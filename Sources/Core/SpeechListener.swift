import Foundation
import Synchronization
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
  /// Il livello piu alto raggiunto dentro questa finestra di risposta.
  ///
  /// Serve a distinguere due cose che si assomigliano e che non vanno
  /// confuse mai: chi non ha detto niente, e chi ha detto tutto ma troppo
  /// piano perche il Mac lo capisca. Misurato: sotto 0,04 il riconoscitore
  /// non consegna nessun testo pur sentendo benissimo che c'e' una voce.
  var picco: Float = 0
  /// Vero quando il riconoscitore ha già consegnato qualcosa almeno una volta
  /// da quando è stato acceso: prima di allora sta ancora caricando il modello.
  var caldo = false
  /// Identifica la prova a cui questa finestra di risposta appartiene.
  ///
  /// Il riconoscitore consegna quando gli pare, e una consegna in ritardo
  /// arrivava dentro la prova successiva: la parola detta per «casa» finiva
  /// giudicata contro «mare». Con l'identificativo la consegna in ritardo si
  /// riconosce e si scarta, invece di essere attribuita a chi non l'ha detta.
  var trialID: Int?
  /// Quante consegne sono state scartate perché arrivate fuori tempo. Non è
  /// un numero da mostrare a un ragazzo, ma tacerlo vorrebbe dire non sapere
  /// mai quanto spesso succede.
  var consegneFuoriTempo = 0
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

/// Lo stato che il microfono e lo schermo si passano di continuo.
///
/// Sta tutto qui dentro, in una struttura sola, perché il microfono scrive da
/// un thread suo, in tempo reale, mentre lo schermo legge sessanta volte al
/// secondo dal thread principale. Tenerlo sparso in proprietà separate voleva
/// dire fidarsi che ogni singola riga si ricordasse di prendere il lucchetto:
/// bastava dimenticarsene una volta perché il difetto diventasse invisibile e
/// intermittente. Raccolto in una struttura, il lucchetto è uno solo e non si
/// può scordare, perché non c'è modo di leggere questi campi senza passarci.
struct StatoVoce {
  var snapshot = VoiceWindowSnapshot()
  var windowActive = false
  /// La prova a cui appartiene la finestra aperta adesso.
  var provaCorrente: Int?
  var windowStart: CMTime = .zero
  var framesFed: Int64 = 0
  /// Vedi `senzaLeParoleGiaDette`.
  var paroleGiaDette = ""
  /// Istante di accensione del riconoscitore: serve a misurare quanto ci mette
  /// a svegliarsi la prima volta.
  var accesoDa: CFTimeInterval?
  /// Soglia RMS per rilevare l'inizio della voce; calibrata sul rumore di
  /// fondo all'avvio.
  var noiseFloor: Float = 0.004
  var calibrating = true
  var calibrationSamples: [Float] = []
  /// Frequenza di campionamento con cui l'audio viene consegnato: serve a
  /// tradurre in tempo il conto dei fotogrammi.
  var sampleRate: Double = 16000
}

/// La parte del riconoscimento vocale che il thread audio tocca davvero.
///
/// Il thread del microfono non può aspettare: gli si consegna un pezzo di
/// audio ogni pochi millesimi e deve restituirlo prima del successivo, quindi
/// non può stare dietro a un attore né sospendersi. Per questo il ciclo di
/// vita (accendere, spegnere, chiudere la trascrizione) sta nell'attore
/// `SpeechListener`, mentre lo stato che l'audio scrive vive qui, protetto da
/// un lucchetto vero.
///
/// Il guadagno non è formale. Prima questa classe era dichiarata sicura *per
/// affermazione* (`@unchecked Sendable`): il compilatore accettava la parola
/// data e smetteva di controllare. Adesso non c'è nessuna affermazione da
/// credere — l'unico campo è un lucchetto, e il compilatore verifica da solo
/// che non esista una strada per leggere quei dati senza passare di lì.
final class CassettaVoce: Sendable {

  private let stato = Mutex(StatoVoce())

  // MARK: - Lettura

  func read() -> VoiceWindowSnapshot {
    stato.withLock { $0.snapshot }
  }

  /// Fin dove l'audio è stato consegnato, in tempo.
  func punto() -> CMTime {
    stato.withLock {
      CMTime(value: $0.framesFed, timescale: CMTimeScale($0.sampleRate))
    }
  }

  // MARK: - Ciclo dell'ascolto

