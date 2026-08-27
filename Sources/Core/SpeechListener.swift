import Foundation
import AVFoundation
import Speech
import CoreMedia

/// Stato osservabile della risposta vocale nella prova corrente.
struct VoiceWindowSnapshot {
  var text: String = ""
  var isFinal = false
  var lastUpdate: CFTimeInterval?
  var voiceOnset: CFTimeInterval?
  var confidence: Double?
  var level: Float = 0
}

enum ListenerError: LocalizedError {
  case notAuthorized
  case noAudioFormat
  case localeUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .notAuthorized:
      "Permesso di riconoscimento vocale o microfono negato. Concedilo in Impostazioni di Sistema › Privacy e sicurezza."
    case .noAudioFormat:
      "Nessun formato audio compatibile con il riconoscitore on-device."
    case .localeUnavailable(let l):
      "Il modello vocale on-device per \(l) non è disponibile."
    }
  }
}

/// Riconoscimento vocale continuo, interamente sul dispositivo (framework Speech di macOS 26).
/// Nessun audio lascia il Mac.
final class SpeechListener: @unchecked Sendable {

  private let lock = NSLock()
  private var snapshot = VoiceWindowSnapshot()
  private var windowActive = false
  private var windowStart: CMTime = .zero
  private var framesFed: Int64 = 0

  private let engine = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var transcriber: SpeechTranscriber?
  private var continuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var analyzerFormat: AVAudioFormat?

  /// Soglia RMS per rilevare l'inizio della voce; calibrata sul rumore di fondo all'avvio.
  private var noiseFloor: Float = 0.004
  private var calibrating = true
  private var calibrationSamples: [Float] = []

  // MARK: - Ciclo di vita

  static func requestPermissions() async -> Bool {
    let speech = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
      SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
    }
    guard speech == .authorized else { return false }
    return await AVCaptureDevice.requestAccess(for: .audio)
  }

  func start(locale: Locale, vocabulary: [String]) async throws {
    guard SpeechTranscriber.isAvailable else { throw ListenerError.localeUnavailable(locale.identifier) }

    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      throw ListenerError.localeUnavailable(locale.identifier)
    }

    let tr = SpeechTranscriber(
      locale: supported,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: [.transcriptionConfidence])

    if await AssetInventory.status(forModules: [tr]) != .installed,
       let request = try? await AssetInventory.assetInstallationRequest(supporting: [tr]) {
      try await request.downloadAndInstall()
    }
    _ = try? await AssetInventory.reserve(locale: supported)

    // Il vocabolario della sessione orienta il riconoscitore verso gli stimoli attesi,
    // che è ciò che rende affidabile il punteggio su parole isolate.
    let context = AnalysisContext()
    context.contextualStrings = [.general: Array(Set(vocabulary)).prefix(500).map { $0 }]

    let an = SpeechAnalyzer(modules: [tr])
    try await an.setContext(context)

    guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [tr]) else {
      throw ListenerError.noAudioFormat
    }

    let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
    analyzer = an
    transcriber = tr
    continuation = cont
    analyzerFormat = fmt

    try installTap(target: fmt)
    try await an.start(inputSequence: stream)
    engine.prepare()
    try engine.start()

    resultsTask = Task { [weak self] in
      guard let self else { return }
      do {
        for try await result in tr.results {
          self.ingest(result)
        }
      } catch {
        // La chiusura dell'analizzatore termina la sequenza: non è una condizione di errore.
      }
    }
  }

  func stop() async {
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    continuation?.finish()
    resultsTask?.cancel()
    await analyzer?.cancelAndFinishNow()
    analyzer = nil
    transcriber = nil
  }

  // MARK: - Finestra di risposta

  func beginWindow() {
    lock.lock()
    snapshot = VoiceWindowSnapshot()
    windowStart = CMTime(value: framesFed, timescale: CMTimeScale(analyzerFormat?.sampleRate ?? 16000))
    windowActive = true
    lock.unlock()
  }

  func endWindow() {
    lock.lock(); windowActive = false; lock.unlock()
  }

  func read() -> VoiceWindowSnapshot {
    lock.lock(); defer { lock.unlock() }
    return snapshot
  }

  // MARK: - Audio

  private func installTap(target: AVAudioFormat) throws {
    let input = engine.inputNode
    let natural = input.outputFormat(forBus: 0)
    guard let converter = AVAudioConverter(from: natural, to: target) else {
      throw ListenerError.noAudioFormat
    }

    input.installTap(onBus: 0, bufferSize: 2048, format: natural) { [weak self] buffer, _ in
      guard let self else { return }
      self.measureLevel(buffer)

      let ratio = target.sampleRate / natural.sampleRate
      let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
      guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

      var error: NSError?
      var delivered = false
      converter.convert(to: out, error: &error) { _, status in
        if delivered { status.pointee = .noDataNow; return nil }
        delivered = true
        status.pointee = .haveData
        return buffer
      }
      guard error == nil, out.frameLength > 0 else { return }

      self.lock.lock()
      let start = CMTime(value: self.framesFed, timescale: CMTimeScale(target.sampleRate))
      self.framesFed += Int64(out.frameLength)
      self.lock.unlock()

      self.continuation?.yield(AnalyzerInput(buffer: out, bufferStartTime: start))
    }
  }

  /// Rileva l'inizio della voce dall'energia del segnale: dà la latenza vocale
  /// con precisione molto maggiore di quella ricavabile dalla trascrizione.
  private func measureLevel(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData?[0] else { return }
    let n = Int(buffer.frameLength)
    guard n > 0 else { return }
    var sum: Float = 0
    for i in 0..<n { sum += data[i] * data[i] }
    let rms = (sum / Float(n)).squareRoot()
    let now = CACurrentMediaTime()

    lock.lock()
    snapshot.level = rms

    if calibrating {
      calibrationSamples.append(rms)
      if calibrationSamples.count >= 40 {
        let sorted = calibrationSamples.sorted()
        let median = sorted[sorted.count / 2]
        noiseFloor = max(0.002, median * 4 + 0.002)
        calibrating = false
      }
    } else if windowActive, snapshot.voiceOnset == nil, rms > noiseFloor {
      snapshot.voiceOnset = now
    }
    lock.unlock()
  }

  private func ingest(_ result: SpeechTranscriber.Result) {
    lock.lock()
    defer { lock.unlock() }
    guard windowActive else { return }
    guard result.range.end > windowStart else { return }

    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    snapshot.text = text
    snapshot.isFinal = result.isFinal
    snapshot.lastUpdate = CACurrentMediaTime()
    snapshot.confidence = result.text.runs
      .compactMap { $0.transcriptionConfidence }
      .max()
  }
}
