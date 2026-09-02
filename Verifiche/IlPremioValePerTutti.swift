import Testing
import Foundation
import QuartzCore
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
        motore.typedAnswer = risposte(ultimaParolaVista)
        motore.submitTyped()
        continue
      }
      adesso += 0.05
      motore.tick(adesso, durataFrame: 1.0 / 60.0)
    }
  }

  @Test("In «Scrivi» la sessione arriva al riepilogo con le parole contate")
  func scriviArrivaAlRiepilogo() {
    let motore = SessionEngine()
    motore.a11y.soundsEnabled = false
    var c = motore.config
    c.mode = .scrittura
    c.trials = 5
    c.warmupTrials = 0
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
    #expect((referto?.total ?? 0) > 0,
            "Con zero parole contate il premio non compare: in «Scrivi» sparirebbe sempre")
    #expect(motore.isCalibration == false)
  }

  @Test("In «Scrivi» il premio compare anche a chi sbaglia tutto")
  func scriviPremioAncheSbagliando() {
    let motore = SessionEngine()
    motore.a11y.soundsEnabled = false
    var c = motore.config
    c.mode = .scrittura
    c.trials = 4
    c.warmupTrials = 0
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
