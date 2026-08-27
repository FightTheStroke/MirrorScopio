import Foundation
import AVFoundation
import Speech

/// Sonda grezza della catena di riconoscimento: niente SpeechListener di mezzo,
/// solo motore audio → convertitore → analizzatore, con tutto stampato.
/// Serve a capire *dove* si perde la voce quando l'app "non riconosce niente".
@main
struct RawSpeechHarness {
  nonisolated(unsafe) static var log = ""
  static func say(_ s: String) {
    Swift.print(s)
    log += s + "\n"
    try? log.write(toFile: "/tmp/mirrorscopio-raw.log", atomically: true, encoding: .utf8)
  }

  @MainActor
  static func main() async {
    say("dispositivo d'ingresso: \(AudioDevices.currentInputName() ?? "?")")
    say("dispositivo d'uscita: \(AudioDevices.currentOutputName() ?? "?")")

    guard await SpeechListener.requestPermissions() else { say("permessi negati"); exit(1) }

    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "it_IT")) else {
      say("lingua italiana non disponibile"); exit(1)
    }
    say("lingua: \(supported.identifier)")

    let tr = SpeechTranscriber(locale: supported,
                               transcriptionOptions: [],
                               reportingOptions: [.volatileResults],
                               attributeOptions: [.transcriptionConfidence])

    let status = await AssetInventory.status(forModules: [tr])
    say("modello installato: \(status)")
    if status != .installed, let req = try? await AssetInventory.assetInstallationRequest(supporting: [tr]) {
      say("scarico il modello…")
      try? await req.downloadAndInstall()
    }
    _ = try? await AssetInventory.reserve(locale: supported)

    let analyzer = SpeechAnalyzer(modules: [tr])
    guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [tr]) else {
      say("nessun formato compatibile"); exit(1)
    }
    say("formato richiesto dall'analizzatore: \(fmt.sampleRate) Hz, \(fmt.channelCount) canali, \(fmt.commonFormat.rawValue)")

    // Il dispositivo va scelto PRIMA di creare il motore: il motore si lega
    // all'ingresso che trova al momento della nascita.
    let previousInput = AudioDevices.defaultInput()
    if let mic = AudioDevices.inputs().first(where: { $0.name == "Microfono MacBook Pro" }) {
      let ok = AudioDevices.setDefaultInput(mic.id)
      say("microfono forzato su «\(mic.name)»: \(ok ? "riuscito" : "fallito")")
      try? await Task.sleep(for: .milliseconds(600))
    }
    defer { if let previousInput { _ = AudioDevices.setDefaultInput(previousInput) } }

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let natural = input.outputFormat(forBus: 0)
    say("formato del microfono: \(natural.sampleRate) Hz, \(natural.channelCount) canali")

    guard let converter = AVAudioConverter(from: natural, to: fmt) else {
      say("convertitore non creabile"); exit(1)
    }

    let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()

    nonisolated(unsafe) var fed: Int64 = 0
    nonisolated(unsafe) var buffersIn = 0
    nonisolated(unsafe) var framesOut: Int64 = 0
    nonisolated(unsafe) var peak: Float = 0
    nonisolated(unsafe) var convErrors = 0

    input.installTap(onBus: 0, bufferSize: 2048, format: natural) { buffer, _ in
      buffersIn += 1
      if let d = buffer.floatChannelData?[0] {
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += d[i] * d[i] }
        peak = max(peak, (sum / Float(buffer.frameLength)).squareRoot())
      }

      let ratio = fmt.sampleRate / natural.sampleRate
      let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
      guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: capacity) else { return }
      var error: NSError?
      var delivered = false
      converter.convert(to: out, error: &error) { _, status in
        if delivered { status.pointee = .noDataNow; return nil }
        delivered = true
        status.pointee = .haveData
        return buffer
      }
      if error != nil { convErrors += 1; return }
      guard out.frameLength > 0 else { return }
      let start = CMTime(value: fed, timescale: CMTimeScale(fmt.sampleRate))
      fed += Int64(out.frameLength)
      framesOut += Int64(out.frameLength)
      cont.yield(AnalyzerInput(buffer: out, bufferStartTime: start))
    }

    nonisolated(unsafe) var results = 0
    let task = Task {
      do {
        for try await r in tr.results {
          results += 1
          let text = String(r.text.characters)
          say("  risultato #\(results): «\(text)»  definitivo=\(r.isFinal)  intervallo=\(r.range.start.seconds)…\(r.range.end.seconds)")
        }
        say("  (la sequenza dei risultati è finita)")
      } catch {
        say("  errore nei risultati: \(error)")
      }
    }

    do {
      try await analyzer.start(inputSequence: stream)
      engine.prepare()
      try engine.start()
    } catch {
      say("avvio fallito: \(error)"); exit(1)
    }
    say("in ascolto…")

    // Parla dagli altoparlanti interni, che il microfono interno può sentire.
    let previousOut = AudioDevices.defaultOutput()
    if let speakers = AudioDevices.outputs().first(where: { $0.name.contains("MacBook") }) {
      _ = AudioDevices.setDefaultOutput(speakers.id)
      say("uscita temporanea: \(speakers.name)")
    }

    let synth = AVSpeechSynthesizer()
    for word in ["farfalla", "cane", "montagna"] {
      let u = AVSpeechUtterance(string: word)
      u.voice = AVSpeechSynthesisVoice(language: "it-IT")
      u.volume = 1.0
      u.rate = 0.4
      synth.speak(u)
      try? await Task.sleep(for: .seconds(3))
      say("  dopo «\(word)»: buffer=\(buffersIn) frame_convertiti=\(framesOut) picco=\(String(format: "%.5f", peak)) risultati=\(results) errori_conversione=\(convErrors)")
    }

    try? await Task.sleep(for: .seconds(2))
    say("finalizzo…")
    try? await analyzer.finalizeAndFinishThroughEndOfInput()
    try? await Task.sleep(for: .seconds(2))

    engine.stop()
    cont.finish()
    task.cancel()
    if let previousOut { _ = AudioDevices.setDefaultOutput(previousOut) }

    say("")
    say("TOTALE: buffer=\(buffersIn) frame_convertiti=\(framesOut) picco=\(String(format: "%.5f", peak)) risultati=\(results) errori_conversione=\(convErrors)")
    exit(results > 0 ? 0 : 1)
  }
}
