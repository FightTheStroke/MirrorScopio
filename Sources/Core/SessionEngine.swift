import Foundation
import SwiftUI
import QuartzCore
import AppKit
import CoreAudio

enum Phase: Equatable {
  case idle
  case preparing
  case instructions
  case countdown(Int)
  case fixation
  case preMask
  case stimulus
  case postMask
  case listening
  /// Attesa della trascrizione definitiva della parola appena letta.
  case flushing
  /// Modalità Scrivi: il Mac ha detto la parola, si aspetta la tastiera.
  case typing
  case scoring
  case feedback(Bool)
  case interTrial
  /// Pausa proposta ogni N parole: si riprende solo quando si è pronti.
  case pausa
  case finished
  case failed(String)
}

/// Motore della sessione: presenta gli stimoli con precisione al frame, ascolta la
/// risposta vocale, la valuta e decide l'esposizione successiva. Non richiede
/// alcun intervento dell'operatore durante la prova.
@MainActor
final class SessionEngine: ObservableObject {

  @Published var config = SessionConfig()
  /// Preferenze di aspetto e ritmo di chi sta usando l'app adesso.
  @Published var a11y = A11ySettings() {
    didSet {
      speaker.voiceIdentifier = a11y.voiceIdentifier
      speaker.rate = Float(a11y.voiceRate)
    }
  }
  /// Testo digitato in modalità Scrivi.
  @Published var typedAnswer = ""
  /// Vero durante il test iniziale che misura la velocità di partenza.
  @Published private(set) var isCalibration = false
  /// Obiettivi sbloccati alla fine della sessione, da mostrare una volta sola.
  @Published var justUnlocked: [Achievement] = []
  /// Proposta automatica di alzare o abbassare il livello.
  @Published var difficultySuggestion: Difficulty.Suggestion = .resta
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var displayText = ""

  /// Perche il turno e finito senza una parola. Vuoto quando non c'e niente da
  /// dire. Un turno andato a vuoto ha due cause opposte — un microfono che non
  /// arriva e una parola che non si e capita — e per chi sta davanti allo
  /// schermo sono due situazioni diversissime: nella prima non c'e niente da
  /// riprovare finche non si sistema l'audio.
  @Published private(set) var ascoltoAvviso: String?

  /// Quando e cominciato l'allenamento. Serve solo all'orologio in alto, che si
  /// vede se lo si e chiesto.
  @Published private(set) var sessionStartedAt: Date?

  /// Vero quando il microfono sta ricevendo una voce **adesso**, misurata sul
  /// rumore di fondo di questa stanza e non su una soglia decisa a tavolino.
  /// Serve a non scrivere "ti sento" nel silenzio: se lo dice sempre, quella
  /// scritta smette di essere un'informazione e diventa un ornamento.
  @Published private(set) var voceInCorso = false

  /// L'ultimo microfono scelto a mano durante l'allenamento, e se il cambio ha
  /// gia avuto effetto. Cambiare cuffie a meta sessione e normale; scoprire
  /// dopo tre parole andate a vuoto che il Mac stava ancora ascoltando dal
  /// microfono di prima, no.
  @Published private(set) var cambioMicrofonoInCorso = false
  @Published private(set) var trials: [Trial] = []
  @Published private(set) var trialIndex = 0
  @Published private(set) var totalTrials = 0
  @Published private(set) var liveTranscript = ""
  @Published private(set) var micLevel: Float = 0
  @Published private(set) var summary: ClinicalSummary?
  @Published private(set) var summarizing = false
  @Published var statusMessage = ""

  private let listener = SpeechListener()
  private let sorveglianzaMicrofono = SorveglianzaMicrofono()
  let speaker = Speaker()
  let suoni = Suoni()
  private var wordsSincePause = 0
  private var items: [String] = []
  private var staircase: StaircaseState?
  private var deadline: CFTimeInterval = 0
  private var stimulusOnset: CFTimeInterval = 0
  private var stimulusOffset: CFTimeInterval = 0
  private var listeningStart: CFTimeInterval = 0
  private var flushStart: CFTimeInterval = 0
  private var current: Trial?
  private var scoringTask: Task<Void, Never>?
  /// Frame disegnati durante l'esposizione in corso, e se ne è stato saltato
  /// qualcuno.
  private var frameEffettivi = 0
  private var frameSaltato = false
  private var ultimoFrame: CFTimeInterval = 0

  /// Identifica la sessione in corso.
  ///
  /// Serve perché quasi tutto qui dentro passa da un compito asincrono che
  /// finisce dopo: il riconoscitore che si accende, il modello che etichetta
  /// un errore, il riassunto finale. Se nel frattempo qualcuno preme
  /// «Interrompi» e ricomincia, quei compiti tornano e scrivono dentro la
  /// sessione **nuova** il risultato della vecchia — una parola che nessuno ha
  /// letto in questa sessione, in mezzo ai dati di un bambino. Prima di
  /// toccare qualunque stato ci si accerta di essere ancora la sessione che
  /// aveva cominciato.
  private var sessionID = UUID()

