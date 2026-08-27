import Foundation
import AVFoundation
import Speech

/// Prova la catena di riconoscimento *in streaming* senza microfono: genera la
/// voce con il sintetizzatore e la inietta nell'analizzatore come farebbe il
/// microfono. Se qui i risultati arrivano, la catena è sana e il problema sta
/// nell'audio in ingresso; se non arrivano, è la catena.
/// I registri vanno in `build/tests/`, non in `/tmp`: `/tmp` è scrivibile da
/// chiunque usi il Mac, e un collegamento piazzato lì dirotterebbe altrove
/// quello che scriviamo.
fileprivate func logPath(_ nome: String) -> String {
  let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("build/tests", isDirectory: true)
  try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir.appendingPathComponent("mirrorscopio-" + nome).path
}

@main
struct StreamHarness {
  nonisolated(unsafe) static var log = ""
  static func say(_ s: String) {
    Swift.print(s)
    log += s + "\n"
    try? log.write(toFile: logPath("stream.log"), atomically: true, encoding: .utf8)
  }

  @MainActor
  static func main() async {
    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "it_IT")) else {
      say("lingua non disponibile"); exit(1)
    }

    let tr = SpeechTranscriber(locale: supported,
                               transcriptionOptions: [],
                               reportingOptions: [.volatileResults],
                               attributeOptions: [.transcriptionConfidence])
    _ = try? await AssetInventory.reserve(locale: supported)

    let analyzer = SpeechAnalyzer(modules: [tr])
    guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [tr]) else {
      say("nessun formato compatibile"); exit(1)
    }
    say("formato analizzatore: \(fmt.sampleRate) Hz, \(fmt.channelCount) ch")

    let ctx = AnalysisContext()
    ctx.contextualStrings = [.general: ["farfalla", "cane", "montagna", "tavolo"]]
    try? await analyzer.setContext(ctx)

    let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()

    nonisolated(unsafe) var results = 0
    let task = Task {
      do {
        for try await r in tr.results {
          results += 1
          say("  risultato #\(results): «\(String(r.text.characters))» definitivo=\(r.isFinal)")
        }
      } catch { say("  errore: \(error)") }
    }

    do { try await analyzer.start(inputSequence: stream) }
    catch { say("start fallito: \(error)"); exit(1) }

    // Due parole di fila, con una chiusura parziale in mezzo: è esattamente
    // quello che fa una sessione, una parola dopo l'altra senza mai fermare
    // il microfono.
    nonisolated(unsafe) var fed: Int64 = 0
    nonisolated(unsafe) var converter: AVAudioConverter?
    // Un solo sintetizzatore, tenuto vivo: se lo si crea dentro la funzione
    // ARC lo libera a metà scrittura e la richiamata non arriva mai.
    let synth = AVSpeechSynthesizer()

    func push(_ word: String) async {
      let u = AVSpeechUtterance(string: word)
      u.voice = AVSpeechSynthesisVoice(language: "it-IT")
      u.rate = 0.4
      await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        nonisolated(unsafe) var finished = false
        synth.write(u) { buf in
          guard let pcm = buf as? AVAudioPCMBuffer else { return }
          if pcm.frameLength == 0 {
            if !finished { finished = true; done.resume() }
            return
          }
          if converter == nil { converter = AVAudioConverter(from: pcm.format, to: fmt) }
          guard let conv = converter else { return }
          let ratio = fmt.sampleRate / pcm.format.sampleRate
          let cap = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 1024
          guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else { return }
          var err: NSError?
          var delivered = false
          conv.convert(to: out, error: &err) { _, status in
            if delivered { status.pointee = .noDataNow; return nil }
            delivered = true
            status.pointee = .haveData
            return pcm
          }
          guard err == nil, out.frameLength > 0 else { return }
          cont.yield(AnalyzerInput(buffer: out,
                                   bufferStartTime: CMTime(value: fed, timescale: CMTimeScale(fmt.sampleRate))))
          fed += Int64(out.frameLength)
        }
      }
      // Mezzo secondo di silenzio in coda, come fra una parola e l'altra.
      if let silence = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(fmt.sampleRate / 2)) {
        silence.frameLength = AVAudioFrameCount(fmt.sampleRate / 2)
        cont.yield(AnalyzerInput(buffer: silence,
                                 bufferStartTime: CMTime(value: fed, timescale: CMTimeScale(fmt.sampleRate))))
        fed += Int64(silence.frameLength)
      }
    }

    // Il microfono vero non smette mai di consegnare buffer: senza questo
    // flusso continuo la chiusura parziale resta in attesa per sempre.
    let silenceFeeder = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(60))
        guard let s = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 960) else { continue }
        s.frameLength = 960
        cont.yield(AnalyzerInput(buffer: s,
                                 bufferStartTime: CMTime(value: fed, timescale: CMTimeScale(fmt.sampleRate))))
        fed += 960
      }
    }

    for word in ["farfalla", "montagna"] {
      say("── parola «\(word)» ──")
      await push(word)
      say("  audio immesso: \(fed) frame")
      let before = results
      let t0 = Date()
      // La chiusura parziale forza il riconoscitore a consegnare quello che ha
      // sentito finora, senza chiudere la sessione.
      say("  chiedo la chiusura parziale…")
      try? await analyzer.finalize(through: CMTime(value: fed, timescale: CMTimeScale(fmt.sampleRate)))
      say("  chiusura parziale tornata")
      for _ in 0..<40 {
        if results > before { break }
        try? await Task.sleep(for: .milliseconds(50))
      }
      say("  risultati nuovi: \(results - before) dopo \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
    }

    silenceFeeder.cancel()
    cont.finish()
    try? await analyzer.finalizeAndFinishThroughEndOfInput()
    try? await Task.sleep(for: .seconds(1))
    task.cancel()

    say("")
    say(results > 0 ? "✓ la catena di riconoscimento funziona (\(results) risultati)"
                    : "✗ la catena non produce risultati nemmeno con audio pulito")
    exit(results > 0 ? 0 : 1)
  }
}
