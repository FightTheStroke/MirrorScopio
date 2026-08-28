import Testing
@testable import MirrorScopioCore

/// La scala adattiva: quanto a lungo resta scritta la parola sullo schermo.
///
/// È la regola che decide se l'esercizio si fa più difficile o più facile, e
/// sbagliarla non si vede a occhio: uno esercizio troppo facile annoia, uno
/// troppo difficile fa sentire incapaci. Perciò va verificata a numeri.
@Suite("Scala adattiva")
struct ScalaAdattiva {

  private func config(_ modifica: (inout SessionConfig) -> Void) -> SessionConfig {
    var c = SessionConfig()
    c.exposureMs = 200
    c.stepMs = 20
    modifica(&c)
    return c
  }

  @Test("Con «due giù, uno su» servono due risposte giuste per accorciare il tempo")
  func dueGiuUnoSu() {
    var s = StaircaseState(config: config { $0.staircase = .twoDownOneUp })
    s.update(correct: true)
    #expect(s.exposure == 200, "una sola risposta giusta non deve ancora accorciare")
    s.update(correct: true)
    #expect(s.exposure == 180, "due di fila accorciano di un passo")
    s.update(correct: false)
    #expect(s.exposure == 200, "una che non è venuta allunga subito")
  }

  @Test("Con «uno giù, uno su» basta una risposta giusta")
  func unoGiuUnoSu() {
    var s = StaircaseState(config: config { $0.staircase = .oneUpOneDown })
    s.update(correct: true)
    #expect(s.exposure == 180)
  }

  @Test("Il tempo non scende sotto il minimo")
  func nonScendeSottoIlMinimo() {
    var s = StaircaseState(config: config {
      $0.exposureMs = 20; $0.minExposureMs = 16; $0.staircase = .oneUpOneDown
    })
    s.update(correct: true)
    s.update(correct: true)
    #expect(s.exposure == 16, "sotto il minimo la parola non sarebbe più leggibile da nessuno")
  }

  @Test("Il tempo non sale sopra il massimo")
  func nonSaleSopraIlMassimo() {
    var s = StaircaseState(config: config {
      $0.exposureMs = 990; $0.minExposureMs = 16; $0.maxExposureMs = 1000
    })
    s.update(correct: false)
    s.update(correct: false)
    #expect(s.exposure == 1000)
  }

  @Test("La soglia si annuncia solo quando c'è abbastanza da cui ricavarla")
  func sogliaSoloQuandoSiPuo() {
    var s = StaircaseState(config: config {
      $0.maxExposureMs = 1000; $0.staircase = .oneUpOneDown
    })
    #expect(s.threshold == nil, "dire una soglia dopo due prove sarebbe inventarsela")
    for giusta in [true, false, true, false, true, false, true, false] {
      s.update(correct: giusta)
    }
    let soglia = try? #require(s.threshold)
    #expect(soglia != nil, "dopo abbastanza cambi di direzione la soglia deve esserci")
    if let soglia {
      #expect(soglia >= 160 && soglia <= 220, "la soglia deve stare dentro i tempi davvero provati")
    }
  }

  @Test("A tempo fisso il tempo non si muove")
  func tempoFisso() {
    var s = StaircaseState(config: config { $0.staircase = .fixed })
    s.update(correct: false)
    #expect(s.exposure == 200)
  }
}

/// La lista di parole di una sessione.
@Suite("Lista delle parole")
struct ListaParole {

  @Test("La lista si allunga fino al numero di prove chieste")
  func listaEstesa() {
    var c = SessionConfig()
    c.set = .bisillabe
    c.trials = 45
    c.shuffle = true
    #expect(c.resolvedItems.count == 45, "chi ha chiesto 45 prove deve riceverne 45")
  }

  @Test("Il maiuscolo, se scelto, vale per tutte le parole")
  func maiuscolo() {
    var c = SessionConfig()
    c.set = .bisillabe
    c.trials = 45
    c.uppercase = true
    #expect(c.resolvedItems.allSatisfy { $0 == $0.uppercased() })
  }
}
