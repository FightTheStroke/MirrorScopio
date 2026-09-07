import Foundation

enum StudioProgramBlock: String, Codable, CaseIterable {
  case activation = "Mi preparo"
  case comprehension = "Capisco il testo"
  case strategy = "Metto in ordine le idee"
  case retrieval = "Riprendo il filo"
}

enum StudioProgramKind: String, Codable {
  case reading, sequence, choice, open
}

struct StudioProgramOption: Codable, Equatable, Identifiable {
  var id: Int
  var text: String
}

struct StudioProgramActivity: Codable, Equatable, Identifiable {
  var id: String
  var block: StudioProgramBlock
  var kind: StudioProgramKind
  var instruction: String
  var material: String
  var support: String
  var reference: String
  var options: [StudioProgramOption] = []
  var answer: [Int] = []
}

struct StudioProgramLoad: Codable, Equatable {
  var memory = 2
  var instructions = 2
  var sentences = 2
}

struct StudioProgramLesson: Codable, Equatable {
  var catalogID: String
  var stage: Int
  var session: Int
  var load: StudioProgramLoad
  var activities: [StudioProgramActivity]
}

struct StudioProgramStep: Codable, Equatable {
  var position = 0
  var selection: [Int] = []
  var text = ""
  var hidden = false
  var help: StudioHelp = .none
  var revealed = false
  var usedReference = false
  var selfAssessment: StudioRecall?
}

struct StudioProgramResponse: Codable, Equatable {
  var activityID: String
  var instruction: String
  var reference: String
  var kind: StudioProgramKind
  var selection: [Int]
  var text: String
  var help: StudioHelp
  var usedReference: Bool
  var matched: Bool?
  var matchedUnits: Int?
  var totalUnits: Int?
  var selfAssessment: StudioRecall?
  var date: Date
}

enum StudioProgramEngine {
  static let title = "Un passo alla volta · 8 settimane"
  static let explanation = "8 tappe, con 5 incontri proposti per tappa. Le settimane sono una traccia, non una scadenza. Puoi fermarti anche dopo una sola attività: il punto resta salvato."

  static func matches(_ activity: StudioProgramActivity, selection: [Int]) -> Bool? {
    switch activity.kind {
    case .choice, .sequence: selection == activity.answer
    case .reading, .open: nil
    }
  }

  static func response(_ activity: StudioProgramActivity, step: StudioProgramStep,
                       now: Date) throws -> StudioProgramResponse {
    guard step.revealed else { throw StudioFailure("Apri prima il confronto.") }
    if activity.kind == .open, step.selfAssessment == nil {
      throw StudioFailure("Scegli com'è andata per te: non è un voto.")
    }
    let matched = matches(activity, selection: step.selection)
    let units = matched == nil ? nil :
      zip(step.selection, activity.answer).filter { $0 == $1 }.count
    let text = matched == nil ? step.text : step.selection.compactMap { id in
      activity.options.first(where: { $0.id == id })?.text
    }.joined(separator: " → ")
    return StudioProgramResponse(activityID: activity.id, instruction: activity.instruction,
      reference: activity.reference, kind: activity.kind, selection: step.selection,
      text: text, help: step.help, usedReference: step.usedReference, matched: matched,
      matchedUnits: units, totalUnits: matched == nil ? nil : activity.answer.count,
      selfAssessment: step.selfAssessment, date: now)
  }