  /// Azzera tutto: serve a ogni riaccensione, perché un ascolto nuovo non deve
  /// ereditare né il rumore di fondo misurato ieri né le parole di prima.
  func azzera(sampleRate: Double) {
    stato.withLock { $0 = StatoVoce(sampleRate: sampleRate) }
  }

  func segnaAccensione() {
    stato.withLock {
      $0.accesoDa = CACurrentMediaTime()
      $0.snapshot.caldo = false
      $0.snapshot.primaRispostaSec = nil
    }
  }

  /// Apre la finestra di risposta per una prova precisa.
  ///
  /// `trialID` non è un dettaglio contabile: è quello che permette di
  /// riconoscere una consegna arrivata in ritardo. Senza, il testo di una
  /// parola poteva finire attribuito a quella dopo, e nessuno se ne accorgeva
  /// — né chi legge, né chi guarda il referto.
  func beginWindow(trialID: Int) {
    stato.withLock { s in
      // Quello che è stato consegnato fin qui non appartiene alla prova che sta
      // per cominciare: si mette da parte per poterlo togliere.
      if !s.snapshot.text.isEmpty {
        s.paroleGiaDette = (s.paroleGiaDette + " " + s.snapshot.text).trimmed()
      }
      let caldoPrima = s.snapshot.caldo
      let primaPrima = s.snapshot.primaRispostaSec
      let scartatePrima = s.snapshot.consegneFuoriTempo
      s.snapshot = VoiceWindowSnapshot()
      s.snapshot.caldo = caldoPrima
      s.snapshot.primaRispostaSec = primaPrima
      s.snapshot.consegneFuoriTempo = scartatePrima
      s.snapshot.trialID = trialID
      s.windowStart = CMTime(value: s.framesFed, timescale: CMTimeScale(s.sampleRate))
      s.windowActive = true
      s.provaCorrente = trialID
    }
  }

  func endWindow() {
    stato.withLock { $0.windowActive = false; $0.provaCorrente = nil }
  }

  /// Vero se la prova indicata è ancora quella aperta. Quando non lo è, la
  /// consegna viene contata fra quelle fuori tempo invece di essere attribuita
  /// a chi non l'ha detta.
  func ancoraSua(_ trialID: Int) -> (sua: Bool, corrente: Int?) {
    stato.withLock { s in
      let corrente = s.provaCorrente
      let sua = corrente == trialID
      if !sua { s.snapshot.consegneFuoriTempo += 1 }
      return (sua, corrente)
    }
  }

  // MARK: - Dal thread audio

  /// Registra i fotogrammi consegnati e restituisce l'istante da cui partono.
  func avanza(fotogrammi: AVAudioFrameCount, frequenza: Double) -> CMTime {
    stato.withLock { s in
      let start = CMTime(value: s.framesFed, timescale: CMTimeScale(frequenza))
      s.framesFed += Int64(fotogrammi)
      return start
    }
  }

  /// Rileva l'inizio della voce dall'energia del segnale: dà la latenza vocale
  /// con precisione molto maggiore di quella ricavabile dalla trascrizione.
  func misuraLivello(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData?[0] else { return }
    let n = Int(buffer.frameLength)
    guard n > 0 else { return }
    var sum: Float = 0
    for i in 0..<n { sum += data[i] * data[i] }
    let rms = (sum / Float(n)).squareRoot()
    let now = CACurrentMediaTime()

    stato.withLock { s in
      s.snapshot.level = rms

      if s.calibrating {
        s.calibrationSamples.append(rms)
        if s.calibrationSamples.count >= 40 {
          let sorted = s.calibrationSamples.sorted()
          let median = sorted[sorted.count / 2]
          s.noiseFloor = max(0.002, median * 4 + 0.002)
          s.calibrating = false
        }
      } else if s.windowActive {
        if rms > s.snapshot.picco { s.snapshot.picco = rms }
        if rms > s.noiseFloor {
          if s.snapshot.voiceOnset == nil { s.snapshot.voiceOnset = now }
          s.snapshot.lastVoice = now
        }
      }
    }
  }

