import Testing
@testable import MirrorScopio

@Suite("Le regole della Corsa non possono punire")
struct ProveRegoleCorsa {
  @Test("Un ostacolo preso dice Ancora senza togliere punti")
  func ostacoloPresoNonPunisce() {
    let esito = RegoleCorsa.esitoOstacolo(progressoSalto: nil)
    #expect(esito == .ancora)
    #expect(esito.punti == 0)
  }

  @Test("Un ostacolo superato in aria vale cento punti")
  func ostacoloSuperatoPremia() {
    let esito = RegoleCorsa.esitoOstacolo(progressoSalto: 0.5)
    #expect(esito == .superato)
    #expect(esito.punti == 100)
  }

  @Test("La finestra del salto è larga ma non comprende il suolo")
  func finestraDelSalto() {
    #expect(!RegoleCorsa.inAria(progressoSalto: nil))
    #expect(!RegoleCorsa.inAria(progressoSalto: 0.10))
    #expect(RegoleCorsa.inAria(progressoSalto: 0.11))
    #expect(RegoleCorsa.inAria(progressoSalto: 0.89))
    #expect(!RegoleCorsa.inAria(progressoSalto: 0.90))
  }

  @Test("L'altezza del salto parte e finisce a terra")
  func curvaDelSalto() {
    #expect(RegoleCorsa.altezzaSalto(progresso: nil, altezzaMassima: 26) == 0)
    #expect(abs(RegoleCorsa.altezzaSalto(
      progresso: 0.5, altezzaMassima: 26) - 26) < 0.001)
    #expect(abs(RegoleCorsa.altezzaSalto(
      progresso: 1, altezzaMassima: 26)) < 0.001)
  }

  @Test("La modalità a passi arriva al traguardo senza oltrepassarlo")
  func passiFinoAlTraguardo() {
    var posizione = Corsa.partenza
    for _ in 0..<20 {
      posizione = RegoleCorsa.posizioneDopoPasso(
        da: posizione, traguardo: Corsa.traguardo)
    }
    #expect(posizione == Corsa.traguardo)
  }

  @Test("L'ultimo tratto non genera nuovi ostacoli")
  func finaleSgombro() {
    #expect(RegoleCorsa.deveGenerareOstacolo(
      prossimo: 0, posizione: Corsa.traguardo - 81, traguardo: Corsa.traguardo))
    #expect(!RegoleCorsa.deveGenerareOstacolo(
      prossimo: 0, posizione: Corsa.traguardo - 80, traguardo: Corsa.traguardo))
    #expect(!RegoleCorsa.deveGenerareOstacolo(
      prossimo: 1, posizione: Corsa.partenza, traguardo: Corsa.traguardo))
  }

  @Test("Cambiare modalità ricostruisce solo la strada ancora da percorrere")
  func ostacoliCalmiDopoCambio() {
    #expect(RegoleCorsa.posizioniOstacoliCalmi(
      dopo: Corsa.partenza, traguardo: Corsa.traguardo) == [64, 118, 172, 226])
    let daMeta = RegoleCorsa.posizioniOstacoliCalmi(
      dopo: 120, traguardo: Corsa.traguardo)
    #expect(daMeta == [170, 224])
    #expect(daMeta.allSatisfy { $0 > 120 && $0 < Corsa.traguardo - 30 })
  }

  @Test("Le gemme chiedono un salto, salvo in modalità calma")
  func raccoltaDelleGemme() {
    #expect(!RegoleCorsa.puoRaccogliereGemma(
      distanza: 0, fermo: false, altezzaSalto: 10))
    #expect(RegoleCorsa.puoRaccogliereGemma(
      distanza: 0, fermo: false, altezzaSalto: 10.1))
    #expect(RegoleCorsa.puoRaccogliereGemma(
      distanza: 0, fermo: true, altezzaSalto: 0))
    #expect(!RegoleCorsa.puoRaccogliereGemma(
      distanza: 16, fermo: true, altezzaSalto: 26))
  }

  @Test("La squadra si ferma a quattro")
  func squadraCompleta() {
    #expect(RegoleCorsa.squadraDopoTappa(0) == 1)
    #expect(RegoleCorsa.squadraDopoTappa(3) == 4)
    #expect(RegoleCorsa.squadraDopoTappa(4) == 4)
  }

  @Test("La quarta tappa porta alla fine")
  func passaggiFraLeTappe() {
    #expect(TappaCorsa.tutte.count == RegoleCorsa.numeroTappe)
    #expect(RegoleCorsa.passaggioDopoTappa(livello: 0) == .prossima(1))
    #expect(RegoleCorsa.passaggioDopoTappa(livello: 2) == .prossima(3))
    #expect(RegoleCorsa.passaggioDopoTappa(livello: 3) == .fine)
  }
}
