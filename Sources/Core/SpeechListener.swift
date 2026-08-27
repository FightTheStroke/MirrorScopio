import Foundation
import AVFoundation
import Speech
import CoreMedia

/// Stato osservabile della risposta vocale nella prova corrente.
struct VoiceWindowSnapshot {
  var text: String = ""
  var isFinal = false
  var lastUpdate: CFTimeInterval?
  var voiceOnset: CFTimeInterval?
  /// Ultimo istante in cui il microfono ha sentito qualcosa sopra il rumore di
  /// fondo. Serve per non chiudere il turno a chi sta ancora parlando.
  var lastVoice: CFTimeInterval?
  var confidence: Double?
  var level: Float = 0
  /// Vero quando il riconoscitore ha già consegnato qualcosa almeno una volta
  /// da quando è stato acceso: prima di allora sta ancora caricando il modello.
  var caldo = false
  /// Quanto ha impiegato la prima parola a comparire, in secondi. L'app lo sa,
  /// quindi lo dice invece di lasciar credere che sia colpa di chi parla.
  var primaRispostaSec: Double?
}

enum ListenerError: LocalizedError {
  case notAuthorized
  case noInputDevice
  case noAudioFormat
  case localeUnavailable(String)
  case modelNotInstalled

  var errorDescription: String? {
    switch self {
    case .notAuthorized:
      "Permesso di riconoscimento vocale o microfono negato. Concedilo in Impostazioni di Sistema › Privacy e sicurezza."
    case .noInputDevice:
      "Nessun microfono attivo. Controlla quale ingresso è selezionato in \"Mi senti?\" o in Impostazioni di Sistema › Suono."
    case .noAudioFormat:
      "Nessun formato audio compatibile con il riconoscitore on-device."
    case .localeUnavailable(let l):
      "Il modello vocale on-device per \(l) non è disponibile."
    case .modelNotInstalled:
      "Manca il modello vocale italiano. Aprilo da «Prepara il Mac»: si scarica una volta sola, e lì vedi quanto manca."
    }
  }
}

/// Riconoscimento vocale continuo, interamente sul dispositivo (framework Speech di macOS 26).
/// Nessun audio lascia il Mac.
final class SpeechListener: @unchecked Sendable {

  private let lock = NSLock()
  private var snapshot = VoiceWindowSnapshot()
  private var windowActive = false
  private var windowStart: CMTime = .zero
  private var framesFed: Int64 = 0

  /// Creato solo al momento di ascoltare: il motore si lega al microfono che
  /// trova alla nascita, quindi la scelta del dispositivo deve venire prima.
  private var engine = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var transcriber: SpeechTranscriber?
  private var continuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var analyzerFormat: AVAudioFormat?
  /// Istante di accensione del riconoscitore: serve a misurare quanto ci mette
  /// a svegliarsi la prima volta.
  private var accesoDa: CFTimeInterval?

  /// Soglia RMS per rilevare l'inizio della voce; calibrata sul rumore di fondo all'avvio.
  private var noiseFloor: Float = 0.004
  private var calibrating = true
  private var calibrationSamples: [Float] = []

  // MARK: - Ciclo di vita

