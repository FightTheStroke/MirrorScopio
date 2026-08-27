import Foundation

/// Verifica della scala adattiva: direzione dei passi, limiti e stima della soglia.
@main
struct StaircaseHarness {
  static func main() {
    var failures = 0
    func check(_ name: String, _ condition: Bool) {
      print("\(condition ? "PASS" : "FAIL")  \(name)")
      if !condition { failures += 1 }
    }

    var c = SessionConfig()
    c.exposureMs = 200; c.stepMs = 20; c.staircase = .twoDownOneUp

    var s = StaircaseState(config: c)
    s.update(correct: true)
    check("2-giu: una corretta non abbassa ancora", s.exposure == 200)
    s.update(correct: true)
    check("2-giu: due corrette consecutive abbassano di un passo", s.exposure == 180)
    s.update(correct: false)
    check("2-giu: una errata alza di un passo", s.exposure == 200)

    c.staircase = .oneUpOneDown
    var t = StaircaseState(config: c)
    t.update(correct: true)
    check("1-giu: una corretta abbassa subito", t.exposure == 180)

    c.exposureMs = 20; c.minExposureMs = 16; c.staircase = .oneUpOneDown
    var m = StaircaseState(config: c)
    m.update(correct: true); m.update(correct: true)
    check("il limite inferiore non viene superato", m.exposure == 16)

    c.exposureMs = 990; c.minExposureMs = 16; c.maxExposureMs = 1000
    var mx = StaircaseState(config: c)
    mx.update(correct: false); mx.update(correct: false)
    check("il limite superiore non viene superato", mx.exposure == 1000)

    c.exposureMs = 200; c.maxExposureMs = 1000; c.staircase = .oneUpOneDown
    var r = StaircaseState(config: c)
    check("nessuna soglia prima di quattro inversioni", r.threshold == nil)
    for correct in [true, false, true, false, true, false, true, false] { r.update(correct: correct) }
    check("la soglia compare dopo abbastanza inversioni", r.threshold != nil)
    if let th = r.threshold {
      check("la soglia resta nell'intervallo esplorato", th >= 160 && th <= 220)
    }

    c.staircase = .fixed
    var f = StaircaseState(config: c)
    f.update(correct: false)
    check("esposizione fissa: nessuna variazione", f.exposure == 200)

    var cfg = SessionConfig()
    cfg.set = .bisillabe; cfg.trials = 45; cfg.shuffle = true
    check("la lista viene estesa fino al numero di prove richiesto", cfg.resolvedItems.count == 45)
    cfg.uppercase = true
    check("il maiuscolo viene applicato", cfg.resolvedItems.allSatisfy { $0 == $0.uppercased() })

    print("\nfallimenti: \(failures)")
    exit(failures == 0 ? 0 : 1)
  }
}
