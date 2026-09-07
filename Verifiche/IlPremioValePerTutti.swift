import Foundation
import QuartzCore
import Testing

@testable import MirrorScopio

/// Il premio di fine sessione deve arrivare in **tutti e due** i modi di
/// allenarsi, «Leggi» e «Scrivi».
///
/// Non è una simmetria per eleganza. Chi si allena a scrivere sotto dettatura
/// fa la stessa fatica di chi legge a lampo — spesso è la stessa persona in un
/// giorno diverso — e un premio che tocca solo a una delle due strade dice a
/// chi prende l'altra che la sua fatica conta meno. In un'app per ragazzi con
/// disturbi della lettura è esattamente il messaggio da non mandare.
///
/// Il pulsante del premio compare quando la sessione è finita, non è una
/// taratura, e almeno una parola è stata fatta. Questa prova verifica che in
/// modalità «Scrivi» si arrivi davvero a quelle tre condizioni: la strada del
/// dettato passa per pezzi diversi da quella della lettura, e basta che uno di
/// quei pezzi non riporti al riepilogo perché il premio sparisca in silenzio.
@Suite("Il premio vale per tutti e due i modi")
@MainActor
struct IlPremioValePerTutti {

  /// Porta una sessione fino in fondo, parola per parola, come farebbe una
  /// persona. Il tempo lo diamo noi: nessuna attesa vera, nessuno schermo.
  private func portaInFondo(_ motore: SessionEngine, risposte: (String) -> String) {
    if case .failed(let perche) = motore.phase {
      Issue.record("La sessione non è nemmeno partita: \(perche)")
      return
    }
    // Dopo `start()` si resta sulle istruzioni finché qualcuno non dice di
    // essere pronto: senza questo passo la sessione non comincia mai.
    if case .instructions = motore.phase { motore.beginTrials() }
    // L'orologio è quello vero del Mac: il motore fissa le sue scadenze con
    // `CACurrentMediaTime()`, e partire da un numero inventato più piccolo
    // vorrebbe dire aspettare per sempre una scadenza già passata.
    var adesso: CFTimeInterval = CACurrentMediaTime()
    var giri = 0
    // L'unica finestra pubblica sulla parola in corso è quella che il ragazzo
    // vede a schermo: la teniamo da parte finché serve rispondere.
    var ultimaParolaVista = ""
    while giri < 4000 {
      giri += 1
      if case .finished = motore.phase { return }
      if !motore.displayText.isEmpty { ultimaParolaVista = motore.displayText }
      if case .typing = motore.phase {
        if motore.revisioneScrittura?.esaurite == true {
          motore.continuaDopoRiproveScrittura()
          continue
        }
        motore.typedAnswer = risposte(ultimaParolaVista)
        motore.submitTyped()
        continue
      }

      adesso += 0.05
      motore.tick(adesso, durataFrame: 1.0 / 60.0)
    }
  }
}

@Suite("Scrivi conserva la prima risposta e concede tre riprove", .serialized)
@MainActor
struct RiproveScrittura {
  private let frase = "colora il prato"

  private func avvia(
    _ parole: [String] = ["colora il prato", "casa"],
    riscontro: Bool = true
  ) -> SessionEngine {
    let motore = SessionEngine()
    motore.config.mode = .scrittura
    motore.config.writingLevel = .frasiBrevi
    motore.config.warmupTrials = 0
    motore.config.useAppleIntelligence = false
    motore.a11y.soundsEnabled = false
    motore.a11y.showFeedbackPerWord = riscontro
    motore.start(words: parole)
    comincia(motore)
    return motore
  }

  private func comincia(_ motore: SessionEngine) {
    motore.beginTrials()
    let ora = CACurrentMediaTime()
    for secondi in 0...3 {
      motore.tick(ora + Double(secondi), durataFrame: 1.0 / 60)
    }
    motore.speaker.stop()
    #expect(motore.phase == .typing)
  }

  private func consegna(_ risposta: String, al motore: SessionEngine) {
    motore.typedAnswer = risposta
    motore.submitTyped()
    motore.speaker.stop()
  }

  private func avanza(_ motore: SessionEngine) {
    let ora = CACurrentMediaTime()
    motore.tick(ora + 10, durataFrame: 1.0 / 60)
    motore.tick(ora + 20, durataFrame: 1.0 / 60)
    motore.speaker.stop()
  }