  // MARK: - Dal riconoscitore

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
  func ingest(_ result: SpeechTranscriber.Result) {
    stato.withLock { s in
      // Il primo risultato che arriva, qualunque sia, dice che il modello è
      // sveglio: si registra prima di ogni altro controllo, perché il
      // riscaldamento avviene apposta a finestra chiusa.
      if !s.snapshot.caldo {
        s.snapshot.caldo = true
        if let accesoDa = s.accesoDa {
          s.snapshot.primaRispostaSec = CACurrentMediaTime() - accesoDa
        }
      }

      guard s.windowActive else { return }
      guard result.range.end > s.windowStart else { return }

      let (grezzo, confidence) = Self.testoDentroLaFinestra(result, da: s.windowStart)
      let text = Self.senzaLeParoleGiaDette(grezzo, gia: s.paroleGiaDette)
      guard !text.isEmpty else { return }

      s.snapshot.text = text
      s.snapshot.isFinal = result.isFinal
      s.snapshot.lastUpdate = CACurrentMediaTime()
      s.snapshot.confidence = confidence
    }
  }

  /// Testo consegnato nelle prove precedenti, da non riportare dentro questa.
  ///
  /// Il taglio sui tempi non basta da solo: il riconoscitore accumula e ogni
  /// consegna ripete tutto quello che ha capito dall'inizio. Senza questo,
  /// alla terza parola si sarebbe confrontato «cane tavolo mare» con `mare` —
  /// che è il difetto per cui una risposta giusta risultava "Ancora".
  static func senzaLeParoleGiaDette(_ testo: String, gia paroleGiaDette: String) -> String {
    guard !paroleGiaDette.isEmpty else { return testo }
    let confronto = Scoring.normalize(testo)
    let vecchio = Scoring.normalize(paroleGiaDette)
    guard confronto.hasPrefix(vecchio) else { return testo }

    // Si tolgono tante parole quante ne conteneva il già detto: si lavora a
    // parole intere, perché tagliare per numero di caratteri sposterebbe il
    // taglio ogni volta che il riconoscitore cambia una maiuscola o un accento.
    let quante = vecchio.split(separator: " ").count
    let rimaste = testo.split(separator: " ").dropFirst(quante)
    return rimaste.joined(separator: " ").trimmed()
  }

