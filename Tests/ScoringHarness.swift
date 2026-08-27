import Foundation
import AVFoundation
import Speech

/// Verifica end-to-end del punteggio automatico: sintetizza la lettura di ogni
/// stimolo, la trascrive con il modello on-device e confronta il verdetto atteso.
@main
struct ScoringHarness {
  static func main() async {
    let locale = Locale(identifier: "it_IT")

    // Coppie (stimolo mostrato, parola effettivamente pronunciata dal "paziente").
    let cases: [(target: String, spoken: String, expectCorrect: Bool)] = [
      ("cane", "cane", true),
      ("farfalla", "farfalla", true),
      ("tavolo", "tavolo", true),
      ("sedia", "sedia", true),
      ("montagna", "montagna", true),
      ("bicchiere", "bicchiere", true),
      ("elicottero", "elicottero", true),
      ("cane", "pane", false),
      ("tavolo", "volato", false),
      ("farfalla", "falla", false),
    ]

    let vocabulary = StimulusSet.bisillabe.items
      + StimulusSet.trisillabe.items
      + StimulusSet.quadrisillabe.items

    var passed = 0
    for c in cases {
      let url = URL(fileURLWithPath: "/tmp/tachi-\(c.spoken).wav")
      synthesize(c.spoken, to: url)
      let transcript = await transcribe(url: url, locale: locale, vocabulary: vocabulary)
      let verdict = Scoring.classify(target: c.target, response: transcript)
      let ok = verdict.correct == c.expectCorrect
      if ok { passed += 1 }
      print("\(ok ? "PASS" : "FAIL")  mostrato=\(c.target)  detto=\(c.spoken)  trascritto=\"\(transcript)\"  esito=\(verdict.correct ? "esatto" : "errato")  tipo=\(verdict.kind.label)")
    }

    print("\n\(passed)/\(cases.count) casi corretti")
    exit(passed == cases.count ? 0 : 1)
  }

  static func synthesize(_ text: String, to url: URL) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    p.arguments = ["-v", "Alice", "--data-format=LEF32@16000", "-o", url.path, text]
    try? p.run()
    p.waitUntilExit()
  }

  static func transcribe(url: URL, locale: Locale, vocabulary: [String]) async -> String {
    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { return "" }
    let transcriber = SpeechTranscriber(
      locale: supported,
      transcriptionOptions: [],
      reportingOptions: [],
      attributeOptions: [])
    let context = AnalysisContext()
    context.contextualStrings = [.general: Array(Set(vocabulary))]
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    do {
      try await analyzer.setContext(context)
      let file = try AVAudioFile(forReading: url)
      let listen = Task { () -> String in
        var parts: [String] = []
        do {
          for try await r in transcriber.results where r.isFinal {
            parts.append(String(r.text.characters))
          }
        } catch {}
        return parts.joined(separator: " ")
      }
      try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
      try await analyzer.finalizeAndFinishThroughEndOfInput()
      return await listen.value.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return ""
    }
  }
}