  @Test("Fatto indica corona, conserva il testo e non passa alla frase dopo")
  func primaConsegna() {
    let motore = avvia()
    defer { motore.reset() }
    consegna("  corona il prato  ", al: motore)
    #expect(motore.phase == .typing)
    #expect(motore.typedAnswer == "  corona il prato  ")
    #expect(motore.revisioneScrittura?.consegne == 1)
    #expect(
      motore.revisioneScrittura?.parole.map(\.esito) == [.daRivedere, .confermata, .confermata])
    #expect(motore.revisioneScrittura?.parole.first?.testo == "corona")
    #expect(motore.modelloScrittura == nil)
    #expect(motore.trials.count == 1)
    #expect(motore.trials.first?.response == "corona il prato")
    #expect(motore.trials.first?.correct == false)
    avanza(motore)
    #expect(motore.trialIndex == 1)
    #expect(motore.phase == .typing)
    #expect(!motore.serveIlBattito)
  }

  @Test(
    "Prima risposta più tre riprove, poi modello e scelta esplicita",
    arguments: [true, false])
  func esaurimento(riscontro: Bool) {
    let motore = avvia(riscontro: riscontro)
    defer { motore.reset() }
    for numero in 1...4 {
      consegna("corona il prato", al: motore)
      #expect(motore.revisioneScrittura?.consegne == numero)
      #expect(motore.revisioneScrittura?.esaurite == (numero == 4))
      #expect(motore.modelloScrittura == (numero == 4 ? frase : nil))
      #expect(motore.trials.count == 1)
      if numero < 4 { motore.continuaDopoRiproveScrittura() }
      avanza(motore)
      #expect(motore.phase == .typing)
      #expect(motore.trialIndex == 1)
    }
    let soglia = motore.currentExposureMs
    consegna(frase, al: motore)
    #expect(motore.phase == .typing, "Copiare il modello non consegna una quinta risposta.")
    #expect(motore.revisioneScrittura?.consegne == 4)
    #expect(motore.trials.first?.correct == false)
    motore.repeatWord()
    #expect(motore.speaker.isSpeaking, "Ripeti resta disponibile anche con il modello.")
    motore.speaker.stop()
    motore.sayWord(motore.typedAnswer)
    #expect(motore.speaker.isSpeaking)
    motore.speaker.stop()
    motore.continuaDopoRiproveScrittura()
    motore.speaker.stop()
    #expect(motore.currentExposureMs == soglia, "Le riprove non aggiornano di nuovo la scala.")
    avanza(motore)
    #expect(motore.phase == .typing)
    #expect(motore.trialIndex == 2)
    #expect(motore.typedAnswer.isEmpty)
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.modelloScrittura == nil)
    motore.continuaDopoRiproveScrittura()
    #expect(motore.trialIndex == 2, "Un secondo Continua non salta la nuova parola.")
  }

  @Test(
    "Una riprova corretta prosegue senza diventare corretta al primo tentativo",
    arguments: [1, 2, 3])
  func correttaPrimaDelLimite(riprova: Int) throws {
    let motore = avvia()
    defer { motore.reset() }
    for _ in 0..<riprova { consegna("corona il prato", al: motore) }
    let soglia = motore.currentExposureMs
    consegna("COLORA il prato!", al: motore)
    #expect(motore.phase == .feedback(true))
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.trials.count == 1)
    #expect(motore.trials.first?.correct == false)
    #expect(motore.trials.first?.response == "corona il prato")
    #expect(motore.trials.first?.errorKind == .sostituzione)
    #expect(motore.trials.first?.editDistance == 2)
    #expect(motore.currentExposureMs == soglia)
    avanza(motore)
    consegna("casa", al: motore)
    avanza(motore)
    #expect(motore.phase == .finished)
    let referto = try #require(motore.finishedRecord)
    #expect(referto.total == 2)
    #expect(referto.correct == 1)
    #expect(referto.items.first?.response == "corona il prato")
    let riletto = try JSONDecoder().decode(SessionRecord.self, from: JSONEncoder().encode(referto))
    #expect(riletto.correct == 1)
    #expect(riletto.items.first?.correct == false)
    #expect(riletto.missedWords == [frase])
  }

  @Test("La risposta corretta subito usa le normalizzazioni di sempre",
        arguments: ["LACQUA e BLU!", "lac qua è b lu"])
  func correttaSubito(risposta: String) {
    let motore = avvia(["L'acqua è blu"])
    defer { motore.reset() }
    consegna(risposta, al: motore)
    #expect(motore.phase == .feedback(true))
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.trials.first?.correct == true)
    avanza(motore)
    #expect(motore.finishedRecord?.correct == 1)
  }

  @Test("Il motore conserva e fa correggere anche parole mancanti o in più",
        arguments: ["colora prato", "colora tutto il prato", "corona prato"])
  func fraseDaCompletare(risposta: String) {
    let motore = avvia()
    defer { motore.reset() }
    consegna(risposta, al: motore)
    #expect(motore.phase == .typing)
    #expect(motore.typedAnswer == risposta)
    #expect(motore.revisioneScrittura?.parole.contains {
      $0.esito == .mancante || $0.esito == .inPiu
    } == true)
    consegna(frase, al: motore)
    #expect(motore.phase == .feedback(true))
    #expect(motore.trials.count == 1)
    #expect(motore.trials.first?.response == risposta)
    #expect(motore.trials.first?.correct == false)
  }

  @Test("Anche una risposta vuota ha tre riprove e può finire")
  func vuota() {
    let motore = avvia([frase])
    defer { motore.reset() }
    for _ in 0..<4 { consegna("   ", al: motore) }
    #expect(motore.revisioneScrittura?.parole.map(\.esito) == [.mancante, .mancante, .mancante])
    #expect(motore.trials.first?.errorKind == .omissioneTotale)
    #expect(motore.modelloScrittura == frase)
    motore.continuaDopoRiproveScrittura()
    motore.speaker.stop()
    avanza(motore)
    #expect(motore.phase == .finished)
    #expect(motore.finishedRecord?.total == 1)
    #expect(motore.finishedRecord?.correct == 0)
    #expect(motore.finishedRecord?.items.count == 1)
  }

  @Test(
    "Una pausa non duplica né cancella una risposta già consegnata",
    arguments: [false, true])
  func pausa(dopoConsegna: Bool) {
    let motore = avvia()
    defer { motore.reset() }
    if dopoConsegna { consegna("corona il prato", al: motore) }
    motore.interrompi(motivo: "Pausa di prova.")
    #expect(motore.phase == .pausa)
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.typedAnswer.isEmpty)
    #expect(motore.trials.count == 1)
    #expect(motore.trials.first?.interrotto == !dopoConsegna)
    #expect(motore.trials.first?.response == (dopoConsegna ? "corona il prato" : ""))
    motore.resumeFromPause()
    motore.speaker.stop()
    #expect(motore.phase == .typing)
    #expect(motore.trialIndex == 2)
    consegna("cas", al: motore)
    #expect(motore.revisioneScrittura?.consegne == 1)
  }

  @Test("Una pausa sull'ultima frase non legge oltre la lista")
  func pausaSullUltima() {
    let motore = avvia([frase])
    defer { motore.reset() }
    consegna("corona il prato", al: motore)
    motore.interrompi(motivo: "Pausa di prova.")
    motore.resumeFromPause()
    #expect(motore.phase == .finished)
    #expect(motore.finishedRecord?.items.count == 1)
    #expect(motore.finishedRecord?.items.first?.response == "corona il prato")
  }

  @Test("La pausa programmata conta frasi, non riprove")
  func pausaProgrammata() {
    let motore = avvia()
    defer { motore.reset() }
    motore.a11y.pauseEveryNWords = 1
    consegna("corona il prato", al: motore)
    avanza(motore)
    #expect(motore.phase == .typing)
    consegna(frase, al: motore)
    avanza(motore)
    #expect(motore.phase == .pausa)
    #expect(motore.revisioneScrittura == nil)
    motore.resumeFromPause()
    motore.speaker.stop()
    #expect(motore.trialIndex == 2)
    #expect(motore.typedAnswer.isEmpty)
  }

  @Test("Stop, ritorno e nuovo avvio azzerano le riprove senza cambiare il referto")
  func nuoviAvvii() {
    let motore = avvia()
    defer { motore.reset() }
    consegna("corona il prato", al: motore)
    motore.abort()
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.typedAnswer.isEmpty)
    #expect(motore.finishedRecord?.items.first?.response == "corona il prato")
    motore.reset()
    #expect(motore.phase == .idle)
    #expect(motore.revisioneScrittura == nil)
    motore.start(words: ["casa"])
    comincia(motore)
    consegna("cas", al: motore)
    #expect(motore.revisioneScrittura?.consegne == 1)
    motore.start(words: ["mare"])
    #expect(motore.revisioneScrittura == nil)
    #expect(motore.trials.isEmpty)
    comincia(motore)
    consegna("mar", al: motore)
    #expect(motore.revisioneScrittura?.consegne == 1)
    #expect(motore.trials.first?.stimulus == "mare")
  }
}

