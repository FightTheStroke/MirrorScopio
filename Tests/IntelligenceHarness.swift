import Foundation

@main
struct IntelligenceHarness {
  static func main() async {
    let ok = await MainActor.run { Intelligence.isAvailable }
    print("disponibile:", ok)
    guard ok else { exit(1) }

    if let j = await Intelligence.judge(target: "farfalla", transcript: "far falla") {
      print("giudizio 'far falla' vs 'farfalla' -> categoria=\(j.categoria)")
    } else { print("judge: nil"); exit(1) }

    if let j = await Intelligence.judge(target: "tavolo", transcript: "volato") {
      print("giudizio 'volato' vs 'tavolo' -> categoria=\(j.categoria)")
    } else { print("judge: nil"); exit(1) }

    var trials: [Trial] = []
    for (i, s) in ["cane", "tavolo", "farfalla", "montagna"].enumerated() {
      var t = Trial(id: i + 1, stimulus: s)
      t.response = i % 2 == 0 ? s : "volato"
      t.correct = i % 2 == 0
      t.errorKind = t.correct ? .none : .inversione
      t.requestedExposureMs = 150
      t.actualExposureMs = 150
      t.vocalLatencyMs = 620
      trials.append(t)
    }
    if let s = await Intelligence.summarize(trials: trials, thresholdMs: 132, config: SessionConfig()) {
      print("--- sintesi ---")
      print(s.profilo)
      print("pattern:", s.patternPrevalente)
      print("proposte:", s.proposte.joined(separator: " | "))
    } else { print("summarize: nil"); exit(1) }
  }
}
