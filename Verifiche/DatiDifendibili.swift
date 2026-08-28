import Testing
import Foundation
@testable import MirrorScopio

/// Le tre cose che, sbagliate, non fanno fallire nessuna prova e non fanno
/// comparire nessun errore: falsano soltanto i dati di un bambino.
///
/// È il motivo per cui queste prove esistono. Un difetto che manda l'app in
/// crash lo trova chiunque in dieci secondi. Un difetto che attribuisce la
/// parola «casa» alla riga di «mare», o che conta come «non ha risposto» un
/// turno in cui il Mac si era addormentato, produce un referto pieno,
/// ordinato, plausibile e falso — e nessuno se ne accorge finché qualcuno non
/// prende una decisione su quel bambino.
@Suite("Dati difendibili")
@MainActor
struct DatiDifendibili {

  // MARK: - La risposta arrivata in ritardo

  /// Il riconoscitore vocale consegna quando gli pare. Se una consegna arriva
  /// mentre la finestra di risposta è già passata alla parola successiva, non
  /// deve essere servita: quel testo è di un'altra parola.
  @Test("Una chiusura chiesta per la prova di prima viene rifiutata")
  func chiusuraFuoriTempoRifiutata() async {
    let ascoltatore = SpeechListener()

    ascoltatore.beginWindow(trialID: 1)
    // Nel frattempo comincia la parola dopo.
    ascoltatore.beginWindow(trialID: 2)

    let servita = await ascoltatore.flush(trialID: 1)
    #expect(servita == false, "La chiusura della prova 1 è arrivata quando eravamo già alla 2: doveva essere rifiutata.")

    let scartate = ascoltatore.read().consegneFuoriTempo
    #expect(scartate == 1, "Una consegna fuori tempo va contata, non ignorata in silenzio.")
  }

  /// La finestra aperta porta con sé l'identificativo della prova: è quello
  /// che permette a chi legge il risultato di accorgersi che non è suo.
  @Test("La finestra di risposta dice a quale parola appartiene")
  func laFinestraSaDiChiÈ() {
    let ascoltatore = SpeechListener()
    ascoltatore.beginWindow(trialID: 7)
    #expect(ascoltatore.read().trialID == 7)
    ascoltatore.endWindow()
  }

  // MARK: - Quanto lampeggia lo schermo

  /// Sopra tre volte al secondo un'alternanza ad alto contrasto può scatenare
  /// una crisi in chi ha un'epilessia fotosensibile. Con i tempi di serie
  /// siamo lontanissimi da lì, e la prova serve a saperlo se qualcuno un
  /// giorno cambia i valori predefiniti.
  @Test("I tempi predefiniti stanno molto sotto il limite di lampeggio")
  func tempiPredefinitiSicuri() {
    let c = SessionConfig()
    #expect(c.oltreIlLimiteDiLampeggio == false)
    #expect(c.frequenzaCicloHz < 1)
  }

  /// Chi apre «Per l'adulto» può azzerare la croce e la pausa. È lì che il
  /// ritmo diventa pericoloso, ed è lì che il blocco deve scattare.
  @Test("Azzerando croce e pausa si supera il limite, e l'app se ne accorge")
  func tempiAzzeratiSuperanoIlLimite() {
    var c = SessionConfig()
    c.fixationMs = 0
    c.interTrialMs = 0
    c.maskMode = .none
    c.minExposureMs = 16
    #expect(c.oltreIlLimiteDiLampeggio, "Un giro da 16 millesimi sono più di 60 volte al secondo.")
    #expect(c.frequenzaCicloHz > SessionConfig.limiteLampeggioHz)
  }

  /// Il limite non è un'opinione: è la soglia delle linee guida, tre hertz,
  /// cioè un giro completo di almeno un terzo di secondo.
  @Test("Il confine sta esattamente a un terzo di secondo")
  func ilConfine() {
    #expect(SessionConfig.limiteLampeggioHz == 3)
    #expect(abs(SessionConfig.durataCicloMinimaMs - 1000.0 / 3.0) < 0.001)

    var c = SessionConfig()
    c.fixationMs = 0
    c.maskMode = .none
    c.minExposureMs = 1
    // Un giro appena più lungo del minimo è ammesso, uno appena più corto no.
    c.interTrialMs = SessionConfig.durataCicloMinimaMs
    #expect(c.oltreIlLimiteDiLampeggio == false)
    c.interTrialMs = SessionConfig.durataCicloMinimaMs - 10
    #expect(c.oltreIlLimiteDiLampeggio)
  }

  /// Un motore configurato oltre il limite non parte, e dice perché. Un
  /// rifiuto muto sembra un guasto, e chi lo legge cerca il modo di aggirarlo.
  @Test("Oltre il limite la sessione non parte e la ragione è leggibile")
  func oltreIlLimiteNonSiParte() {
    let motore = SessionEngine()
    var c = motore.config
    c.fixationMs = 0
    c.interTrialMs = 0
    c.maskMode = .none
    c.minExposureMs = 16
    motore.config = c
    motore.start()

    guard case .failed(let spiegazione) = motore.phase else {
      Issue.record("La sessione è partita lo stesso: fase \(motore.phase)")
      return
    }
    #expect(spiegazione.contains("volte al secondo"))
    #expect(spiegazione.contains("epilessia fotosensibile"))
    #expect(motore.trials.isEmpty)
  }

