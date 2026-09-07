import AVFoundation
import Combine
import Foundation

@MainActor
final class StudioAudio: NSObject, ObservableObject {
  enum State { case stopped, speaking, paused }
  @Published private(set) var state: State = .stopped
  @Published private(set) var message: String?
  var onInterruption: (() -> Void)?
  private let synthesizer = AVSpeechSynthesizer()
  private var currentUtterance: AVSpeechUtterance?
  // Anche le letture annullate restano vive fino alla consegna della notifica:
  // un indirizzo riutilizzato non deve fermare una lettura successiva.
  private var retainedUtterances: [ObjectIdentifier: AVSpeechUtterance] = [:]
  private var subscriptions: Set<AnyCancellable> = []

  override init() {
    super.init()
    synthesizer.delegate = self
    #if os(iOS)
    NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
      .receive(on: RunLoop.main).sink { [weak self] _ in
        self?.stop()
        self?.onInterruption?()
        self?.message = "Ascolto interrotto dal dispositivo. Premi Ascolta per ripartire, quando vuoi."
      }.store(in: &subscriptions)
    NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
      .receive(on: RunLoop.main).sink { [weak self] notification in
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        self?.stop()
        self?.onInterruption?()
        self?.message = "L'uscita audio è cambiata. Controlla il volume e premi Ascolta."
      }.store(in: &subscriptions)
    #endif
  }

  func speak(_ text: String, settings: StudioSettings) {
    stop()
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      message = "Questo segmento contiene solo spazi. Puoi passare al successivo."
      return
    }
    let voices = Speaker.italianVoices()
    let voice = settings.voiceID.isEmpty ? voices.first : voices.first { $0.identifier == settings.voiceID }
    guard let voice else {
      message = "La voce italiana scelta non è installata. Scegli una voce disponibile in Per l'adulto."
      return
    }
    do {
      #if os(iOS)
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      #endif
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = Float(settings.rate)
      currentUtterance = utterance
      retainedUtterances[ObjectIdentifier(utterance)] = utterance
      state = .speaking
      message = nil
      synthesizer.speak(utterance)
    } catch {
      message = "L'audio non è disponibile: \(error.localizedDescription)"
      state = .stopped
    }
  }

  func togglePause() {
    switch state {
    case .speaking:
      if synthesizer.pauseSpeaking(at: .immediate) { state = .paused }
      else { message = "Non sono riuscito a mettere in pausa. Puoi fermare o ripetere il segmento." }
    case .paused:
      if synthesizer.continueSpeaking() { state = .speaking }
      else { stop(); message = "Premi Ascolta per ripetere il segmento." }
    case .stopped: break
    }
  }

  func stop() {
    currentUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    state = .stopped
    deactivate()
  }

  func background() {
    let wasPlaying = state != .stopped
    stop()
    if wasPlaying { message = "Ascolto fermato mentre l'app non era in primo piano. Riparti quando vuoi." }
  }

  private func deactivate() {
    #if os(iOS)
    do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    catch { message = "Non posso liberare l'audio: \(error.localizedDescription)" }
    #endif
  }

  private func completed(_ id: ObjectIdentifier) {
    guard let utterance = retainedUtterances.removeValue(forKey: id) else { return }
    guard currentUtterance === utterance else { return }
    self.currentUtterance = nil
    state = .stopped
    deactivate()
  }
}

extension StudioAudio: AVSpeechSynthesizerDelegate {
  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    let id = ObjectIdentifier(utterance)
    Task { @MainActor [weak self] in self?.completed(id) }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    let id = ObjectIdentifier(utterance)
    Task { @MainActor [weak self] in self?.completed(id) }
  }
}