  /// Serve soltanto il microfono.
  ///
  /// Il vecchio permesso di "riconoscimento vocale" fa comparire un avviso di
  /// sistema che dice che l'audio viene inviato ad Apple: è il testo fisso di
  /// quella richiesta, scritto per il riconoscimento sui server. Qui non serve,
  /// perché `SpeechAnalyzer` lavora con il modello installato sul Mac e l'audio
  /// non esce da questa macchina. Chiederlo lo stesso spaventerebbe le famiglie
  /// dicendo il falso.
  static func requestPermissions() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .audio)
  }

  func start(locale: Locale, vocabulary: [String],
             preferredInput: AudioDeviceID? = nil) async throws {
    guard SpeechTranscriber.isAvailable else { throw ListenerError.localeUnavailable(locale.identifier) }

    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      throw ListenerError.localeUnavailable(locale.identifier)
    }

    let tr = SpeechTranscriber(
      locale: supported,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: [.transcriptionConfidence, .audioTimeRange])

    // Nessun download a sorpresa qui: sono ~1 GB, e partirebbero mentre un
    // bambino ha appena premuto «Via!», senza avanzamento e senza spiegazione.
    // Il modello si installa dalla schermata «Prepara il Mac», dove si vede.
    if await AssetInventory.status(forModules: [tr]) != .installed {
      throw ListenerError.modelNotInstalled
    }
    _ = try? await AssetInventory.reserve(locale: supported)

    // Il vocabolario della sessione orienta il riconoscitore verso gli stimoli attesi,
    // che è ciò che rende affidabile il punteggio su parole isolate.
    let context = AnalysisContext()
    context.contextualStrings = [.general: Array(Set(vocabulary)).prefix(500).map { $0 }]

    let an = SpeechAnalyzer(modules: [tr])
    try await an.setContext(context)

    guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [tr]) else {
      throw ListenerError.noAudioFormat
    }

    let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
    analyzer = an
    transcriber = tr
    continuation = cont
    analyzerFormat = fmt

    // La scelta del microfono passa dall'ingresso predefinito del sistema
    // (vedi `AudioDevices.setDefaultInput`) e deve precedere la nascita del
    // motore audio, altrimenti resta legato al microfono di prima.
    if let preferredInput, preferredInput != AudioDevices.defaultInput() {
      AudioDevices.setDefaultInput(preferredInput)
      try? await Task.sleep(for: .milliseconds(600))
    }
    engine = AVAudioEngine()

    try installTap(target: fmt)
    try await an.start(inputSequence: stream)
    engine.prepare()
    try engine.start()

    segnaAccensione()

    resultsTask = Task { [weak self] in
      guard let self else { return }
      do {
        for try await result in tr.results {
          self.ingest(result)
        }
      } catch {
        // La chiusura dell'analizzatore termina la sequenza: non è una condizione di errore.
      }
    }

    // Il modello si sveglia solo quando gli si chiede qualcosa, e la prima
    // volta ci mette secondi: viene caricato in memoria mentre qualcuno sta
    // già parlando. Il risultato è che la prima parola di ogni sessione
    // sembrava non arrivare mai — e chi legge, non vedendo niente, la ripeteva.
    // Qui gli si dà da masticare un po' di silenzio subito, così il carico
    // avviene mentre sullo schermo c'è ancora il conto alla rovescia.
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      await self?.flush()
    }
  }

  /// Chiude la trascrizione fino a questo punto e basta: la sessione resta
  /// aperta e il microfono non si ferma.
  ///
  /// Senza questa chiamata i risultati non arrivano mai a parola singola —
  /// l'analizzatore aspetta molto più audio prima di dire la sua, e il tempo di
  /// risposta di una prova scade prima. È il guasto che rendeva l'app sorda.
  /// Provato in `Tests/StreamHarness.swift`: i risultati arrivano in circa 40 ms.
  func flush() async {
    let punto = puntoAttuale()
    do {
      try await analyzer?.finalize(through: punto)
    } catch {
      // Non si puo interrompere la sessione per questo: il microfono resta
      // aperto e la parola dopo va comunque tentata. Ma il silenzio totale era
      // peggio — se questa chiamata smettesse di funzionare l'app tornerebbe
      // sorda come prima, e nessuno saprebbe perche.
      Log.warn("La chiusura della trascrizione non è riuscita: \(error.localizedDescription)")
    }
  }

  /// Sincrona di proposito, come `puntoAttuale()`: il lucchetto non si prende
  /// dentro una funzione `async`, o si rischia di rilasciarlo da un thread
  /// diverso da quello che l'ha preso e di non scioglierlo più.
  private func segnaAccensione() {
    lock.lock()
    defer { lock.unlock() }
    accesoDa = CACurrentMediaTime()
    snapshot.caldo = false
    snapshot.primaRispostaSec = nil
  }

  /// Legge sotto lucchetto fin dove l'audio è stato consegnato.
  ///
  /// Sta in una funzione a parte, e sincrona, di proposito: `NSLock` non si può
  /// prendere dentro una funzione `async` — fra `lock()` e `unlock()` il
  /// compito può cambiare thread, e un lucchetto rilasciato da un thread
  /// diverso da quello che l'ha preso è un blocco che non si scioglie più.
  private func puntoAttuale() -> CMTime {
    lock.lock()
    defer { lock.unlock() }
    return CMTime(value: framesFed,
                  timescale: CMTimeScale(analyzerFormat?.sampleRate ?? 16000))
  }

  func stop() async {
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    continuation?.finish()
    resultsTask?.cancel()
    await analyzer?.cancelAndFinishNow()
    analyzer = nil
    transcriber = nil
  }

  // MARK: - Finestra di risposta

  func beginWindow() {
    lock.lock()
    snapshot = VoiceWindowSnapshot()
    windowStart = CMTime(value: framesFed, timescale: CMTimeScale(analyzerFormat?.sampleRate ?? 16000))
    windowActive = true
    lock.unlock()
  }

  func endWindow() {
    lock.lock(); windowActive = false; lock.unlock()
  }

  func read() -> VoiceWindowSnapshot {
    lock.lock(); defer { lock.unlock() }
    return snapshot
  }

  // MARK: - Audio

  private func installTap(target: AVAudioFormat) throws {
    let input = engine.inputNode
    let natural = input.outputFormat(forBus: 0)
    // Un ingresso senza canali o a frequenza zero è un microfono che non c'è:
    // meglio dirlo subito che restare in ascolto di un silenzio eterno.
    guard natural.sampleRate > 0, natural.channelCount > 0 else {
      throw ListenerError.noInputDevice
    }
    guard let converter = AVAudioConverter(from: natural, to: target) else {
      throw ListenerError.noAudioFormat
    }

    input.installTap(onBus: 0, bufferSize: 2048, format: natural) { [weak self] buffer, _ in
      guard let self else { return }
      self.measureLevel(buffer)

      let ratio = target.sampleRate / natural.sampleRate
      let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
      guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

      var error: NSError?
      var delivered = false
      converter.convert(to: out, error: &error) { _, status in
        if delivered { status.pointee = .noDataNow; return nil }
        delivered = true
        status.pointee = .haveData
        return buffer
      }
      guard error == nil, out.frameLength > 0 else { return }

      self.lock.lock()
      let start = CMTime(value: self.framesFed, timescale: CMTimeScale(target.sampleRate))
      self.framesFed += Int64(out.frameLength)
      self.lock.unlock()

      self.continuation?.yield(AnalyzerInput(buffer: out, bufferStartTime: start))
    }
  }

  /// Rileva l'inizio della voce dall'energia del segnale: dà la latenza vocale
  /// con precisione molto maggiore di quella ricavabile dalla trascrizione.
  private func measureLevel(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData?[0] else { return }
    let n = Int(buffer.frameLength)
    guard n > 0 else { return }
    var sum: Float = 0
    for i in 0..<n { sum += data[i] * data[i] }
    let rms = (sum / Float(n)).squareRoot()
    let now = CACurrentMediaTime()

    lock.lock()
    snapshot.level = rms

    if calibrating {
      calibrationSamples.append(rms)
      if calibrationSamples.count >= 40 {
        let sorted = calibrationSamples.sorted()
        let median = sorted[sorted.count / 2]
        noiseFloor = max(0.002, median * 4 + 0.002)
        calibrating = false
      }
    } else if windowActive, rms > noiseFloor {
      if snapshot.voiceOnset == nil { snapshot.voiceOnset = now }
      snapshot.lastVoice = now
    }
    lock.unlock()
  }

  /// Tiene solo cio che e stato detto **dopo** la comparsa della parola in corso.
  ///
  /// Qui c'era il difetto che faceva giudicare una prova con la parola di
  /// prima. Il riconoscitore non consegna una parola per volta: consegna un
  /// pezzo di trascrizione che scorre e che puo coprire anche l'attesa
  /// precedente. Scartare il risultato intero quando finisce prima della
  /// finestra non basta — un risultato che *attraversa* l'inizio della finestra
  /// passava il controllo e portava dentro le parole vecchie, e allora si
  /// confrontava "casa mare" con `mare`: "Ancora" a chi aveva detto giusto, e
  /// ogni tanto il contrario, che e anche peggio.
  ///
  /// Adesso il taglio e sul testo, non sul risultato: ogni pezzo di
  /// trascrizione porta con se il tratto di audio da cui viene
  /// (`audioTimeRange`), e teniamo i pezzi che cominciano dentro la finestra.
  private func ingest(_ result: SpeechTranscriber.Result) {
    lock.lock()
    defer { lock.unlock() }

    // Il primo risultato che arriva, qualunque sia, dice che il modello è
    // sveglio: si registra prima di ogni altro controllo, perché il
    // riscaldamento avviene apposta a finestra chiusa.
    if !snapshot.caldo {
      snapshot.caldo = true
      if let accesoDa { snapshot.primaRispostaSec = CACurrentMediaTime() - accesoDa }
    }

    guard windowActive else { return }
    guard result.range.end > windowStart else { return }

    let (text, confidence) = testoDentroLaFinestra(result)
    guard !text.isEmpty else { return }

    snapshot.text = text
    snapshot.isFinal = result.isFinal
    snapshot.lastUpdate = CACurrentMediaTime()
    snapshot.confidence = confidence
  }

  /// Da chiamare col lucchetto gia preso.
  private func testoDentroLaFinestra(_ result: SpeechTranscriber.Result)
    -> (String, Double?) {
    var pezzi: [String] = []
    var confidenze: [Double] = []
    var senzaTempo = false

    for run in result.text.runs {
      let frammento = String(result.text.characters[run.range])
      guard let tratto = run.audioTimeRange else {
        // Senza il tratto di audio non si puo collocare nel tempo: lo si tiene,
        // perche buttarlo renderebbe sorda l'app se un giorno l'attributo non
        // arrivasse piu, ma si annota che il taglio non e affidabile.
        senzaTempo = true
        pezzi.append(frammento)
        if let c = run.transcriptionConfidence { confidenze.append(c) }
        continue
      }
      // Una tolleranza serve: il tratto di audio di una parola comincia qualche
      // centesimo prima del suono vero, e chi risponde di scatto verrebbe
      // tagliato fuori proprio perche e stato veloce.
      guard tratto.end > windowStart,
            tratto.start >= windowStart - CMTime(value: 25, timescale: 1000) else { continue }
      pezzi.append(frammento)
      if let c = run.transcriptionConfidence { confidenze.append(c) }
    }

    if senzaTempo, pezzi.count == result.text.runs.count {
      // Nessun pezzo era collocabile: si torna al comportamento di prima,
      // cioe il testo intero, che e impreciso ma non muto.
      let intero = String(result.text.characters)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return (intero, confidenze.max())
    }

    let testo = pezzi.joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (testo, confidenze.max())
  }
}