@Suite("Il riscontro di Scrivi allinea le parole")
struct RevisioneParoleScrittura {
  @Test("Una parola mancante non fa segnalare quelle successive")
  func mancante() {
    let parole = Scoring.revisioneParole(target: "colora il prato", response: "colora prato")
    #expect(parole.map(\.esito) == [.confermata, .mancante, .confermata])
    #expect(parole.map(\.indiceRisposta) == [0, nil, 1])
    #expect(parole[1].testo.isEmpty, "Il modello non si anticipa fra i suggerimenti.")
  }

  @Test("Una parola in più viene isolata senza spostare le altre")
  func inPiu() {
    let parole = Scoring.revisioneParole(
      target: "colora il prato", response: "colora tutto il prato")
    #expect(parole.map(\.esito) == [.confermata, .inPiu, .confermata, .confermata])
    #expect(parole[1].testo == "tutto")
  }

  @Test("Maiuscole, accenti, apostrofi e punteggiatura seguono il verdetto")
  func normalizzazione() {
    let parole = Scoring.revisioneParole(target: "L'acqua è blu.", response: "LACQUA e BLU!")
    #expect(parole.allSatisfy { $0.esito == .confermata })
    #expect(parole.map(\.testo) == ["LACQUA", "e", "BLU!"])
  }