  static func validate(_ archive: StudioArchive) throws {
    func require(_ value: Bool, _ message: String) throws {
      if !value { throw StudioFailure(message) }
    }
    let blockOrder = StudioProgramBlock.allCases
    let programLessons = archive.lessons.compactMap(\.program)
    try require(Set(programLessons.map(\.catalogID)).count == programLessons.count,
                "Un incontro del percorso è presente due volte.")
    for program in programLessons {
      try require((1...8).contains(program.stage) && (1...5).contains(program.session)
        && program.catalogID == "passi-v1-\(program.stage)-\(program.session)"
        && (2...4).contains(program.load.memory) && (2...3).contains(program.load.instructions)
        && (2...5).contains(program.load.sentences),
        "Tappa, incontro o carico del percorso non valido.")
      try require((4...40).contains(program.activities.count)
        && Set(program.activities.map(\.id)).count == program.activities.count
        && Set(program.activities.map(\.block)) == Set(blockOrder)
        && zip(program.activities, program.activities.dropFirst()).allSatisfy {
          (blockOrder.firstIndex(of: $0.block) ?? 0) <= (blockOrder.firstIndex(of: $1.block) ?? 0)
        },
        "Ogni incontro richiede quattro blocchi e attività distinte.")
      for activity in program.activities {
        try require(!activity.id.isEmpty && activity.id.count <= 100
          && !activity.instruction.isEmpty && activity.instruction.count <= 2_000
          && activity.material.count <= 10_000 && activity.support.count <= 10_000
          && !activity.reference.isEmpty && activity.reference.count <= 10_000
          && activity.options.count <= 12 && Set(activity.options.map(\.id)).count == activity.options.count
          && activity.options.allSatisfy { !$0.text.isEmpty && $0.text.count <= 2_000 },
          "Un'attività contiene una consegna, un aiuto o delle scelte non validi.")
        let closed = activity.kind == .choice || activity.kind == .sequence
        try require(closed
          ? !activity.answer.isEmpty && Set(activity.answer).count == activity.answer.count
            && activity.answer.allSatisfy { id in activity.options.contains { $0.id == id } }
            && (activity.kind != .choice || activity.answer.count == 1)
          : activity.options.isEmpty && activity.answer.isEmpty,
          "Le risposte chiuse devono avere una soluzione; quelle aperte non hanno un correttore automatico.")
      }
    }
    if let run = archive.guidedRun {
      let program = archive.lessons.first { $0.id == run.lessonID }?.program
      try require((run.phase == .program) == (run.programStep != nil),
                  "Il segnalibro non corrisponde al tipo di attività.")
      if let step = run.programStep, let program,
         program.activities.indices.contains(step.position) {
        let activity = program.activities[step.position]
        try require(step.text.count <= 5_000 && Set(step.selection).count == step.selection.count
          && step.selection.allSatisfy { id in activity.options.contains { $0.id == id } }
          && (activity.kind != .choice || step.selection.count <= 1)
          && (activity.kind == .open || step.selfAssessment == nil)
          && (step.selfAssessment == nil || step.revealed)
          && (!step.revealed || activity.kind == .open || activity.kind == .reading
            || step.selection.count == activity.answer.count),
          "La risposta o il confronto nel segnalibro non è valido.")
      }
    }
    for session in archive.sessions + (archive.currentSession.map { [$0] } ?? []) {
      guard let responses = session.programResponses else { continue }
      guard let program = archive.lessons.first(where: { $0.id == session.lessonID })?.program else {
        throw StudioFailure("Le risposte del percorso non hanno una lezione.")
      }
      try require(responses.count <= 40 && Set(responses.map(\.activityID)).count == responses.count,
                  "Le attività registrate sono troppe o ripetute.")
      for response in responses {
        guard let activity = program.activities.first(where: { $0.id == response.activityID }) else {
          throw StudioFailure("Una risposta fa riferimento a un'attività mancante.")
        }
        try require(response.kind == activity.kind && response.text.count <= 5_000
          && response.instruction == activity.instruction && response.reference == activity.reference
          && response.matched == matches(activity, selection: response.selection)
          && response.selection.allSatisfy { id in activity.options.contains { $0.id == id } }
          && Set(response.selection).count == response.selection.count
          && (activity.kind != .open || response.selfAssessment != nil)
          && (activity.kind == .open || response.selfAssessment == nil)
          && (response.matched == nil
            ? response.matchedUnits == nil && response.totalUnits == nil && response.selection.isEmpty
            : response.selection.count == activity.answer.count
              && response.totalUnits == activity.answer.count
              && response.matchedUnits == zip(response.selection, activity.answer).filter { $0 == $1 }.count)
          && (-62_135_596_800...253_402_300_799).contains(response.date.timeIntervalSince1970),
          "Risposta del percorso non valida: confronto automatico e autovalutazione restano distinti.")
      }
    }
  }
}

