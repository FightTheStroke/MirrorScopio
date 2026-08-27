import Foundation

// MARK: - Che cosa resta salvato

/// Una parola della sessione, con il suo esito. È l'unità del registro.
struct ItemRecord: Codable, Identifiable {
  var id = UUID()
  var stimulus: String
  var response: String
  var correct: Bool
  var exposureMs: Double
  var latencyMs: Double?
  var errorKind: String
  var warmup: Bool = false
}

/// Una sessione conclusa. È quello che alimenta dashboard, progressi e PDF.
struct SessionRecord: Codable, Identifiable {
  var id = UUID()
  var learnerID: UUID?
  var date = Date()
  var mode: SessionMode = .lettura
  var level: Level = .base
  var setLabel: String = ""
  var correct: Int = 0
  var total: Int = 0
  var thresholdMs: Double?
  var meanLatencyMs: Double?
  var items: [ItemRecord] = []

  var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }

  /// Le parole sbagliate, per poterle ripassare subito dopo.
  var missedWords: [String] {
    items.filter { !$0.correct && !$0.warmup }.map(\.stimulus)
  }

  var errorCounts: [String: Int] {
    Dictionary(grouping: items.filter { !$0.correct }, by: \.errorKind)
      .mapValues(\.count)
  }
}

/// Chi usa l'app. Un Mac può ospitarne più d'uno (fratelli, più pazienti).
struct Learner: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String = ""
  var a11y = A11ySettings()
  var config = SessionConfig()
  /// Velocità di partenza misurata dal test iniziale, in millisecondi.
  var calibratedExposureMs: Double?
  var calibratedAt: Date?
  var xp: Int = 0
  var streakCurrent: Int = 0
  var streakLongest: Int = 0
  var lastSessionDay: String?
  var unlockedAchievements: [String] = []
}

// MARK: - Archivio su disco

/// Tutto vive in `~/Library/Application Support/MirrorScopio/`, in chiaro, in JSON:
/// niente rete, niente account, e un adulto può leggere o cancellare i file a mano.
@MainActor
final class Store: ObservableObject {
  @Published var learners: [Learner] = []
  @Published var currentID: UUID?
  @Published private(set) var history: [SessionRecord] = []

  private let folder: URL
  private let learnersURL: URL
  private let historyURL: URL

  init(folder: URL? = nil) {
    let base = folder ?? FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MirrorScopio", isDirectory: true)
    self.folder = base
    self.learnersURL = base.appendingPathComponent("learners.json")
    self.historyURL = base.appendingPathComponent("history.json")
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    load()
  }

  var current: Learner {
    get {
      if let id = currentID, let l = learners.first(where: { $0.id == id }) { return l }
      return learners.first ?? Learner(name: "")
    }
    set {
      if let i = learners.firstIndex(where: { $0.id == newValue.id }) {
        learners[i] = newValue
      } else {
        learners.append(newValue)
      }
      currentID = newValue.id
      save()
    }
  }

  /// Le sessioni di chi sta usando l'app adesso, dalla più recente.
  var currentHistory: [SessionRecord] {
    history.filter { $0.learnerID == currentID }.sorted { $0.date > $1.date }
  }

  func addLearner(name: String) {
    var l = Learner(name: name)
    l.a11y = A11ySettings()
    learners.append(l)
    currentID = l.id
    save()
  }

  func record(_ session: SessionRecord) {
    var s = session
    s.learnerID = currentID
    history.append(s)
    var l = current
    Gamification.apply(session: s, to: &l)
    current = l
    save()
  }

  /// Usata quando punti e obiettivi sono già stati calcolati altrove:
  /// evita di assegnarli due volte alla stessa sessione.
  func recordAlreadyScored(_ session: SessionRecord) {
    guard !history.contains(where: { $0.id == session.id }) else { return }
    history.append(session)
    save()
  }

  func deleteHistory() {
    history.removeAll { $0.learnerID == currentID }
    save()
  }

  // MARK: - Lettura e scrittura

  private func load() {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    if let d = try? Data(contentsOf: learnersURL),
       let l = try? dec.decode([Learner].self, from: d) {
      learners = l
    }
    if let d = try? Data(contentsOf: historyURL),
       let h = try? dec.decode([SessionRecord].self, from: d) {
      history = h
    }
    if learners.isEmpty {
      learners = [Learner(name: "")]
    }
    currentID = learners.first?.id
  }

  func save() {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601
    try? enc.encode(learners).write(to: learnersURL, options: .atomic)
    try? enc.encode(history).write(to: historyURL, options: .atomic)
  }

  var storageFolder: URL { folder }
}
