import Foundation
import Combine

@MainActor
final class StudioSessionTracker: ObservableObject {
  @Published private(set) var active = false
  private let store: StudioStore
  private var anchor: TimeInterval?
  private let uptime: () -> TimeInterval
  private let now: () -> Date

  init(store: StudioStore, uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       now: @escaping () -> Date = Date.init) {
    self.store = store
    self.uptime = uptime
    self.now = now
  }

  @discardableResult
  func start(lessonID: UUID) -> Bool {
    if let current = store.archive.currentSession {
      guard current.lessonID == lessonID else { return false }
      return resume()
    }
    let date = now()
    let success = store.change {
      $0.currentSession = StudioSession(lessonID: lessonID, startedAt: date,
        events: [StudioSessionEvent(kind: .start, date: date, activeSeconds: 0)])
    }
    if success { anchor = uptime(); active = true }
    return success
  }

  @discardableResult
  func resume() -> Bool {
    guard !active, store.archive.currentSession != nil else { return active }
    let date = now()
    let success = store.change {
      let seconds = $0.currentSession?.activeSeconds ?? 0
      $0.currentSession?.events.append(StudioSessionEvent(kind: .resume, date: date,
        activeSeconds: seconds))
    }
    if success { anchor = uptime(); active = true }
    return success
  }

  /// Il tempo nel file è solo quello già osservato. Un rilancio non conta il tempo a app chiusa.
  func checkpoint() {
    guard active, let anchor else { return }
    let current = uptime()
    if store.change({ $0.currentSession?.activeSeconds += max(0, current - anchor) }) {
      self.anchor = current
    } else {
      // La modifica in attesa include già questo intervallo; non va conteggiato due volte.
      store.notePendingPause(at: now())
      active = false
      self.anchor = nil
    }
  }

  func pause() {
    guard active else { return }
    let elapsed = anchor.map { max(0, uptime() - $0) } ?? 0
    let date = now()
    _ = store.change {
      $0.currentSession?.activeSeconds += elapsed
      let seconds = $0.currentSession?.activeSeconds ?? 0
      $0.currentSession?.events.append(StudioSessionEvent(kind: .pause, date: date,
        activeSeconds: seconds))
    }
    active = false
    anchor = nil
  }

  @discardableResult
  func finish(_ outcome: StudioSessionOutcome) -> Bool {
    let elapsed = active ? anchor.map { max(0, uptime() - $0) } ?? 0 : 0
    let date = now()
    let success = store.change {
      guard var session = $0.currentSession else { throw StudioFailure("Non c'è una sessione da concludere.") }
      session.activeSeconds += elapsed
      session.endedAt = max(date, session.startedAt)
      session.outcome = outcome
      session.events.append(StudioSessionEvent(kind: .finish, date: date, activeSeconds: session.activeSeconds))
      $0.sessions.append(session)
      $0.currentSession = nil
    }
    active = false
    anchor = nil
    return success
  }
}

enum StudioReport {
  static let disclaimer = "Dati descrittivi: non è una valutazione clinica. Tempo e tocchi non misurano la comprensione."

  static func summary(_ archive: StudioArchive) -> String {
    let minutes = Int(archive.sessions.reduce(0) { $0 + $1.activeSeconds } / 60)
    return "\(archive.sessions.count) sessioni concluse; \(minutes) minuti attivi registrati; \(archive.attempts.count) autovalutazioni. \(disclaimer)"
  }

  private static func cell(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let safe = ["=", "+", "-", "@"].contains(where: trimmed.hasPrefix) ? "'" + text : text
    return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  static func csv(_ archive: StudioArchive) -> Data {
    let iso = ISO8601DateFormatter()
    var rows = [[disclaimer],
      ["tipo", "lezione", "data", "secondi_attivi", "modalita", "esito_dichiarato", "fatica_1_5",
       "aiuti", "domanda", "tentativo", "risposta_modello", "fonte_segmento"]]
    for session in archive.sessions {
      rows.append(["sessione", archive.lessons.first { $0.id == session.lessonID }?.title ?? "",
        iso.string(from: session.startedAt), String(Int(session.activeSeconds)), session.mode.rawValue,
        session.outcome.rawValue, session.fatigue.map(String.init) ?? "", session.adultHelp, "", "", "", ""])
    }
    for attempt in archive.attempts {
      rows.append(["ripasso", archive.lessons.first { $0.id == attempt.lessonID }?.title ?? "",
        iso.string(from: attempt.date), "", "", attempt.recall.rawValue, "", attempt.help.rawValue,
        attempt.question, attempt.text, attempt.answer, attempt.segmentID.uuidString])
    }
    return Data(rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n").utf8)
  }
}