extension StudioStore {
  @discardableResult
  func updateProgramLoad(_ load: StudioProgramLoad) -> Bool {
    change { archive in
      let catalog = try StudioProgramCatalog.lessons(load: load)
      let visited = Set(archive.sessions.map(\.lessonID)
        + (archive.currentSession.map { [$0.lessonID] } ?? [])
        + (archive.guidedRun.map { [$0.lessonID] } ?? [])
        + StudioPathEngine.path(in: archive).completedIDs)
      var count = 0
      for index in archive.lessons.indices where !visited.contains(archive.lessons[index].id) {
        guard let key = archive.lessons[index].program?.catalogID,
              let updated = catalog.first(where: { $0.program?.catalogID == key })?.program else { continue }
        let old = archive.lessons[index].program?.load
        let changes = [old?.memory != load.memory, old?.instructions != load.instructions,
                       old?.sentences != load.sentences].filter { $0 }.count
        guard changes <= 1 else {
          throw StudioFailure("Cambia una sola richiesta alla volta: elementi, consegne oppure frasi.")
        }
        archive.lessons[index].program = updated
        count += 1
      }
      guard count > 0 else {
        throw StudioFailure("Non ci sono incontri ancora da iniziare. Quelli già aperti conservano carico e risposte.")
      }
    }
  }

  @discardableResult
  func installProgram(load: StudioProgramLoad, activate: Bool) -> Bool {
    change { archive in
      let catalog = try StudioProgramCatalog.lessons(load: load)
      let existing = Set(archive.lessons.compactMap { $0.program?.catalogID })
      let added = catalog.filter { !existing.contains($0.program?.catalogID ?? "") }
      guard archive.lessons.count + added.count <= StudioLimits.lessons else {
        throw StudioFailure("Servono \(added.count) posti liberi per gli incontri. Esporta le lezioni che vuoi conservare prima di liberare spazio.")
      }
      var path = StudioPathEngine.path(in: archive)
      archive.lessons.append(contentsOf: added)
      let ids = catalog.compactMap { item in
        archive.lessons.first { $0.program?.catalogID == item.program?.catalogID }?.id
      }
      if activate {
        guard archive.guidedRun == nil && archive.currentSession == nil
          && (archive.reviewRun?.remaining.isEmpty ?? true) else {
          throw StudioFailure("C'è un incontro in pausa. Concludilo prima di cambiare il prossimo passo; puoi intanto aggiungere il programma in fondo.")
        }
        path.lessonIDs = ids + path.lessonIDs.filter { !ids.contains($0) }
      } else {
        path.lessonIDs += ids.filter { !path.lessonIDs.contains($0) }
      }
      archive.path = path
    }
  }

  @discardableResult
  func revealProgramStep() -> Bool {
    change { archive in
      guard let run = archive.guidedRun, var step = run.programStep,
            let program = archive.lessons.first(where: { $0.id == run.lessonID })?.program,
            program.activities.indices.contains(step.position) else {
        throw StudioFailure("Non c'è un'attività aperta.")
      }
      let activity = program.activities[step.position]
      if activity.kind == .choice || activity.kind == .sequence {
        guard step.selection.count == activity.answer.count else {
          throw StudioFailure("Scegli \(activity.answer.count) \(activity.answer.count == 1 ? "risposta" : "elementi") prima del confronto.")
        }
      }
      step.revealed = true
      archive.guidedRun?.programStep = step
    }
  }

  @discardableResult
  func advanceProgramStep(now: Date = Date()) -> Bool {
    change { archive in
      guard let run = archive.guidedRun, let step = run.programStep,
            let program = archive.lessons.first(where: { $0.id == run.lessonID })?.program,
            program.activities.indices.contains(step.position),
            archive.currentSession?.lessonID == run.lessonID else {
        throw StudioFailure("Riprendi l'incontro prima di continuare.")
      }
      let activity = program.activities[step.position]
      let response = try StudioProgramEngine.response(activity, step: step, now: now)
      var responses = archive.currentSession?.programResponses ?? []
      guard !responses.contains(where: { $0.activityID == activity.id }) else {
        throw StudioFailure("Questo passo è già registrato. Riprendi il prossimo.")
      }
      responses.append(response)
      archive.currentSession?.programResponses = responses
      if step.position + 1 < program.activities.count {
        archive.guidedRun?.programStep = StudioProgramStep(position: step.position + 1)
      } else {
        archive.guidedRun?.programStep = nil
        archive.guidedRun?.phase = .finished
      }
    }
  }
}
