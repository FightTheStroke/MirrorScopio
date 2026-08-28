import Testing
import Foundation
@testable import MirrorScopio

/// I conti del referto: che cosa entra nella percentuale e che cosa no.
///
/// Sono le due regole cliniche più delicate dell'app, e per settimane non
/// erano coperte da niente — non perché nessuno ci avesse pensato, ma perché
/// stavano dentro un oggetto di mille righe legato a un microfono acceso e a
/// un orologio che gira: per provarle bisognava fare una sessione vera, a
/// mano, e leggere il risultato a occhio.
///
/// Un conto sbagliato qui non manda in errore niente. Produce un referto
/// pieno, ordinato, plausibile e falso, su cui qualcuno prenderà una decisione
/// riguardo a un ragazzo.
@Suite("I conti del referto")
struct ContiDelReferto {

  /// Costruisce una prova finta. Solo quello che serve ai conti.
  private func prova(_ id: Int, giusta: Bool,
                     interrotta: Bool = false,
                     latenzaMs: Double? = nil,
                     espostaMs: Double = 300) -> Trial {
    var t = Trial(id: id, stimulus: "parola")
    t.correct = giusta
    t.interrotto = interrotta
    t.vocalLatencyMs = latenzaMs
    t.requestedExposureMs = espostaMs
    return t
  }

  private func configurazione(riscaldamento: Int = 3) -> SessionConfig {
    var c = SessionConfig()
    c.warmupTrials = riscaldamento
    return c
  }

  // MARK: - Il riscaldamento

  /// Le parole di riscaldamento sono facili e mostrate molto più a lungo,
  /// fatte apposta per prendere la mano. Contarle gonfia la percentuale e
  /// spinge in su il livello suggerito: un numero che si abbellisce da solo
  /// toglie senso anche ai miglioramenti veri.
  @Test("Le parole di riscaldamento non entrano nel punteggio")
  func riscaldamentoFuoriDalConto() {
    let prove = [
      prova(1, giusta: true), prova(2, giusta: true), prova(3, giusta: true),
      prova(4, giusta: true), prova(5, giusta: false),
    ]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.total == 2, "Contano solo le due prove vere, non le cinque.")
    #expect(r.correct == 1)
    #expect(r.accuracy == 0.5, "Con il riscaldamento dentro sarebbe l'80%: un regalo.")
  }

  @Test("Le parole di riscaldamento restano comunque nel dettaglio")
  func riscaldamentoVisibile() {
    let prove = [prova(1, giusta: true), prova(4, giusta: true)]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.items.count == 2, "Escluse dal conto, non nascoste a chi guarda.")
    #expect(r.items[0].warmup == true)
    #expect(r.items[1].warmup == false)
  }

  // MARK: - Le prove interrotte

  /// Una prova interrotta è una in cui il Mac si è addormentato o il microfono
  /// è sparito. Metterla nel totale senza poterla mettere fra le giuste fa
  /// scendere la percentuale per una cosa che il ragazzo non ha fatto.
  @Test("Una prova interrotta non fa scendere la percentuale")
  func interrottaFuoriDalConto() {
    let prove = [
      prova(4, giusta: true), prova(5, giusta: true),
      prova(6, giusta: false, interrotta: true),
    ]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.total == 2, "L'interrotta non va nel totale.")
    #expect(r.correct == 2)
    #expect(r.accuracy == 1.0, "Con l'interrotta dentro sarebbe il 67%: un peggioramento mai avvenuto.")
  }

  @Test("Una prova interrotta si riconosce nel dettaglio")
  func interrottaVisibile() {
    let prove = [prova(4, giusta: false, interrotta: true)]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.items.count == 1)
    #expect(r.items[0].interrotto == true,
            "Chi legge il dettaglio deve poter distinguere «non è venuta» da «non è mai comparsa».")
  }

  @Test("Il tempo medio di risposta non tiene conto delle prove interrotte")
  func latenzaSenzaInterrotte() {
    let prove = [
      prova(4, giusta: true, latenzaMs: 400),
      prova(5, giusta: true, latenzaMs: 600),
      // Interrotta con una latenza assurda: se entrasse, sposterebbe la media.
      prova(6, giusta: false, interrotta: true, latenzaMs: 9000),
    ]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.meanLatencyMs == 500)
  }

  @Test("Senza nessuna risposta a tempo, il tempo medio non si inventa")
  func latenzaAssente() {
    let prove = [prova(4, giusta: false), prova(5, giusta: false)]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.meanLatencyMs == nil, "Meglio niente che uno zero che sembra un tempo di risposta.")
  }

  @Test("Una sessione senza nessuna prova vera non vale zero su zero")
  func soloRiscaldamento() {
    let prove = [prova(1, giusta: true), prova(2, giusta: false), prova(3, giusta: true)]
    let r = RegistroSessione.referto(prove: prove, config: configurazione(), sogliaMs: nil)
    #expect(r.total == 0)
    #expect(r.accuracy == 0, "Zero su zero non è una percentuale: non deve dividere per zero.")
  }

  // MARK: - La velocità di partenza suggerita

  @Test("La partenza suggerita concede il 25% sopra la soglia misurata")
  func margineDelVenticinquePerCento() {
    let esito = RegistroSessione.partenzaSuggerita(prove: [prova(1, giusta: true)], sogliaMs: 200)
    #expect(esito?.exposureMs == 250)
    #expect(esito?.level == .intermedio)
  }

  @Test("La partenza suggerita non scende sotto un fotogramma né sale oltre un secondo")
  func partenzaDentroILimiti() {
    let veloce = RegistroSessione.partenzaSuggerita(prove: [prova(1, giusta: true)], sogliaMs: 10)
    #expect(veloce?.exposureMs == 80, "Sotto gli 80 ms non si scende: sarebbe più veloce di quanto lo schermo sappia mostrare.")
    let lenta = RegistroSessione.partenzaSuggerita(prove: [prova(1, giusta: true)], sogliaMs: 5000)
    #expect(lenta?.exposureMs == 1000)
    #expect(lenta?.level == .inizio)
  }

  @Test("Senza soglia si ripiega sulla più veloce fra le risposte giuste")
  func senzaSoglia() {
    let prove = [
      prova(1, giusta: true, espostaMs: 400),
      prova(2, giusta: true, espostaMs: 240),
      // Sbagliata: non deve essere presa, per quanto veloce.
      prova(3, giusta: false, espostaMs: 60),
    ]
    let esito = RegistroSessione.partenzaSuggerita(prove: prove, sogliaMs: nil)
    #expect(esito?.exposureMs == 300)
  }

  @Test("Senza nessuna prova non si suggerisce niente")
  func nienteProve() {
    #expect(RegistroSessione.partenzaSuggerita(prove: [], sogliaMs: 200) == nil)
  }
}