  static func testoDentroLaFinestra(_ result: SpeechTranscriber.Result,
                                    da windowStart: CMTime) -> (String, Double?) {
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
      // Conta dove il pezzo **finisce**, non dove comincia.
      //
      // Pretendere che cominciasse dentro la finestra sembrava ovvio ed era il
      // guasto che rendeva l'app muta: il riconoscitore non data i pezzi
      // parola per parola, li data dall'inizio dell'ascolto. Misurato sul
      // vero: leggendo «farfalla» dopo un secondo di silenzio, il pezzo
      // arrivava marcato 0,00–3,96 secondi. Cominciava prima della finestra,
      // quindi veniva buttato, quindi la trascrizione restava vuota, quindi
      // l'app diceva «non ho sentito niente» a chi aveva appena letto giusto.
      //
      // Le parole delle prove precedenti non tornano dentro lo stesso: le
      // toglie `senzaLeParoleGiaDette`, che lavora sul testo consegnato invece
      // che sui tempi.
      guard tratto.end > windowStart else { continue }
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

/// Riconoscimento vocale continuo, interamente sul dispositivo (framework
/// Speech di macOS 26). Nessun audio lascia il Mac.
///
/// È un attore: accendere e spegnere il microfono sono le due operazioni che
/// non devono mai sovrapporsi, e un attore le mette in fila da solo invece di
/// affidarsi a chi chiama. Serviva: `abort()` spegne, il cambio di microfono
/// spegne e riaccende, e la fine della sessione spegne di nuovo — tre strade
/// che possono partire nello stesso istante. Prima si intrecciavano, e il
/// motore audio che restava acceso teneva il microfono occupato per sempre.
///
/// Lo stato che il thread audio scrive **non** sta qui: sta in `CassettaVoce`,
/// perché quel thread non può aspettare il proprio turno.
actor SpeechListener {

  /// Le quattro condizioni in cui il microfono può trovarsi.
  ///
  /// Scritte a chiare lettere perché prima erano implicite, sparse fra un
  /// oggetto a `nil` e un motore fermo, e non c'era modo di rispondere alla
  /// domanda «adesso è acceso?» senza indovinare.
  enum Fase: Sendable, Equatable {
    case fermo, avvio, attivo, arresto
  }

  private(set) var fase: Fase = .fermo

  /// Cambia a ogni accensione e a ogni spegnimento.
  ///
  /// È quello che rende `stop()` ripetibile e l'accensione a raffica
  /// innocua: un avvio che si risveglia da un'attesa e trova un numero
  /// diverso dal proprio sa che nel frattempo qualcuno ha ricominciato, butta
  /// quello che ha costruito e si toglie di mezzo, invece di andare a
  /// sovrascrivere il microfono di un altro.
  private var generazione = 0

  /// Lo stato condiviso col thread audio. `nonisolated` perché quel thread lo
  /// scrive senza passare dall'attore: lo protegge il lucchetto dentro la
  /// cassetta, non l'attore.
  nonisolated let cassetta = CassettaVoce()

  /// Creato solo al momento di ascoltare: il motore si lega al microfono che
  /// trova alla nascita, quindi la scelta del dispositivo deve venire prima.
  private var engine: AVAudioEngine?
  private var analyzer: SpeechAnalyzer?
  private var transcriber: SpeechTranscriber?
  private var continuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?

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
    // Chi accende trova sempre spento: se qualcosa era acceso lo si spegne
    // qui, invece di sperare che chi chiama se lo ricordi. Due motori audio
    // sullo stesso microfono non danno errore, danno un microfono occupato
    // che non si libera più.
    await stop()

    generazione += 1
    let mia = generazione
    fase = .avvio

    /// Da chiamare quando questo avvio ha perso il posto: butta quello che ha
    /// costruito senza toccare la roba di chi è arrivato dopo.
    func abbandona(_ costruito: Costruito) async {
      costruito.spegniIlMotore()
      await costruito.analyzer?.cancelAndFinishNow()
    }

    do {
      guard SpeechTranscriber.isAvailable else {
        throw ListenerError.localeUnavailable(locale.identifier)
      }
      guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
        throw ListenerError.localeUnavailable(locale.identifier)
      }
      guard mia == generazione else { fase = .fermo; return }

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
      guard mia == generazione else { fase = .fermo; return }

      // Il vocabolario della sessione orienta il riconoscitore verso gli stimoli attesi,
      // che è ciò che rende affidabile il punteggio su parole isolate.
      let context = AnalysisContext()
      context.contextualStrings = [.general: Array(Set(vocabulary)).prefix(500).map { $0 }]

      let an = SpeechAnalyzer(modules: [tr])
      try await an.setContext(context)

      guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [tr]) else {
        throw ListenerError.noAudioFormat
      }
      guard mia == generazione else { fase = .fermo; return }

      // La scelta del microfono passa dall'ingresso predefinito del sistema
      // (vedi `AudioDevices.setDefaultInput`) e deve precedere la nascita del
      // motore audio, altrimenti resta legato al microfono di prima.
      if let preferredInput, preferredInput != AudioDevices.defaultInput() {
        AudioDevices.setDefaultInput(preferredInput)
        try? await Task.sleep(for: .milliseconds(600))
      }
      guard mia == generazione else { fase = .fermo; return }

      // Da qui in poi c'è roba accesa: se questo avvio perde il posto va
      // smontata a mano, perché non è ancora appesa all'attore.
      let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
      let motore = AVAudioEngine()
      let costruito = Costruito(engine: motore, analyzer: an, continuation: cont)

      cassetta.azzera(sampleRate: fmt.sampleRate)
      do {
        try installTap(su: motore, target: fmt, verso: cont)
        try await an.start(inputSequence: stream)
        motore.prepare()
        try motore.start()
      } catch {
        await abbandona(costruito)
        throw error
      }

      guard mia == generazione else { await abbandona(costruito); fase = .fermo; return }

      engine = motore
      analyzer = an
      transcriber = tr
      continuation = cont
      cassetta.segnaAccensione()

      let cassetta = self.cassetta
      resultsTask = Task {
        do {
          for try await result in tr.results {
            cassetta.ingest(result)
          }
        } catch {
          // La chiusura dell'analizzatore termina la sequenza: non è una condizione di errore.
        }
      }

      fase = .attivo

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
    } catch {
      fase = .fermo
      throw error
    }
  }

  /// Spegne, e si può chiamare quante volte si vuole.
  ///
  /// Chiamarlo su un microfono già spento non fa niente e non costa niente:
  /// serve, perché le strade che spengono sono tre (interruzione, cambio di
  /// microfono, fine della sessione) e possono arrivare tutte insieme.
  func stop() async {
    generazione += 1
    guard fase != .fermo else { return }
    fase = .arresto

    let costruito = Costruito(engine: engine, analyzer: analyzer, continuation: continuation)
    let compito = resultsTask
    engine = nil
    analyzer = nil
    transcriber = nil
    continuation = nil
    resultsTask = nil

    compito?.cancel()
    costruito.spegniIlMotore()
    await costruito.analyzer?.cancelAndFinishNow()

    fase = .fermo
  }

  /// Le tre cose accese che vanno spente insieme e nell'ordine giusto.
  ///
  /// Sta a parte perché lo spegnimento serve in due punti — quando si smette
  /// davvero, e quando un avvio scopre di essere stato superato da un altro —
  /// e le due volte deve fare esattamente la stessa cosa. Quando erano due
  /// copie del codice, una delle due dimenticava sempre un pezzo.
  private struct Costruito {
    let engine: AVAudioEngine?
    let analyzer: SpeechAnalyzer?
    let continuation: AsyncStream<AnalyzerInput>.Continuation?

    /// La parte che si spegne subito, senza aspettare nessuno.
    func spegniIlMotore() {
      if let engine {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
      }
      continuation?.finish()
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
    guard let analyzer else { return }
    do {
      try await analyzer.finalize(through: cassetta.punto())
    } catch {
      // Non si puo interrompere la sessione per questo: il microfono resta
      // aperto e la parola dopo va comunque tentata. Ma il silenzio totale era
      // peggio — se questa chiamata smettesse di funzionare l'app tornerebbe
      // sorda come prima, e nessuno saprebbe perche.
      Log.warn("La chiusura della trascrizione non è riuscita: \(error.localizedDescription)")
    }
  }

  /// Chiude la trascrizione fino a questo punto per una prova precisa.
  ///
  /// Se nel frattempo la finestra è passata alla prova successiva, la richiesta
  /// non ha più senso: chiuderla adesso vorrebbe dire consegnare alla prova
  /// nuova l'audio di quella vecchia.
  func flush(trialID: Int) async -> Bool {
    let esito = cassetta.ancoraSua(trialID)
    guard esito.sua else {
      Log.warn("Chiusura della trascrizione arrivata fuori tempo: era per la prova \(trialID), ora siamo alla \(esito.corrente.map(String.init) ?? "nessuna"). Scartata.")
      return false
    }
    await flush()
    return true
  }

  // MARK: - Finestra di risposta

  // Queste tre non passano dall'attore: chi disegna lo schermo le chiama
  // sessanta volte al secondo e non può fermarsi ad aspettare un turno. Sono
  // sicure perché toccano solo la cassetta, che ha il lucchetto suo.

  nonisolated func beginWindow(trialID: Int) { cassetta.beginWindow(trialID: trialID) }

  nonisolated func endWindow() { cassetta.endWindow() }

  nonisolated func read() -> VoiceWindowSnapshot { cassetta.read() }

  // MARK: - Audio

  private func installTap(su engine: AVAudioEngine,
                          target: AVAudioFormat,
                          verso cont: AsyncStream<AnalyzerInput>.Continuation) throws {
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

    // Il blocco non tiene `self`: tiene la cassetta e il canale, che è tutto
    // quello che gli serve. Così l'attore può essere lasciato andare senza che
    // il thread audio resti attaccato a qualcosa che non c'è più.
    let cassetta = self.cassetta
    input.installTap(onBus: 0, bufferSize: 2048, format: natural) { buffer, _ in
      cassetta.misuraLivello(buffer)

      let ratio = target.sampleRate / natural.sampleRate
      let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
      guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

      var error: NSError?
      // Il blocco qui sotto è dichiarato dal sistema come utilizzabile da più
      // thread, ma non lo è: `convert` lo chiama e lo esaurisce prima di
      // restituire il controllo, sempre su questo stesso thread. Le due
      // dichiarazioni «non sorvegliato» dicono esattamente questo, su due
      // righe sole e con la ragione accanto — che è il contrario di quello che
      // faceva prima l'intera classe, dove la stessa parola copriva ottanta
      // campi e nessuno sapeva più quali fossero davvero al sicuro.
      nonisolated(unsafe) let ingresso = buffer
      nonisolated(unsafe) var consegnato = false
      converter.convert(to: out, error: &error) { _, status in
        if consegnato { status.pointee = .noDataNow; return nil }
        consegnato = true
        status.pointee = .haveData
        return ingresso
      }
      guard error == nil, out.frameLength > 0 else { return }

      let start = cassetta.avanza(fotogrammi: out.frameLength, frequenza: target.sampleRate)
      cont.yield(AnalyzerInput(buffer: out, bufferStartTime: start))
    }
  }
}
