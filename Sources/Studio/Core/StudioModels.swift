import Foundation

enum StudioLimits {
  static let text = 120_000
  static let segment = 600
  static let lessons = 100
  static let cards = 2_000
  static let records = 20_000
  static let fileBytes = 20 * 1_024 * 1_024
  static let pages = 30
  static let scannedPages = 10
  static let description = "Per file: massimo 20 MB, 30 pagine PDF (10 da riconoscere), 120.000 caratteri per lezione. In totale: archivio Studio fino a 20 MB e 100 lezioni."
}

struct StudioFailure: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

enum StudioSegmenter {
  /// I separatori restano nel segmento: concatenando si ritrova il testo originale.
  static func split(_ text: String, limit: Int = StudioLimits.segment) throws -> [String] {
    guard limit > 0, text.count <= StudioLimits.text else {
      throw StudioFailure("Testo troppo lungo: usa al massimo \(StudioLimits.text) caratteri.")
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw StudioFailure("Aggiungi il testo della lezione.")
    }
    var result: [String] = []
    var buffer = ""
    for character in text {
      buffer.append(character)
      if ".!?;\n".contains(character) || buffer.count == limit {
        result.append(buffer)
        buffer = ""
      }
    }
    if !buffer.isEmpty { result.append(buffer) }
    // Spazi dopo un punto appartengono alla frase successiva; nessun carattere viene tolto.
    return result
  }
}

struct StudioSegment: Codable, Equatable, Identifiable {
  var id = UUID()
  var text: String
}

enum StudioSchema: String, Codable, CaseIterable {
  case explanation = "Spiego un argomento"
  case story = "Racconto una storia"
  var prompts: [String] {
    self == .story ? ["Chi e dove", "Che cosa succede", "Come finisce"]
      : ["Idea principale", "Un dettaglio", "Un esempio"]
  }
}

struct StudioMap: Codable, Equatable {
  var schema: StudioSchema = .explanation
  var ideas = ["", "", ""]
  var connection = ""
}

struct StudioProcedure: Codable, Equatable, Identifiable {
  var id = UUID()
  var text = ""
}

struct StudioLesson: Codable, Equatable, Identifiable {
  var id = UUID()
  var title: String
  var subject: String
  var source: String
  var segments: [StudioSegment]
  var position = 0
  var map = StudioMap()
  var procedures: [StudioProcedure] = []
  var createdAt = Date()

  init(title: String, subject: String, source: String) throws {
    self.title = title
    self.subject = subject
    self.source = source
    segments = try StudioSegmenter.split(source).map { StudioSegment(text: $0) }
  }
}

enum StudioHelp: String, Codable, CaseIterable {
  case none = "Senza strumenti"
  case map = "Con mappa"
  case procedure = "Con formulario"
  case source = "Con testo o ascolto"
  case adult = "Con un adulto"
  case several = "Con più aiuti"

  func adding(_ other: StudioHelp) -> StudioHelp {
    if self == .none { return other }
    return self == other ? self : .several
  }
}

enum StudioRecall: String, Codable, CaseIterable {
  case remembered = "Ricordato"
  case helped = "Con aiuto"
  case again = "Ancora"
}

struct StudioCard: Codable, Equatable, Identifiable {
  var id = UUID()
  var lessonID: UUID
  var segmentID: UUID
  var question: String
  var answer: String
  var approved = false
  var stage = 0
  var due = Date()
}

struct StudioAttempt: Codable, Equatable, Identifiable {
  var id = UUID()
  var cardID: UUID
  var lessonID: UUID
  var segmentID: UUID
  var question: String
  var answer: String
  var text: String
  var help: StudioHelp
  var recall: StudioRecall
  var date: Date
}

enum StudioSchedule {
  static let defaults = [1, 3, 7, 14, 30]

  static func next(stage: Int, recall: StudioRecall, help: StudioHelp,
                   intervals: [Int], now: Date) -> (stage: Int, due: Date) {
    let nextStage: Int
    switch recall {
    case .again: nextStage = 0
    case .helped: nextStage = max(0, stage - 1)
    case .remembered: nextStage = help == .none ? min(stage + 1, intervals.count - 1) : stage
    }
    let delay = recall == .again ? intervals[0] : intervals[min(stage, nextStage)]
    return (nextStage, now.addingTimeInterval(TimeInterval(delay) * 86_400))
  }

  static func due(in archive: StudioArchive, lessonID: UUID, now: Date) -> [StudioCard] {
    archive.cards.filter { $0.lessonID == lessonID && $0.approved && $0.due <= now }
      .sorted { $0.due == $1.due ? $0.id.uuidString < $1.id.uuidString : $0.due < $1.due }
  }
}

enum StudioMode: String, Codable, CaseIterable {
  case reading = "Lettura"
  case listening = "Ascolto"
  case mixed = "Mista"
}

enum StudioSessionEventKind: String, Codable {
  case start, pause, resume, finish
}

struct StudioSessionEvent: Codable, Equatable {
  var kind: StudioSessionEventKind
  var date: Date
  var activeSeconds: Double
}

enum StudioSessionOutcome: String, Codable {
  case ongoing = "In corso"
  case completed = "Completato"
  case interrupted = "Interrotto"
}

struct StudioSession: Codable, Equatable, Identifiable {
  var id = UUID()
  var lessonID: UUID
  var startedAt: Date
  var endedAt: Date?
  var activeSeconds: Double = 0
  var mode: StudioMode = .reading
  var fatigue: Int?
  var adultHelp: String = ""
  var outcome: StudioSessionOutcome = .ongoing
  var events: [StudioSessionEvent] = []
}

struct StudioSettings: Codable, Equatable {
  var voiceID = ""
  var rate: Double = 0.42
  var largeText = false
  var intervals = StudioSchedule.defaults
  var intervalDraft = "1, 3, 7, 14, 30"
}

struct StudioLessonDraft: Codable, Equatable {
  var title = ""
  var subject = ""
  var source = ""
}

struct StudioCardDraft: Codable, Equatable {
  var lessonID: UUID?
  var segmentID: UUID?
  var question = ""
  var answer = ""
}

struct StudioReviewRun: Codable, Equatable {
  var lessonID: UUID
  var remaining: [UUID]
  var text = ""
  var help: StudioHelp = .none
  var revealed = false
}

struct StudioArchive: Codable, Equatable {
  var version = 1
  var lessons: [StudioLesson] = []
  var cards: [StudioCard] = []
  var attempts: [StudioAttempt] = []
  var sessions: [StudioSession] = []
  var currentSession: StudioSession?
  var settings = StudioSettings()
  var draft = StudioLessonDraft()
  var cardDraft = StudioCardDraft()
  var reviewRun: StudioReviewRun?

  mutating func deleteLesson(_ id: UUID) {
    lessons.removeAll { $0.id == id }
    cards.removeAll { $0.lessonID == id }
    attempts.removeAll { $0.lessonID == id }
    sessions.removeAll { $0.lessonID == id }
    if currentSession?.lessonID == id { currentSession = nil }
    if cardDraft.lessonID == id { cardDraft = StudioCardDraft() }
    if reviewRun?.lessonID == id { reviewRun = nil }
  }
}
