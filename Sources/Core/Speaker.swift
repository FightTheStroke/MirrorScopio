import AVFoundation

/// Voce di sistema, usata per dettare le parole in modalità "Scrivi" e per
/// rileggere la parola giusta a chi vede poco. Tutto locale: nessuna rete.
@MainActor
final class Speaker: NSObject, ObservableObject {
  private let synth = AVSpeechSynthesizer()
  @Published private(set) var isSpeaking = false

  /// Velocità di lettura più bassa del normale: le parole vanno capite, non ascoltate di corsa.
  var rate: Float = 0.42

  override init() {
    super.init()
    synth.delegate = self
  }

  func say(_ text: String, rate customRate: Float? = nil) {
    guard !text.isEmpty else { return }
    stop()
    let u = AVSpeechUtterance(string: text)
    u.voice = Speaker.italianVoice
    u.rate = customRate ?? rate
    u.postUtteranceDelay = 0.1
    isSpeaking = true
    synth.speak(u)
  }

  func stop() {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    isSpeaking = false
  }

  /// Si preferisce una voce italiana di qualità migliorata quando l'utente
  /// l'ha scaricata; altrimenti va bene quella di serie.
  static let italianVoice: AVSpeechSynthesisVoice? = {
    let italian = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("it") }
    return italian.first { $0.quality == .premium }
      ?? italian.first { $0.quality == .enhanced }
      ?? italian.first
      ?? AVSpeechSynthesisVoice(language: "it-IT")
  }()
}

extension Speaker: AVSpeechSynthesizerDelegate {
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
    Task { @MainActor in self.isSpeaking = false }
  }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
    Task { @MainActor in self.isSpeaking = false }
  }
}
