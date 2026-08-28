import Foundation
import AVFoundation
import Speech

/// Sonda del giro completo col microfono vero: apre l'ascolto, pronuncia una
/// parola dagli altoparlanti e guarda se il riconoscitore la sente.
/// Serve a capire dove si rompe la catena quando "non riconosce niente".
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
struct MicHarness {
  /// Scrive anche su file: dentro un bundle lanciato da LaunchServices lo
  /// standard output non arriva da nessuna parte.
  nonisolated(unsafe) static var log = ""
  static func say(_ s: String) {
    Swift.print(s)
    log += s + "\n"
    try? log.write(toFile: logPath("microfono.log"), atomically: true, encoding: .utf8)
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

    // Il modello vocale si installa per applicazione, non per Mac.
    //
    // Sul disco l'italiano c'era, ma questa verifica falliva lo stesso dicendo
    // «manca il modello»: ogni applicazione deve chiedersi la propria copia in
    // uso, e l'harness non è l'app. È lo stesso passo che l'app fa dalla
    // schermata «Prepara il Mac»; qui va fatto in silenzio, o le tre verifiche
    // che contano restano rosse per sempre e nessuno le guarda più.
    if let sup = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "it_IT")) {
      let modulo = SpeechTranscriber(locale: sup, transcriptionOptions: [],
                                     reportingOptions: [.volatileResults],
                                     attributeOptions: [.transcriptionConfidence, .audioTimeRange])
      if await AssetInventory.status(forModules: [modulo]) != .installed {
        say("il modello italiano non è ancora in uso per questa verifica: lo richiedo…")
        if let richiesta = try? await AssetInventory.assetInstallationRequest(supporting: [modulo]) {
          try? await richiesta.downloadAndInstall()
        }
        say("stato del modello: \(String(describing: await AssetInventory.status(forModules: [modulo])))")
      }
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

    listener.beginWindow(trialID: 1)

    let synth = AVSpeechSynthesizer()
    let u = AVSpeechUtterance(string: "farfalla")
    u.voice = AVSpeechSynthesisVoice(language: "it-IT")
    u.volume = 1.0
    u.rate = 0.42
    say("pronuncio «farfalla» dagli altoparlanti…")
    synth.speak(u)

    // Si misura la cosa di cui la gente si lamenta: quanto passa fra la fine
    // della parola e il momento in cui l'app sa che cosa è stato detto.
    //
    // Questa verifica prima aspettava solo che arrivasse una trascrizione
    // definitiva, senza mai chiederla — cioè riproduceva fedelmente il difetto
    // dell'app invece di scoprirlo, e concludeva che «il riconoscitore non
    // produce testo». Adesso fa quello che fa la sessione vera: appena la voce
    // tace, chiede la consegna.
    var peak: Float = 0
    var fineVoce: CFAbsoluteTime?
    var chiesto = false
    var latenza: Double?

    for _ in 0..<80 {
      try? await Task.sleep(for: .milliseconds(50))
      peak = max(peak, listener.read().level)

      if !synth.isSpeaking, fineVoce == nil { fineVoce = CFAbsoluteTimeGetCurrent() }

      if let fine = fineVoce, !chiesto, CFAbsoluteTimeGetCurrent() - fine >= 0.45 {
        chiesto = true
        await listener.flush()
      }

      let ora = listener.read()
      if !ora.text.isEmpty, latenza == nil, let fine = fineVoce {
        latenza = CFAbsoluteTimeGetCurrent() - fine
      }
      if ora.isFinal, !ora.text.isEmpty { break }
    }

    let snap = listener.read()
    listener.endWindow()
    await listener.stop()

    say("picco di livello durante la prova: \(String(format: "%.5f", peak))")
    say("trascrizione: «\(snap.text)»")
    say("definitiva: \(snap.isFinal)  ·  confidenza: \(snap.confidence.map { String(format: "%.2f", $0) } ?? "—")")
    if let latenza {
      say(String(format: "attesa fra la fine della parola e la risposta: %.2f secondi", latenza))
    }

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
