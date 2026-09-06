import Foundation
import FoundationModels

@Generable
struct StudioGeneratedLesson: Equatable, Sendable {
  @Guide(description: "Spiegazione italiana semplice, fino a 900 caratteri.")
  var explanation: String
  @Guide(description: "Tre idee brevi, fino a 180 caratteri ciascuna.", .count(3))
  var ideas: [String]
  @Guide(description: "Come si collegano le tre idee, fino a 300 caratteri.")
  var connection: String
  @Guide(description: "Solo se utili: regole o passi concreti, fino a 180 caratteri ciascuno.", .maximumCount(3))
  var procedures: [String]
}

@Generable
struct StudioGeneratedCard: Equatable, Sendable {
  @Guide(description: "Domanda semplice in italiano, fino a 180 caratteri.")
  var question: String
  @Guide(description: "Risposta proposta per la revisione del genitore, fino a 300 caratteri.")
  var answer: String
  @Guide(description: "Spunto breve, senza giudizi, fino a 180 caratteri. Vuoto se inutile.")
  var hint: String
  @Guide(description: "Numero della parte fornita che contiene il riferimento, a partire da 1.")
  var segmentNumber: Int
  @Guide(description: "Citazione esatta copiata da quella parte, senza cambiarla, fino a 160 caratteri.")
  var quote: String
}

@Generable
struct StudioGeneratedQuestions: Sendable {
  @Guide(description: "Due o tre domande diverse basate soltanto sulle parti fornite.", .count(2...3))
  var cards: [StudioGeneratedCard]
}

struct StudioGenerationInput: Equatable, Sendable {
  static let sourceLimit = 2_400
  static let sourceByteLimit = 4_800
  static let limitMessage = """
    Usa una fonte breve: massimo 2.400 caratteri e 4.800 byte (lo spazio occupato dal testo). \
    Il modello locale ha un limite di 4.096 unità di testo, condivise con istruzioni e risposta: \
    anche un testo più corto può richiedere di essere ridotto. Non tagliamo nulla automaticamente.
    """
  var topic = ""
  var subject = ""
  var source = ""
  var hasSource: Bool { !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  func validate() throws {
    try StudioGenerationValidation.text(topic, name: "Argomento", limit: 200)
    try StudioGenerationValidation.text(subject, name: "Materia", limit: 100, required: false)
    guard source.count <= Self.sourceLimit, source.utf8.count <= Self.sourceByteLimit else {
      throw StudioFailure(Self.limitMessage)
    }
    if hasSource { _ = try StudioGenerationValidation.segments(source) }
  }
}

enum StudioGenerationValidation {
  static let syntheticLabel = "Materiale sintetico da un argomento, non una fonte verificata."
  static let sourceLabel = "Rielaborazione di una fonte fornita: il riferimento non prova l'accuratezza."

  static func text(_ value: String, name: String, limit: Int, required: Bool = true) throws {
    guard value.count <= limit, value.utf8.count <= limit * 4,
          !required || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw StudioFailure("\(name): \(required ? "scrivi un testo, " : "")massimo \(limit) caratteri.")
    }
  }

  static func segments(_ source: String) throws -> [String] {
    let parts = try StudioSegmenter.split(source)
    guard parts.count <= 40 else {
      throw StudioFailure("Ci sono troppe parti brevi per il modello locale. Usa una fonte più breve (massimo 40 parti).")
    }
    return parts
  }

  static func lesson(_ value: StudioGeneratedLesson) throws {
    try text(value.explanation, name: "Spiegazione", limit: 1_400)
    guard value.ideas.count == 3, value.procedures.count <= 3 else {
      throw StudioFailure("Servono tre idee e al massimo tre passi. Rigenera la proposta.")
    }
    for idea in value.ideas { try text(idea, name: "Idea", limit: 240) }
    try text(value.connection, name: "Collegamento", limit: 400)
    for step in value.procedures { try text(step, name: "Passo", limit: 240) }
  }