  /// Con lo sblocco esplicito di un adulto si parte: la scelta esiste, ma
  /// bisogna farla apposta.
  @Test("Con il consenso esplicito di un adulto la sessione parte")
  func conIlConsensoSiParte() {
    let motore = SessionEngine()
    var c = motore.config
    c.mode = .scrittura   // niente microfono: qui interessa solo il cancello
    c.fixationMs = 0
    c.interTrialMs = 0
    c.maskMode = .none
    c.minExposureMs = 16
    c.lampeggioVeloceConsentito = true
    motore.config = c
    motore.start()

    if case .failed = motore.phase {
      Issue.record("Con il consenso dell'adulto non doveva fermarsi.")
    }
  }

  // MARK: - Il turno interrotto

  /// Un turno fermato dal Mac che si addormenta non è una parola non letta.
  /// Contarlo come tale vorrebbe dire scrivere nel referto di un bambino una
  /// cosa che non è successa.
  @Test("Un turno interrotto è marcato interrotto, non contato come omissione")
  func turnoInterrotto() {
    var prova = Trial(id: 3, stimulus: "casa")
    prova.interrotto = true
    prova.motivoInterruzione = "Il Mac si è addormentato"
    #expect(prova.errorKind == .none)
    #expect(prova.correct == false)
    #expect(prova.interrotto)
  }

  /// E soprattutto non deve spostare la soglia: la scala adattiva misura chi
  /// legge, non quante volte si è chiuso il coperchio del portatile.
  ///
  /// La prova mostra che la differenza c'è davvero: se un turno interrotto
  /// venisse contato come sbagliato, la soglia finirebbe altrove.
  @Test("Contare una prova interrotta sposterebbe la soglia — per questo si salta")
  func laProvaInterrottaNonSpostaLaSoglia() {
    var config = SessionConfig()
    config.staircase = .oneUpOneDown
    config.exposureMs = 300
    config.stepMs = 20

    var comeFaLApp = StaircaseState(config: config)
    var seLaContassimo = StaircaseState(config: config)

    for _ in 0..<3 {
      comeFaLApp.update(correct: true)
      seLaContassimo.update(correct: true)
    }
    // Il quarto turno è quello interrotto: l'app lo salta, il confronto no.
    seLaContassimo.update(correct: false)

    #expect(comeFaLApp.exposure != seLaContassimo.exposure,
            "Se contare un turno interrotto non cambiasse niente, questa protezione sarebbe inutile: cambia.")
  }
}

/// Che cosa arriva nel referto quando il turno si è fermato per colpa del Mac.
///
/// Il motore sapeva distinguere una parola interrotta da una parola sbagliata,
/// ma l'informazione moriva lì: nel referto, nella percentuale e nel ripasso
/// arrivava come «nessuna risposta», cioè come un errore del ragazzo. Una
/// protezione che si ferma al confine del referto non protegge nessuno.
@Suite("Una parola interrotta non diventa un errore")
struct InterrotteFuoriDalReferto {

  private func voce(interrotto: Bool, corretta: Bool, parola: String = "casa") -> ItemRecord {
    ItemRecord(stimulus: parola, response: "", correct: corretta,
               exposureMs: 100, latencyMs: nil, errorKind: "omissione",
               warmup: false, interrotto: interrotto)
  }

  @Test("Non finisce fra le parole da ripassare")
  func nonSiRipassaUnaParolaMaiVista() {
    var r = SessionRecord()
    r.items = [voce(interrotto: true, corretta: false, parola: "gatto"),
               voce(interrotto: false, corretta: false, parola: "cane")]
    #expect(r.missedWords == ["cane"], "far ripetere una parola mai comparsa è chiedere conto di una cosa mai successa")
  }

  @Test("Non entra nel conteggio dei tipi di errore")
  func nonConteggiaUnErroreMaiFatto() {
    var r = SessionRecord()
    r.items = [voce(interrotto: true, corretta: false),
               voce(interrotto: false, corretta: false)]
    #expect(r.errorCounts["omissione"] == 1)
  }
}

/// Il limite di lampeggio contato come lo conta la norma.
@Suite("Il limite di lampeggio")
struct LimiteLampeggio {

  @Test("I valori di serie non fanno scattare l'avviso")
  func serieÈTranquilla() {
    let c = SessionConfig()
    #expect(!c.oltreIlLimiteDiLampeggio, "un avviso che compare sempre non lo legge più nessuno")
  }

  @Test("Azzerando croce e pausa l'avviso scatta")
  func azzerareSiVede() {
    var c = SessionConfig()
    c.fixationMs = 0
    c.interTrialMs = 0
    c.maskMode = .both
    c.maskMs = 30
    c.minExposureMs = 16
    #expect(c.oltreIlLimiteDiLampeggio)
  }

  @Test("I lampi si contano a coppie di cambi, non a cicli")
  func lampiNonCicli() {
    // Due cambi fanno un lampo: è la definizione della norma, ed è il motivo
    // per cui contare i cicli soltanto nascondeva i cambi ravvicinati dentro
    // una singola prova.
    var c = SessionConfig()
    c.fixationMs = 0
    c.interTrialMs = 0
    c.maskMode = .post
    c.maskMs = 30
    c.minExposureMs = 16
    #expect(c.lampiAlSecondo > c.frequenzaCicloHz / 2)
  }
}
