import Foundation
import AVFoundation
import Speech

/// Sonda del giro completo col microfono vero: apre l'ascolto, pronuncia una
/// parola dagli altoparlanti e guarda se il riconoscitore la sente.
/// Serve a capire dove si rompe la catena quando "non riconosce niente".
@main
struct MicHarness {
  /// Scrive anche su file: dentro un bundle lanciato da LaunchServices lo
  /// standard output non arriva da nessuna parte.
  nonisolated(unsafe) static var log = ""
  static func say(_ s: String) {
    Swift.print(s)
    log += s + "\n"
    try? log.write(toFile: "/tmp/mirrorscopio-microfono.log", atomically: true, encoding: .utf8)
  }

  @MainActor
  static func main() async {
    say("── ambiente audio ──")

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let fmt = input.outputFormat(forBus: 0)
    say("ingresso: \(fmt.sampleRate) Hz, \(fmt.channelCount) canali")
    if fmt.sampleRate == 0 || fmt.channelCount == 0 {
      say("✗ il dispositivo d'ingresso non fornisce audio: nessun microfono attivo.")
      exit(1)
    }

    say("dispositivo d'ingresso predefinito: \(AudioDevices.currentInputName() ?? "sconosciuto")")
    say("dispositivo d'uscita predefinito: \(AudioDevices.currentOutputName() ?? "sconosciuto")")
    for d in AudioDevices.inputs() { say("  ingresso disponibile: \(d.name)") }

    say("\n── permessi ──")
    let ok = await SpeechListener.requestPermissions()
    say("microfono e riconoscimento: \(ok ? "concessi" : "NEGATI")")
    guard ok else { exit(1) }

    say("\n── ascolto ──")
    // Prova col microfono e con gli altoparlanti interni: sono gli unici che
    // possono sentirsi a vicenda. Con le AirPods l'altoparlante sta dentro
    // l'orecchio e il microfono non può sentirlo.
    let builtInMic = AudioDevices.inputs().first { $0.name == "Microfono MacBook Pro" }
    let builtInOut = AudioDevices.outputs().first { $0.name.contains("MacBook") }
    say("microfono scelto per la prova: \(builtInMic?.name ?? "predefinito")")

    let previousOutput = AudioDevices.defaultOutput()
    if let builtInOut {
      say("uscita spostata temporaneamente su: \(builtInOut.name)")
      _ = AudioDevices.setDefaultOutput(builtInOut.id)
    }
    defer {
      if let previousOutput { _ = AudioDevices.setDefaultOutput(previousOutput) }
    }

    let listener = SpeechListener()
    let words = ["farfalla", "cane", "tavolo", "montagna"]
    do {
      try await listener.start(locale: Locale(identifier: "it_IT"), vocabulary: words,
                               preferredInput: builtInMic?.id)
    } catch {
      say("✗ avvio dell'ascolto fallito: \(error.localizedDescription)")
      exit(1)
    }

    // Un attimo perché la calibrazione del rumore di fondo finisca.
    try? await Task.sleep(for: .milliseconds(1500))
    say("livello a riposo: \(String(format: "%.5f", listener.read().level))")

    listener.beginWindow()

    let synth = AVSpeechSynthesizer()
    let u = AVSpeechUtterance(string: "farfalla")
    u.voice = AVSpeechSynthesisVoice(language: "it-IT")
    u.volume = 1.0
    u.rate = 0.42
    say("pronuncio «farfalla» dagli altoparlanti…")
    synth.speak(u)

    var peak: Float = 0
    for _ in 0..<60 {
      try? await Task.sleep(for: .milliseconds(100))
      peak = max(peak, listener.read().level)
      if listener.read().isFinal { break }
    }

    let snap = listener.read()
    listener.endWindow()
    await listener.stop()

    say("picco di livello durante la prova: \(String(format: "%.5f", peak))")
    say("trascrizione: «\(snap.text)»")
    say("definitiva: \(snap.isFinal)  ·  confidenza: \(snap.confidence.map { String(format: "%.2f", $0) } ?? "—")")

    if peak < 0.01 {
      say("\n✗ Il microfono non sente quasi niente. Volume degli altoparlanti a zero, oppure l'ingresso selezionato non è quello giusto.")
      exit(1)
    }
    if snap.text.isEmpty {
      say("\n✗ Il microfono sente, ma il riconoscitore non produce testo: il problema è nella catena di riconoscimento.")
      exit(1)
    }
    say("\n✓ La catena funziona da un capo all'altro.")
  }
}
