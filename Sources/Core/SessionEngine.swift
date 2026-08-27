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

  /// Avvia una sessione. `words` serve per il ripasso delle parole sbagliate;
  /// `calibration` per il test iniziale che misura la velocità di partenza.
  func start(words: [String]? = nil, calibration: Bool = false) {
    items = words ?? config.resolvedItems
    guard !items.isEmpty else {
      statusMessage = "La lista di parole è vuota."
      return
    }
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
        phase = .failed(ListenerError.notAuthorized.errorDescription ?? "Servono i permessi per microfono e riconoscimento vocale.")
        return
      }
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"), vocabulary: items)
        statusMessage = ""
        phase = .instructions
      } catch {
        phase = .failed(error.localizedDescription)
      }
    }
  }

  func abort() {
    scoringTask?.cancel()
    displayText = ""
    Task { await listener.stop() }
    finish(interrupted: true)
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
    Task {
      await listener.stop()
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"),
                                 vocabulary: items,
                                 preferredInput: id)
      } catch {
        phase = .failed(error.localizedDescription)
      }
      cambioMicrofonoInCorso = false
    }
  }

  // MARK: - Orologio

  /// Chiamato una volta per frame dal display link della finestra di presentazione.
  func tick(_ now: CFTimeInterval) {
    let snap = listener.read()
    micLevel = snap.level

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
      guard now >= deadline - halfFrame(now) else { return }
      stimulusOffset = now
      current?.actualExposureMs = (now - stimulusOnset) * 1000
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
    let refresh = NSScreen.main?.maximumFramesPerSecond ?? 60
    return 0.5 / Double(max(refresh, 1))
  }

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
    // Il microfono comincia a contare da qui, non dopo la maschera.
    //
    // Prima la finestra si apriva alla fine della maschera, e chi rispondeva di
    // scatto — cioe chi aveva letto benissimo — parlava dentro un intervallo
    // che nessuno stava guardando: la parola andava persa e l'app sembrava
    // sorda proprio con chi era piu veloce.
    listener.beginWindow()
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
    phase = .flushing
    flushStart = CACurrentMediaTime()
    Task { await listener.flush() }
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

    trial.response = snap.text
    trial.confidence = snap.confidence

    if snap.text.isEmpty {
      ascoltoAvviso = snap.voiceOnset == nil
        ? "Non ho sentito niente. Controlla il microfono qui in alto."
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
      commit(trial)
    }
  }

  private func commit(_ trial: Trial) {
    trials.append(trial)
    // Le parole di riscaldamento non spostano la soglia: servono solo a prendere la mano.
    if trial.id > config.warmupTrials { staircase?.update(correct: trial.correct) }
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
  func resumeFromPause() {
    guard case .pausa = phase else { return }
    wordsSincePause = 0
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

  private func makeRecord() -> SessionRecord {
    var r = SessionRecord()
    r.mode = config.mode
    r.level = config.level
    r.setLabel = config.set.label
    // Il riscaldamento non entra nel punteggio.
    //
    // Sono parole facili mostrate molto piu a lungo, fatte apposta per prendere
    // la mano: contarle gonfiava la percentuale mostrata a fine sessione e
    // spingeva in su il livello suggerito. Un numero che si abbellisce da solo
    // e peggio di un numero severo — toglie senso anche ai miglioramenti veri.
    // Erano gia escluse dalla scala adattiva e dalle parole da riprendere: qui
    // mancava.
    let contate = trials.filter { $0.id > config.warmupTrials }
    r.total = contate.count
    r.correct = contate.filter(\.correct).count
    r.thresholdMs = thresholdMs
    let lat = trials.compactMap(\.vocalLatencyMs)
    r.meanLatencyMs = lat.isEmpty ? nil : lat.reduce(0, +) / Double(lat.count)
    r.items = trials.map {
      ItemRecord(stimulus: $0.stimulus, response: $0.response, correct: $0.correct,
                 exposureMs: $0.actualExposureMs > 0 ? $0.actualExposureMs : $0.requestedExposureMs,
                 latencyMs: $0.vocalLatencyMs, errorKind: $0.errorKind.label,
                 warmup: $0.id <= config.warmupTrials)
    }
    return r
  }

  /// Velocità di partenza suggerita dal test iniziale. Si prende la soglia
  /// misurata e si concede un margine del 25%, perché allenarsi al limite
  /// scoraggia: si parte appena sopra, dove si sbaglia poco ma non zero.
  var calibrationResult: (exposureMs: Double, level: Level)? {
    guard isCalibration, !trials.isEmpty else { return nil }
    let measured = thresholdMs ?? trials.filter(\.correct).map(\.requestedExposureMs).min()
    guard let measured else { return nil }
    let suggested = min(1000, max(80, measured * 1.25))
    let level: Level = switch suggested {
    case ..<180: .avanzato
    case ..<380: .intermedio
    case ..<700: .base
    default: .inizio
    }
    return (suggested, level)
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