  static func reference(_ card: StudioGeneratedCard, in parts: [String]) throws -> Int {
    guard card.segmentNumber > 0, card.segmentNumber <= parts.count else {
      throw StudioFailure("Una domanda indica una parte che non esiste. Scegli il riferimento nel testo.")
    }
    let index = card.segmentNumber - 1
    try text(card.quote, name: "Citazione", limit: StudioLimits.segment)
    // Confronto letterale, non semantico: nessun modello decide se una risposta è corretta.
    guard parts[index].range(of: card.quote, options: .literal) != nil else {
      throw StudioFailure("La citazione non compare esattamente nella parte scelta. Ricopiala dalla fonte, senza cambiarla.")
    }
    return index
  }
}

struct StudioGenerationDraft: Equatable, Sendable {
  let input: StudioGenerationInput
  var content: StudioGeneratedLesson
  var cards: [StudioGeneratedCard]
  var provenance: String {
    input.hasSource ? StudioGenerationValidation.sourceLabel : StudioGenerationValidation.syntheticLabel
  }
  var referenceSource: String { input.hasSource ? input.source : content.explanation }

  func referenceParts() throws -> [String] {
    try StudioGenerationValidation.segments(referenceSource)
  }

  func validate() throws {
    try input.validate()
    try StudioGenerationValidation.lesson(content)
    guard (2...3).contains(cards.count) else {
      throw StudioFailure("Servono due o tre domande. Rigenera la proposta.")
    }
    let parts = try referenceParts()
    var questions = Set<String>()
    for card in cards {
      try StudioGenerationValidation.text(card.question, name: "Domanda", limit: 400)
      try StudioGenerationValidation.text(card.answer, name: "Risposta", limit: 800)
      try StudioGenerationValidation.text(card.hint, name: "Spunto", limit: 240, required: false)
      guard questions.insert(card.question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted else {
        throw StudioFailure("Due domande sono uguali. Rendile diverse prima di confermare.")
      }
      _ = try StudioGenerationValidation.reference(card, in: parts)
    }
  }

  /// Si chiama solo dopo il consenso: in anteprima non si creano lezioni né carte approvate.
  func prepareApproval() throws -> StudioGenerationApproval {
    try validate()
    let parts = try referenceParts()
    let prefix = input.hasSource ? "" : provenance + "\n\n"
    var lesson = try StudioLesson(title: input.topic.trimmingCharacters(in: .whitespacesAndNewlines),
                                  subject: input.subject, source: prefix + referenceSource)
    // I confini sono gli stessi mostrati al genitore, anche quando il prefisso è sintetico.
    let prefixParts = prefix.isEmpty ? [] : try StudioSegmenter.split(prefix)
    lesson.segments = (prefixParts + parts).map { StudioSegment(text: $0) }
    lesson.map = StudioMap(ideas: content.ideas, connection: """
      \(provenance)
      Spiegazione preparata con Apple Intelligence e riletta dal genitore:
      \(content.explanation)

      Collegamento tra le idee:
      \(content.connection)
      """)
    lesson.procedures = content.procedures.map { StudioProcedure(text: $0) }
    let approvedCards = try cards.map { card in
      let index = try StudioGenerationValidation.reference(card, in: parts) + prefixParts.count
      let hint = card.hint.trimmingCharacters(in: .whitespacesAndNewlines)
      let answer = card.answer + (hint.isEmpty ? "" : "\n\nSpunto: \(card.hint)")
      return StudioCard(lessonID: lesson.id, segmentID: lesson.segments[index].id,
                        question: card.question, answer: answer, approved: true)
    }
    return StudioGenerationApproval(lesson: lesson, cards: approvedCards)
  }
}

struct StudioGenerationApproval {
  let lesson: StudioLesson
  let cards: [StudioCard]

  func insert(into archive: inout StudioArchive) throws {
    guard !archive.lessons.contains(where: { $0.id == lesson.id }) else {
      throw StudioFailure("Questa proposta è già stata aggiunta.")
    }
    var candidate = archive
    candidate.lessons.append(lesson)
    candidate.cards.append(contentsOf: cards)
    try candidate.enrollLesson(lesson.id)
    try StudioCodec.validate(candidate)
    archive = candidate
  }
}

/// Una risposta arrivata dopo annullamento o dopo un'altra richiesta non può diventare una bozza.
struct StudioGenerationRun {
  private(set) var id: UUID?
  mutating func begin() -> UUID {
    let value = UUID()
    id = value
    return value
  }
  mutating func cancel() { id = nil }
  func accepts(_ candidate: UUID) -> Bool { id == candidate }
}
