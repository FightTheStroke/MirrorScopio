import AVFoundation

/// Voce di sistema, usata per dettare le parole in modalità "Scrivi" e per
/// rileggere la parola giusta a chi vede poco. Tutto locale: nessuna rete.
@MainActor
final class Speaker: NSObject, ObservableObject {
  private let synth = AVSpeechSynthesizer()
  @Published private(set) var isSpeaking = false

  /// Velocità di lettura più bassa del normale: le parole vanno capite, non ascoltate di corsa.
  var rate: Float = 0.42

  /// Voce scelta dall'utente. Se vuota si usa la migliore italiana trovata.
  var voiceIdentifier: String?

  override init() {
    super.init()
    synth.delegate = self
  }

  func say(_ text: String, rate customRate: Float? = nil) {
    guard !text.isEmpty else { return }
    stop()
    let u = AVSpeechUtterance(string: text)
    u.voice = chosenVoice
    u.rate = customRate ?? rate
    u.postUtteranceDelay = 0.1
    isSpeaking = true
    synth.speak(u)
  }

  func stop() {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    isSpeaking = false
  }

  var chosenVoice: AVSpeechSynthesisVoice? {
    if let voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: voiceIdentifier) { return v }
    return Speaker.bestItalianVoice
  }

  /// Le voci italiane installate, dalla migliore alla più semplice.
  ///
  /// Deliberatamente **non** in cache: le voci si scaricano mentre l'app è
  /// aperta, e una lista calcolata una volta sola al lancio mostrava soltanto
  /// «Alice» anche a chi aveva Federica Premium installata.
  static func italianVoices() -> [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("it") }
      .sorted { a, b in
        if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
        return a.name.localizedCompare(b.name) == .orderedAscending
      }
  }

  /// Si preferisce una voce italiana di qualità migliore quando c'è.
  static var bestItalianVoice: AVSpeechSynthesisVoice? {
    italianVoices().first ?? AVSpeechSynthesisVoice(language: "it-IT")
  }

  /// Nome leggibile della qualità, per l'elenco delle voci.
  static func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
    switch v.quality {
    case .premium: return "la più naturale"
    case .enhanced: return "migliorata"
    default: return "di serie"
    }
  }
}

extension Speaker: AVSpeechSynthesizerDelegate {
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
    Task { @MainActor in self.isSpeaking = false }
  }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
    Task { @MainActor in self.isSpeaking = false }
  }
}