  /// Vero se il compito che sta parlando appartiene ancora alla sessione viva.
  private func èAncoraMia(_ id: UUID) -> Bool { id == sessionID }

  var isRunning: Bool {
    switch phase {
    case .idle, .finished, .failed: false
    default: true
    }
  }

  var thresholdMs: Double? { staircase?.threshold }

  /// Tempo concesso per rispondere, allungato quando il profilo lo richiede.
  private var responseTimeout: Double { config.responseTimeoutMs * a11y.extraResponseTime }

  var currentExposureMs: Double { staircase?.exposure ?? config.exposureMs }

  /// Vero durante le prime parole: si vedono benissimo e non contano per la soglia.
  var isWarmup: Bool { trialIndex <= config.warmupTrials }

  /// Quanto resta davvero visibile la parola in corso.
  var effectiveExposureMs: Double {
    isWarmup ? min(currentExposureMs * 3, 1500) : currentExposureMs
  }

  // MARK: - Avvio e arresto

  init() {
    // Due cose interrompono un turno senza che il ragazzo c'entri niente: il
    // Mac che si addormenta e il microfono che sparisce. Il sistema le sa
    // entrambe e le dice — tacerle vorrebbe dire scrivere «non ha risposto»
    // nel referto di qualcuno che non era stato interrogato.
    // Il gettone dell'osservatore va conservato: senza, ogni motore creato
    // (prove, anteprime, azzeramenti) ne lascia dietro uno vivo, e un solo
    // sonno del Mac finisce per interrompere il turno più volte.
    osservatoreSonno = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in
          self?.interrompi(motivo: "Il Mac si è addormentato: questa parola non conta. Quando vuoi, si riprende da qui.")
        }
      }
    sorveglianzaMicrofono.suMicrofonoSparito = { [weak self] in
      self?.interrompi(motivo: "Il microfono non c'è più: forse si sono staccate le cuffie. Questa parola non conta. Ricollegalo e si riprende da qui.")
    }
  }

  /// Gettone dell'osservatore del sonno, da restituire quando il motore muore.
  private var osservatoreSonno: NSObjectProtocol?

  deinit {
    if let osservatoreSonno {
      NSWorkspace.shared.notificationCenter.removeObserver(osservatoreSonno)
    }
  }

  /// Avvia una sessione. `words` serve per il ripasso delle parole sbagliate;
  /// `calibration` per il test iniziale che misura la velocità di partenza.
  func start(words: [String]? = nil, calibration: Bool = false) {
    items = words ?? config.resolvedItems
    guard !items.isEmpty else {
      statusMessage = "La lista di parole è vuota."
      return
    }
    // Prima di ogni altra cosa: quanto in fretta lampeggerà questo schermo.
    //
    // Parole ad alto contrasto che si alternano a una maschera sono
    // esattamente l'alternanza che può scatenare una crisi in chi ha
    // un'epilessia fotosensibile, e questa app la usa un ragazzo da solo:
    // nessun adulto accanto a fermarlo. Sopra tre volte al secondo non si
    // parte, e si dice perché — un rifiuto senza spiegazione sembra un guasto,
    // e chi lo legge cerca il modo di aggirarlo.
    if config.oltreIlLimiteDiLampeggio, !config.lampeggioVeloceConsentito {
      let attuale = String(format: "%.1f", config.ritmoDaDireHz)
      let minima = Int(SessionConfig.durataCicloMinimaMs.rounded())
      phase = .failed("""
        Con questi tempi lo schermo cambierebbe \(attuale) volte al secondo. \
        Sopra tre volte al secondo un'alternanza così può far male a chi ha \
        un'epilessia fotosensibile, quindi l'allenamento non parte.

        Per rientrare basta allungare la pausa fra una parola e l'altra, o il \
        segno di partenza, finché il giro completo dura almeno \(minima) \
        millesimi di secondo. Se serve davvero un ritmo più veloce, un adulto \
        può consentirlo da «Per l'adulto».
        """)
      return
    }

    // Da qui in poi la sessione è un'altra: i compiti ancora in volo che
    // appartenevano a quella di prima non devono più poter scrivere niente.
    scoringTask?.cancel()
    scoringTask = nil
    sessionID = UUID()
    let mia = sessionID
    trials = []
    trialIndex = 0
    totalTrials = items.count
    summary = nil
    justUnlocked = []
    difficultySuggestion = .resta
    typedAnswer = ""
    wordsSincePause = 0
    isCalibration = calibration
    staircase = StaircaseState(config: config)
    finishedRecord = nil

    // In modalità Scrivi non serve il microfono: si salta tutta la parte vocale.
    guard config.mode == .lettura else {
      phase = .instructions
      statusMessage = ""
      return
    }

    phase = .preparing
    statusMessage = "Un attimo: preparo l'ascolto sul Mac…"

    Task {
      guard await SpeechListener.requestPermissions() else {
        guard èAncoraMia(mia) else { return }
        phase = .failed(ListenerError.notAuthorized.errorDescription ?? "Servono i permessi per microfono e riconoscimento vocale.")
        return
      }
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"), vocabulary: items)
        guard èAncoraMia(mia) else { await listener.stop(); return }
        sorveglianzaMicrofono.inizia(su: AudioDevices.defaultInput())
        statusMessage = ""
        phase = .instructions
      } catch {
        guard èAncoraMia(mia) else { return }
        phase = .failed(error.localizedDescription)
      }
    }
  }

  func abort() {
    scoringTask?.cancel()
    scoringTask = nil
    // Cambiando identificativo, tutto quello che è ancora in volo diventa
    // roba di una sessione che non esiste più, e viene lasciato cadere.
    sessionID = UUID()
    displayText = ""
    Task { await listener.stop() }
    finish(interrupted: true)
  }

  /// Qualcosa che non c'entra con chi legge ha interrotto il turno: il Mac si è
  /// addormentato, la finestra è passata dietro a un'altra, il microfono è
  /// sparito.
  ///
  /// La parola in corso finisce nei dati **marcata come interrotta**, non come
  /// omissione. La differenza non è formale: un'omissione dice che un ragazzo
  /// non ha risposto, e scriverlo quando nessuno gli aveva chiesto niente
  /// significa mettere nel suo referto una cosa falsa.
  func interrompi(motivo: String) {
    guard isRunning else { return }
    guard !phaseÈFerma else { return }

    if var trial = current {
      trial.interrotto = true
      trial.motivoInterruzione = motivo
      trial.response = ""
      trial.correct = false
      trial.errorKind = .none
      scoringTask?.cancel()
      scoringTask = nil
      listener.endWindow()
      suoni.microfonoInAscolto = false
      voceInCorso = false
      registraInterrotta(trial)
    }

    displayText = ""
    phase = .pausa
    ascoltoAvviso = motivo
  }

  /// Le fasi in cui non c'è nessun turno da interrompere: fermarsi qui sarebbe
  /// solo un fastidio.
  ///
  /// `.scoring` è in elenco e non è una svista: lì la parola è già stata letta
  /// e già trascritta, manca solo l'etichetta dell'errore. Interrompere in quel
  /// punto butterebbe via una risposta vera — una parola letta bene
  /// diventerebbe un turno interrotto perché la finestra ha perso il fuoco
  /// mentre il modello lavorava.
  private var phaseÈFerma: Bool {
    switch phase {
    case .idle, .preparing, .instructions, .pausa, .finished, .failed, .scoring: true
    default: false
    }
  }

  /// Mette via una prova interrotta senza far finta che sia stata giocata.
  ///
  /// Non passa da `commit` di proposito: `commit` suona «Ancora», fa
  /// pronunciare la parola giusta e accende il pallino del riscontro. Tutte
  /// cose che, dette per una parola che il ragazzo non ha mai visto, sono un
  /// rimprovero per una cosa che non ha fatto lui — e arriverebbero un istante
  /// dopo avergli scritto che quella parola non conta.
  private func registraInterrotta(_ trial: Trial) {
    trials.append(trial)
    current = nil
    // Niente `staircase.update`: un turno fermato dal Mac non dice niente su
    // chi legge, e farlo pesare sulla soglia vorrebbe dire misurare il Mac.
  }

  /// Il test iniziale: poche parole a velocità che cala in fretta, per capire
  /// da dove partire senza far annoiare né frustrare.
  func startCalibration() {
    var c = config
    c.mode = .lettura
    c.level = .personalizzato
    c.set = .bisillabe
    c.trials = 8
    c.warmupTrials = 1
    c.exposureMs = 800
    c.staircase = .twoDownOneUp
    c.stepMs = 90
    c.minExposureMs = 60
    config = c
    start(calibration: true)
  }

  /// Chiamato dalla schermata di istruzioni, quando chi legge dice di essere pronto.
  func beginTrials() {
    guard case .instructions = phase else { return }
    phase = .countdown(3)
    deadline = 0
    sessionStartedAt = Date()
  }

  /// Passa a un altro microfono senza uscire dall'allenamento.
  ///
  /// Il motore audio si lega al microfono che trova quando nasce: non basta
  /// cambiare l'ingresso del Mac, va rifatto tutto l'ascolto. Dura meno di un
  /// secondo, ma va detto — durante quel secondo l'app non sente, e restare in
  /// silenzio qui vorrebbe dire far parlare qualcuno nel vuoto.
  func cambiaMicrofono(_ id: AudioDeviceID) {
    guard config.mode == .lettura else {
      AudioDevices.setDefaultInput(id)
      return
    }
    guard !cambioMicrofonoInCorso else { return }
    cambioMicrofonoInCorso = true
    let mia = sessionID
    Task {
      await listener.stop()
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"),
                                 vocabulary: items,
                                 preferredInput: id)
        guard èAncoraMia(mia) else { await listener.stop(); return }
        // La sorveglianza deve guardare il microfono **in uso**, non quello
        // che era predefinito quando è partita la sessione: altrimenti
        // staccare le cuffie che si stanno usando non viene visto, e staccare
        // un microfono vecchio e inutilizzato ferma il turno per niente.
        sorveglianzaMicrofono.inizia(su: id)
      } catch {
        guard èAncoraMia(mia) else { return }
        phase = .failed(error.localizedDescription)
      }
      guard èAncoraMia(mia) else { return }
      cambioMicrofonoInCorso = false
    }
  }

  // MARK: - Orologio

  /// Se adesso serve il battito del display.
  ///
  /// La regola è semplice e si controlla a occhio: **il battito serve se e
  /// solo se `tick` fa qualcosa**. L'elenco qui sotto è lo stesso elenco di
  /// fasi in cui `tick` esce subito senza toccare niente; se le due liste si
  /// allontanano, l'app ridisegna lo schermo sessanta volte al secondo per
  /// eseguire un `return`. Una prova in `Verifiche/Battito.swift` le tiene
  /// insieme.
  ///
  /// Le fasi che contano non sono un dettaglio: in pausa e mentre si scrive si
  /// resta fermi anche per minuti. È lì che si sentiva la ventola partire e la
  /// batteria scendere — cioè una sessione interrotta a metà.
  var serveIlBattito: Bool { Self.serveIlBattito(in: phase) }

  /// La regola, staccata dal motore perche' si possa provare fase per fase
  /// senza dover portare una sessione vera fin li'.
  static func serveIlBattito(in fase: Phase) -> Bool {
    switch fase {
    case .idle, .preparing, .instructions, .typing, .pausa, .scoring,
         .finished, .failed:
      false
    default:
      true
    }
  }


  /// Chiamato una volta per frame dal display link della finestra di presentazione.
  ///
  /// `durataFrame` è quanto dura un frame **sullo schermo dove sta la
  /// finestra**, misurato dal display link. Prima si chiedeva a
  /// `NSScreen.main`, che è lo schermo dove c'è il fuoco della tastiera: con
  /// due schermi a frequenza diversa il numero era di un altro monitor, e la
  /// tolleranza con cui si chiude l'esposizione risultava sbagliata proprio
  /// nella cosa che questa app misura.
  /// È la durata **nominale**, non quella dell'ultimo fotogramma: su uno
  /// schermo a frequenza variabile la seconda oscilla per costruzione, e
  /// usarla come metro faceva dichiarare 24 Hz su un display a 120.
  func tick(_ now: CFTimeInterval, durataFrame: CFTimeInterval) {
    if durataFrame > 0 { ultimaDurataFrame = durataFrame }
    let snap = listener.read()
    // Solo se è cambiato davvero.
    //
    // `@Published` avvisa a ogni assegnazione, anche quando il valore è
    // identico. Assegnando il livello sessanta volte al secondo, tutta l'app
    // che osserva il motore si ridisegnava sessanta volte al secondo — anche
    // ferma in home, con il microfono spento e il livello inchiodato a zero.
    // Costava un terzo di un core e batteria per non mostrare niente, e con
    // quel ritmo l'albero di accessibilità non riusciva più a essere letto:
    // chi usa VoiceOver rischiava di trovare una schermata muta.
    if abs(micLevel - snap.level) > 0.002 { micLevel = snap.level }

    switch phase {
    case .idle, .preparing, .instructions, .typing, .pausa, .scoring, .finished, .failed:
      return

    case .countdown(let n):
      if deadline == 0 { deadline = now + 1; return }
      guard now >= deadline else { return }
      if n > 1 {
        phase = .countdown(n - 1)
        deadline = now + 1
      } else {
        startTrial(at: now)
      }

    case .fixation:
      // Il segno di partenza lo disegna la scena (un cerchietto, non un
      // carattere): qui il testo resta vuoto apposta, perché qualunque cosa ci
      // mettessimo qualcuno proverebbe a leggerla.
      displayText = ""
      guard now >= deadline else { return }
      if config.maskMode == .both, config.maskMs > 0 {
        phase = .preMask
        displayText = mask()
        deadline = now + config.maskMs / 1000
      } else {
        enterStimulus(at: now)
      }

    case .preMask:
      guard now >= deadline else { return }
      enterStimulus(at: now)

    case .stimulus:
      // Si contano i frame davvero disegnati e si guarda se ne è stato saltato
      // qualcuno: un frame saltato vuol dire che la parola è rimasta sullo
      // schermo più a lungo di quanto dice il referto, e per un tachistoscopio
      // è la differenza fra una misura e un'impressione.
      frameEffettivi += 1
      // Il primo fotogramma della parola non ha un precedente con cui
      // confrontarsi, e proprio l'accensione è il momento in cui il Mac salta
      // più spesso: si usa l'istante in cui la parola è comparsa.
      let precedente = ultimoFrame > 0 ? ultimoFrame : stimulusOnset
      if precedente > 0, now - precedente > ultimaDurataFrame * 1.5 { frameSaltato = true }
      ultimoFrame = now
      guard now >= deadline - halfFrame(now) else { return }
      stimulusOffset = now
      current?.actualExposureMs = (now - stimulusOnset) * 1000
      current?.refreshHz = refreshHz
      current?.frameEffettivi = frameEffettivi
      current?.frameSaltato = frameSaltato
      if config.maskMode != .none, config.maskMs > 0 {
        phase = .postMask
        displayText = mask()
        deadline = now + config.maskMs / 1000
      } else {
        enterListening(at: now)
      }

    case .postMask:
      guard now >= deadline else { return }
      enterListening(at: now)

    case .listening:
      liveTranscript = snap.text
      voceInCorso = snap.lastVoice.map { now - $0 < 0.4 } ?? false
      let elapsed = now - listeningStart
      let silent = snap.lastUpdate.map { now - $0 >= config.endpointSilenceMs / 1000 } ?? false
      let heard = !snap.text.isEmpty && silent

      // La voce si è fermata: è il momento di chiedere la trascrizione.
      //
      // Qui c'era il cane che si mordeva la coda, ed è la vera ragione per cui
      // ogni parola sembrava impiegare un'eternità. Si chiedeva la consegna
      // solo quando c'era già del testo — ma il testo, a parola singola, non
      // arriva finché non lo si chiede. Le due condizioni si aspettavano a
      // vicenda, e l'unica via d'uscita restava il tempo scaduto: quattro
      // secondi buoni dopo l'ultima sillaba, ogni volta, anche quando la
      // parola era stata detta perfettamente al primo colpo.
      //
      // Adesso basta il silenzio del microfono, che si misura senza bisogno di
      // nessuna trascrizione: uno smette di parlare, e in mezzo secondo sa.
      let vocePoiSilenzio = snap.voiceOnset != nil
        && (snap.lastVoice.map { now - $0 >= config.endpointSilenceMs / 1000 } ?? false)
      // Quando la parola è già quella giusta, non c'è niente da aspettare.
      //
      // È il motivo per cui l'app sembrava lenta: uno leggeva "casa", e poi
      // restava mezzo secondo di silenzio più l'attesa del testo definitivo
      // prima di vedere qualcosa. Un secondo e mezzo di niente, con la parola
      // ancora coperta davanti: chi non è sicuro di sé lo legge come "non mi
      // ha sentito" e ripete — e la ripetizione, quella sì, rovinava la
      // risposta. Se il testo provvisorio combacia già con lo stimolo il
      // verdetto non può cambiare, quindi si chiude subito.
      if !snap.text.isEmpty, let stimolo = current?.stimulus,
         Scoring.combaciaGia(stimolo: stimolo, testo: snap.text) {
        closeListening(snapshot: snap)
        return
      }
      // Il tempo non scade mentre qualcuno sta ancora parlando.
      //
      // Chiudere il turno a meta di una parola e la seconda ragione per cui
      // l'app sembrava sorda: chi comincia a parlare in ritardo — ed e la
      // norma per chi stiamo aiutando — si vedeva tagliare la voce a meta e
      // trovava "Ancora" senza capire perche. Il tetto esiste lo stesso,
      // altrimenti un rumore continuo terrebbe aperto il turno per sempre.
      let staParlando = snap.lastVoice.map { now - $0 < 0.4 } ?? false
      let scaduto = elapsed >= responseTimeout / 1000
      let oltreOgniAttesa = elapsed >= (responseTimeout / 1000) * 2.5
      let timedOut = (scaduto && !staParlando) || oltreOgniAttesa
      if heard || vocePoiSilenzio || timedOut {
        // Prima di giudicare bisogna chiedere all'analizzatore quello che ha
        // sentito: da solo, a parola singola, non lo dice.
        requestFinalTranscript()
      }

    case .flushing:
      // Si aspetta il testo definitivo, ma non all'infinito: mezzo secondo è
      // il triplo di quanto serve in pratica.
      let waited = now - flushStart
      // Se il microfono ha sentito una voce ma non e ancora arrivato nessun
      // testo, val la pena aspettare di piu: dichiarare "non hai detto niente"
      // a chi ha appena parlato e il modo piu rapido per far smettere qualcuno
      // di provarci.
      let attesaMassima = (snap.voiceOnset != nil && snap.text.isEmpty) ? 1.2 : 0.5
      if snap.isFinal || waited > attesaMassima {
        closeListening(snapshot: listener.read())
      }

    case .feedback:
      guard now >= deadline else { return }
      displayText = ""
      phase = .interTrial
      deadline = now + config.interTrialMs / 1000

    case .interTrial:
      guard now >= deadline else { return }
      guard trialIndex < items.count else {
        Task { await listener.stop() }
        finish(interrupted: false)
        return
      }
      if a11y.pauseEveryNWords > 0, wordsSincePause >= a11y.pauseEveryNWords {
        phase = .pausa
        displayText = ""
        return
      }
      startTrial(at: now)
    }
  }

  /// Mezzo frame di tolleranza: chiudere lo stimolo al frame più vicino al bersaglio
  /// è più accurato che chiuderlo al primo frame che lo supera.
  private func halfFrame(_ now: CFTimeInterval) -> CFTimeInterval {
    ultimaDurataFrame / 2
  }

  /// Quanto dura un frame sullo schermo della finestra, aggiornato a ogni
  /// battito. Il valore iniziale vale solo per i pochi millesimi prima del
  /// primo frame, e per le prove che chiamano `tick` senza un display link.
  /// Quanto dura **di regola** un fotogramma su questo schermo: è il metro con
  /// cui si decide la tolleranza, la frequenza da scrivere nel referto e
  /// quanti fotogrammi serve tenere accesa la parola.
  private var ultimaDurataFrame: CFTimeInterval = 1.0 / 60.0

  /// La frequenza dello schermo su cui si sta davvero presentando, in hertz.
  /// Finisce nel referto: senza, la durata richiesta e quella ottenuta non
  /// sono confrontabili fra due Mac diversi.
  var refreshHz: Double { ultimaDurataFrame > 0 ? 1 / ultimaDurataFrame : 60 }

  // MARK: - Fasi della prova

  private func startTrial(at now: CFTimeInterval) {
    let stimulus = items[trialIndex]
    trialIndex += 1
    var t = Trial(id: trialIndex, stimulus: stimulus)
    t.requestedExposureMs = effectiveExposureMs
    current = t
    liveTranscript = ""
    typedAnswer = ""

    if config.mode == .scrittura {
      phase = .typing
      displayText = ""
      speaker.say(stimulus)
      return
    }

    if config.fixationMs > 0 {
      phase = .fixation
      displayText = ""
      deadline = now + config.fixationMs / 1000
    } else {
      enterStimulus(at: now)
    }
  }

  private func enterStimulus(at now: CFTimeInterval) {
    phase = .stimulus
    displayText = current?.stimulus ?? ""
    stimulusOnset = now
    deadline = now + effectiveExposureMs / 1000
    frameEffettivi = 0
    frameSaltato = false
    ultimoFrame = 0
    current?.frameRichiesti = max(1, Int(((effectiveExposureMs / 1000) / ultimaDurataFrame).rounded()))
    // Il microfono comincia a contare da qui, non dopo la maschera.
    //
    // Prima la finestra si apriva alla fine della maschera, e chi rispondeva di
    // scatto — cioe chi aveva letto benissimo — parlava dentro un intervallo
    // che nessuno stava guardando: la parola andava persa e l'app sembrava
    // sorda proprio con chi era piu veloce.
    listener.beginWindow(trialID: current?.id ?? trialIndex)
    // Finché il microfono ascolta l'app resta zitta: altrimenti si sente da
    // sola e giudica il proprio suono come se fosse una parola letta.
    suoni.microfonoInAscolto = true
  }

  /// Modalità Scrivi: si consegna quello che si è digitato.
  func submitTyped() {
    guard case .typing = phase, var trial = current else { return }
    trial.response = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    let verdict = Scoring.classify(target: trial.stimulus, response: trial.response)
    trial.correct = verdict.correct
    trial.errorKind = trial.response.isEmpty ? .omissioneTotale : verdict.kind
    trial.editDistance = verdict.distance
    trial.actualExposureMs = 0
    phase = .scoring
    commit(trial)
  }

  /// Modalità Scrivi: ripete la parola, quante volte serve.
  func repeatWord() {
    guard case .typing = phase, let t = current else { return }
    speaker.say(t.stimulus)
  }

  /// Rilegge ad alta voce una singola parola: o una del dettato, o una di
  /// quelle appena scritte.
  ///
  /// Su una frase intera "ripeti tutto" non basta. Chi sta imparando a
  /// scrivere non sbaglia la frase: sbaglia una parola dentro la frase, e per
  /// trovarla deve poter sentire quella e solo quella. E il modo in cui si
  /// lavora nella riabilitazione della disortografia — si isola il pezzo, non
  /// si ricomincia da capo.
  ///
  /// Piu lenta del dettato, perche qui non si sta piu misurando: si sta
  /// controllando.
  func sayWord(_ word: String) {
    speaker.say(word, rate: max(0.26, Float(a11y.voiceRate) - 0.08))
  }

  /// Chiede la trascrizione definitiva della parola appena letta e passa in
  /// attesa: la risposta arriva in poche decine di millesimi.
  private func requestFinalTranscript() {
    guard case .listening = phase else { return }
    guard let prova = current?.id else { return }
    phase = .flushing
    flushStart = CACurrentMediaTime()
    let mia = sessionID
    Task {
      let servita = await listener.flush(trialID: prova)
      guard èAncoraMia(mia) else { return }
      if !servita {
        // La chiusura è arrivata quando la finestra era già di un'altra prova.
        // Non si aspetta un testo che non arriverà: si chiude subito con
        // quello che c'è, altrimenti il turno resta appeso mezzo secondo per
        // niente.
        if case .flushing = phase { closeListening(snapshot: listener.read()) }
      }
    }
  }

  private func enterListening(at now: CFTimeInterval) {
    // La parola non sparisce: resta coperta dov'era.
    //
    // Prima lo schermo si svuotava e comparivano altrove le istruzioni per
    // parlare: tre scene diverse per una cosa sola, e chi guardava perdeva il
    // filo — parlava mentre la parola era ancora li, o taceva perche non aveva
    // capito che toccava a lui. Adesso il riquadro centrale non cambia mai
    // posizione e le barre restano: quello che cambia e solo l'invito sotto.
    displayText = mask()
    phase = .listening
    listeningStart = now
  }

  private func closeListening(snapshot snap: VoiceWindowSnapshot) {
    listener.endWindow()
    suoni.microfonoInAscolto = false
    voceInCorso = false
    phase = .scoring
    guard var trial = current else { return }
    let mia = sessionID

    // La risposta appartiene a questa parola, o a quella di prima?
    //
    // È il difetto che rendeva i dati inaffidabili senza che si vedesse:
    // niente andava in crash, il referto era pieno, e dentro c'era la parola
    // sbagliata attribuita al ragazzo sbagliato. Se l'identificativo non
    // combacia il testo si butta — e lo si scrive nella prova, invece di
    // lasciar credere che non abbia risposto.
    if let id = snap.trialID, id != trial.id {
      Log.warn("Risposta arrivata per la prova \(id) mentre siamo alla \(trial.id): scartata.")
      trial.response = ""
      trial.interrotto = true
      trial.motivoInterruzione = "La risposta è arrivata fuori tempo e non si poteva attribuire con certezza."
      trial.errorKind = .none
      trial.correct = false
      ascoltoAvviso = "Questa parola non l'ho potuta contare: la risposta è arrivata in ritardo. Non è colpa tua."
      commit(trial)
      return
    }

    trial.response = snap.text
    trial.confidence = snap.confidence

    if snap.text.isEmpty {
      // Tre cause diverse, e confonderle e' il modo piu rapido per far
      // credere a un ragazzo di aver letto male quando ha letto benissimo.
      //
      // Misurato con la prova del microfono: con il picco a 0,02 il
      // riconoscitore non consegna una sola parola, con 0,075 la consegna in
      // mezzo secondo e con confidenza 0,83. In mezzo non c'e' niente da
      // capire meglio: c'e' un volume da alzare. L'app il livello ce l'ha,
      // quindi lo dice invece di far ripetere.
      ascoltoAvviso = snap.voiceOnset == nil
        ? "Non ho sentito niente. Controlla il microfono qui in alto."
        : snap.picco < 0.04
        ? "Ti ho sentito, ma pianissimo: il Mac non arriva a capire le parole. Parla più vicino al microfono, o provalo dal menu qui in alto."
        : "Ti ho sentito, ma non sono riuscita a capire le parole."
    } else {
      ascoltoAvviso = nil
    }
    if let onset = snap.voiceOnset {
      trial.vocalLatencyMs = max(0, (onset - stimulusOffset) * 1000)
    }

    let verdict = Scoring.classify(target: trial.stimulus, response: trial.response)
    trial.correct = verdict.correct
    trial.errorKind = verdict.kind
    trial.editDistance = verdict.distance

    scoringTask = Task { [config] in
      // Il verdetto resta quello del confronto testuale: riproducibile e verificabile.
      // Il modello on-device aggiunge solo l'etichetta clinica dell'errore.
      if config.useAppleIntelligence, !verdict.correct, verdict.kind != .omissioneTotale,
         let judgement = await Intelligence.judge(target: trial.stimulus, transcript: trial.response) {
        trial.note = judgement.categoria
      }
      // Segnalazione basata sul dato, non sull'opinione del modello: sotto questa
      // confidenza la trascrizione è inaffidabile e la prova va riascoltata.
      if let c = trial.confidence, c < 0.5 {
        trial.note = trial.note.isEmpty
          ? "confidenza di trascrizione bassa — da verificare"
          : "\(trial.note) — confidenza di trascrizione bassa"
      }
      // Il modello ci mette un momento a rispondere, e in quel momento
      // qualcuno può aver interrotto e ricominciato. Questa parola appartiene
      // alla sessione di prima: dentro quella nuova non c'entra niente.
      guard !Task.isCancelled, èAncoraMia(mia) else { return }
      commit(trial)
    }
  }

  private func commit(_ trial: Trial) {
    trials.append(trial)
    // Le parole di riscaldamento non spostano la soglia: servono solo a prendere la mano.
    // E nemmeno le prove interrotte: un turno che si è fermato perché il Mac
    // si è addormentato o il microfono è sparito non dice niente su chi legge,
    // e farlo pesare sulla soglia vorrebbe dire misurare il Mac invece del
    // ragazzo.
    if trial.id > config.warmupTrials, !trial.interrotto {
      staircase?.update(correct: trial.correct)
    }
    current = nil

    // Rileggere la parola giusta serve a chi vede poco e a chi ha sbagliato:
    // chiude il cerchio invece di lasciare il dubbio.
    if a11y.speakCorrectWord || (config.mode == .scrittura && !trial.correct) {
      speaker.say(trial.stimulus)
    }

    wordsSincePause += 1
    let now = CACurrentMediaTime()
    // Un riscontro anche per le orecchie: serve a chi lo schermo fatica a
    // guardarlo. «Ancora» non suona mai come un errore, sono due tocchi alla
    // stessa altezza.
    suoni.suona(trial.correct ? .giusta : .ancora, a11y: a11y)
    if a11y.showFeedbackPerWord {
      phase = .feedback(trial.correct)
      displayText = ""
      deadline = now + 0.6
    } else {
      phase = .interTrial
      deadline = now + config.interTrialMs / 1000
    }
  }

  /// Riprende dopo una pausa.
  ///
  /// Se la pausa è arrivata da un'interruzione — cuffie staccate, Mac
  /// addormentato — non basta ripartire: il motore audio si lega al microfono
  /// che trova quando nasce, e quel microfono non c'è più. Riprendere e basta
  /// significava che **ogni parola successiva diventava «Non ho sentito
  /// niente»**: esattamente la fila di omissioni che l'interruzione doveva
  /// evitare, spostata di un minuto. Il messaggio prometteva «ricollegalo e si
  /// riprende da qui»: adesso è vero.
  func resumeFromPause() {
    guard case .pausa = phase else { return }
    wordsSincePause = 0

    guard ascoltoAvviso != nil, config.mode == .lettura else {
      ascoltoAvviso = nil
      riparti()
      return
    }

    ascoltoAvviso = nil
    phase = .preparing
    statusMessage = "Un attimo: riaccendo l'ascolto…"
    let mia = sessionID
    Task {
      await listener.stop()
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"), vocabulary: items)
        guard èAncoraMia(mia) else { await listener.stop(); return }
        sorveglianzaMicrofono.inizia(su: AudioDevices.defaultInput())
        statusMessage = ""
        riparti()
      } catch {
        guard èAncoraMia(mia) else { return }
        // Anche qui si dice che cosa è successo invece di tornare in pausa in
        // silenzio: senza microfono l'allenamento di lettura non può andare
        // avanti, e girare a vuoto sarebbe peggio.
        phase = .failed(error.localizedDescription)
      }
    }
  }

  private func riparti() {
    if config.mode == .scrittura {
      startTrial(at: CACurrentMediaTime())
    } else {
      phase = .interTrial
      deadline = CACurrentMediaTime() + 0.3
    }
  }

  private func mask() -> String {
    let n = max(3, (current?.stimulus.count ?? 5))
    return String(repeating: "#", count: n)
  }

  private func finish(interrupted: Bool) {
    sorveglianzaMicrofono.fermati()
    displayText = ""
    liveTranscript = ""
    speaker.stop()
    phase = .finished
    statusMessage = interrupted ? "Sessione interrotta." : ""

    let record = makeRecord()
    if !interrupted {
      suoni.suona(
        .fine,
        quota: record.total > 0 ? Double(record.correct) / Double(record.total) : 1,
        a11y: a11y)
    }
    finishedRecord = record
    if !isCalibration {
      difficultySuggestion = Difficulty.suggestion(for: record, current: config.level)
    }
    guard !trials.isEmpty, config.useAppleIntelligence, Intelligence.isAvailable else { return }
    summarizing = true
    Task { [config, trials, thresholdMs] in
      summary = await Intelligence.summarize(trials: trials, thresholdMs: thresholdMs, config: config)
      summarizing = false
    }
  }

  // MARK: - Registro

  /// La sessione appena chiusa, pronta per essere salvata e mostrata.
  @Published private(set) var finishedRecord: SessionRecord?

  /// I conti del referto stanno in `RegistroSessione`: sono regole cliniche
  /// pure — quali prove entrano nel totale — e lì si possono provare senza
  /// accendere un microfono.
  private func makeRecord() -> SessionRecord {
    RegistroSessione.referto(prove: trials, config: config, sogliaMs: thresholdMs)
  }

  /// Velocità di partenza suggerita dal test iniziale.
  var calibrationResult: (exposureMs: Double, level: Level)? {
    guard isCalibration else { return nil }
    return RegistroSessione.partenzaSuggerita(prove: trials, sogliaMs: thresholdMs)
  }

  // MARK: - Esportazione

  /// Torna alla schermata iniziale buttando via la sessione appena chiusa.
  func reset() {
    trials = []
    trialIndex = 0
    totalTrials = 0
    summary = nil
    displayText = ""
    liveTranscript = ""
    statusMessage = ""
    phase = .idle
  }

}