  @Test("Le ripetizioni restano distinguibili e l'allineamento è riproducibile")
  func ripetizioni() {
    let parole = Scoring.revisioneParole(
      target: "il prato e il sole", response: "il il prato e il sole")
    #expect(parole.filter { $0.esito == .inPiu }.count == 1)
    #expect(parole.filter { $0.esito == .confermata }.count == 5)
    #expect(parole.compactMap(\.indiceRisposta) == Array(0...5))
    #expect(
      parole
        == Scoring.revisioneParole(target: "il prato e il sole", response: "il il prato e il sole"))
  }

  @Test("Una singola parola e le omissioni ai margini sono leggibili")
  func confini() {
    #expect(Scoring.revisioneParole(target: "casa", response: "cas").map(\.esito) == [.daRivedere])
    #expect(
      Scoring.revisioneParole(target: "colora il prato", response: "il").map(\.esito)
        == [.mancante, .confermata, .mancante])
    #expect(
      Scoring.revisioneParole(target: "colora il prato", response: "...").map(\.esito)
        == [.mancante, .mancante, .mancante])
    #expect(Scoring.revisioneParole(target: "", response: "casa").map(\.esito) == [.inPiu])
    #expect(Scoring.revisioneParole(target: "", response: "").isEmpty)
  }
}
extension IlPremioValePerTutti {
  @Test("In «Scrivi» la sessione arriva al riepilogo con le parole contate")
  func scriviArrivaAlRiepilogo() {
    let motore = SessionEngine()
    defer { motore.reset() }
    motore.a11y.soundsEnabled = false
    var c = motore.config
    c.mode = .scrittura
    c.trials = 5
    c.warmupTrials = 0
    c.useAppleIntelligence = false
    c.interTrialMs = 400
    motore.config = c
    motore.start()

    portaInFondo(motore) { parola in parola }

    guard case .finished = motore.phase else {
      Issue.record("La sessione di scrittura non è arrivata in fondo: fase \(motore.phase)")
      return
    }
    let referto = motore.finishedRecord
    #expect(referto != nil, "Senza referto il riepilogo non mostra niente, premio compreso")
    // È la condizione esatta che accende il pulsante del premio nel riepilogo.
    #expect(
      (referto?.total ?? 0) > 0,
      "Con zero parole contate il premio non compare: in «Scrivi» sparirebbe sempre")
    #expect(motore.isCalibration == false)
  }

  @Test("In «Scrivi» il premio compare anche a chi sbaglia tutto")
  func scriviPremioAncheSbagliando() {
    let motore = SessionEngine()
    defer { motore.reset() }
    motore.a11y.soundsEnabled = false
    var c = motore.config
    c.mode = .scrittura
    c.trials = 4
    c.warmupTrials = 0
    c.useAppleIntelligence = false
    c.interTrialMs = 400
    motore.config = c
    motore.start()

    // Nessuna parola presa. Il premio non è una ricompensa per il risultato:
    // è la fine della fatica, e la fatica l'ha fatta lo stesso.
    portaInFondo(motore) { _ in "zzzz" }

    let referto = motore.finishedRecord
    #expect((referto?.total ?? 0) > 0)
    #expect((referto?.correct ?? -1) == 0)
  }
}
