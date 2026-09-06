import Foundation

struct StudioPath: Codable, Equatable {
  var lessonIDs: [UUID] = []
  var completedIDs: [UUID] = []
}

enum StudioGuidedPhase: String, Codable {
  case reading, recall, finished
}

struct StudioGuidedRun: Codable, Equatable {
  var lessonID: UUID
  var phase: StudioGuidedPhase = .reading
  var position = 0
}

struct StudioNextStep {
  var lessonID: UUID
  var title: String
  var reason: String
  var action: String
  var reviewOnly = false
}

extension StudioLesson {
  var readablePositions: [Int] {
    segments.indices.filter { !segments[$0].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }
}

extension StudioArchive {
  mutating func enrollLesson(_ id: UUID) throws {
    guard lessons.contains(where: { $0.id == id }) else {
      throw StudioFailure("Aggiungi prima la lezione.")
    }
    var value = StudioPathEngine.path(in: self)
    if !value.lessonIDs.contains(id) { value.lessonIDs.append(id) }
    path = value
  }
}

enum StudioPathEngine {
  static func path(in archive: StudioArchive) -> StudioPath {
    archive.path ?? StudioPath(lessonIDs: archive.lessons.map(\.id))
  }

  static func next(in archive: StudioArchive, now: Date) -> StudioNextStep? {
    let path = path(in: archive)
    if let id = archive.guidedRun?.lessonID ?? archive.currentSession?.lessonID,
       let lesson = archive.lessons.first(where: { $0.id == id }) {
      return StudioNextStep(lessonID: id, title: lesson.title,
        reason: "Ripartiamo dal punto che hai lasciato.", action: "Continua")
    }
    if let review = archive.reviewRun, !review.remaining.isEmpty,
       let lesson = archive.lessons.first(where: { $0.id == review.lessonID }) {
      return StudioNextStep(lessonID: lesson.id, title: lesson.title,
        reason: "Riprendiamo la domanda che avevi lasciato.", action: "Continua", reviewOnly: true)
    }
    let lessons = path.lessonIDs.compactMap { id in archive.lessons.first { $0.id == id } }
    if let lesson = lessons.first(where: { !path.completedIDs.contains($0.id) }) {
      return StudioNextStep(lessonID: lesson.id, title: lesson.title,
        reason: "Il prossimo passo è già pronto.", action: "Inizia")
    }
    if let lesson = lessons.first(where: { !StudioSchedule.due(in: archive, lessonID: $0.id, now: now).isEmpty }) {
      return StudioNextStep(lessonID: lesson.id, title: lesson.title,
        reason: "Riprendiamo insieme qualcosa che hai già incontrato.", action: "Ripassa", reviewOnly: true)
    }
    if let lesson = lessons.last {
      return StudioNextStep(lessonID: lesson.id, title: lesson.title,
        reason: "Il percorso è concluso. Puoi fermarti oppure rivedere con calma.", action: "Rivedi")
    }
    if let lesson = archive.lessons.first {
      return StudioNextStep(lessonID: lesson.id, title: lesson.title,
        reason: "Una lezione è pronta da riprendere.", action: "Inizia")
    }
    return nil
  }

  static func validate(_ archive: StudioArchive) throws {
    if let path = archive.path {
      let ids = Set(archive.lessons.map(\.id))
      guard path.lessonIDs.count <= StudioLimits.lessons,
            Set(path.lessonIDs).count == path.lessonIDs.count,
            Set(path.lessonIDs).isSubset(of: ids),
            Set(path.completedIDs).count == path.completedIDs.count,
            Set(path.completedIDs).isSubset(of: ids) else {
        throw StudioFailure("Il percorso contiene lezioni mancanti o ripetute.")
      }
    }
    if let run = archive.guidedRun {
      guard let lesson = archive.lessons.first(where: { $0.id == run.lessonID }),
            lesson.segments.indices.contains(run.position) else {
        throw StudioFailure("La lezione del percorso aperto non è disponibile.")
      }
      if let session = archive.currentSession, session.lessonID != run.lessonID {
        throw StudioFailure("La sessione e il percorso aperto devono riguardare la stessa lezione.")
      }
      if run.phase == .recall {
        guard archive.reviewRun?.lessonID == run.lessonID else {
          throw StudioFailure("Il ripasso non corrisponde al percorso aperto.")
        }
      }
    }
  }

  static func example() throws -> (StudioLesson, [StudioCard]) {
    var lesson = try StudioLesson(title: "Una pausa che aiuta", subject: "Primo passo",
      source: "Quando un compito sembra lungo, puoi dividerlo in piccoli passi. Scegli un passo e tieni vicino ciò che ti serve. Dopo un passo puoi fare una pausa e poi riprendere.")
    lesson.map.ideas = ["Un passo alla volta", "Gli strumenti vicini", "La pausa è permessa"]
    lesson.map.connection = "Divido il compito, preparo gli strumenti e mi fermo quando serve."
    lesson.procedures = [
      StudioProcedure(text: "Guardo quale passo viene adesso."),
      StudioProcedure(text: "Tengo a portata di mano il testo o la mappa."),
      StudioProcedure(text: "Posso fare una pausa e riprendere dallo stesso punto.")
    ]
    let cards = [
      StudioCard(lessonID: lesson.id, segmentID: lesson.segments[0].id,
        question: "Che cosa puoi fare se un compito sembra lungo?",
        answer: "Puoi dividerlo in piccoli passi.", approved: true),
      StudioCard(lessonID: lesson.id, segmentID: lesson.segments[2].id,
        question: "Che cosa puoi fare dopo un passo?",
        answer: "Puoi fare una pausa e poi riprendere.", approved: true)
    ]
    return (lesson, cards)
  }
}

extension StudioStore {
  @discardableResult
  func includeInPath(_ id: UUID) -> Bool {
    change { try $0.enrollLesson(id) }
  }

  @discardableResult
  func startGuided(now: Date = Date()) -> Bool {
    change { archive in
      if archive.guidedRun != nil { return }
      if StudioPathEngine.next(in: archive, now: now) == nil {
        guard archive.lessons.isEmpty else {
          throw StudioFailure("Il genitore può scegliere le lezioni da inserire nel percorso.")
        }
        let (lesson, cards) = try StudioPathEngine.example()
        archive.lessons.append(lesson)
        archive.cards.append(contentsOf: cards)
        archive.path = StudioPath(lessonIDs: [lesson.id])
      }
      guard let next = StudioPathEngine.next(in: archive, now: now) else {
        throw StudioFailure("Non c'è ancora una lezione nel percorso.")
      }
      if StudioPathEngine.path(in: archive).lessonIDs.isEmpty {
        archive.path = StudioPath(lessonIDs: [next.lessonID],
                                 completedIDs: archive.path?.completedIDs ?? [])
      }
      let existing = archive.reviewRun
      if let existing, !existing.remaining.isEmpty, existing.lessonID == next.lessonID {
        archive.guidedRun = StudioGuidedRun(lessonID: next.lessonID, phase: .recall)
      } else if next.reviewOnly {
        let due = StudioSchedule.due(in: archive, lessonID: next.lessonID, now: now)
        archive.reviewRun = StudioReviewRun(lessonID: next.lessonID, remaining: Array(due.prefix(3).map(\.id)))
        archive.guidedRun = StudioGuidedRun(lessonID: next.lessonID, phase: .recall)
      } else {
        if let index = archive.lessons.firstIndex(where: { $0.id == next.lessonID }),
           archive.currentSession?.lessonID != next.lessonID {
          archive.lessons[index].position = 0
        }
        guard let lesson = archive.lessons.first(where: { $0.id == next.lessonID }),
              let position = lesson.readablePositions.first(where: { $0 >= lesson.position })
                ?? lesson.readablePositions.last else {
          throw StudioFailure("Questa lezione non ha una parte leggibile da riprendere.")
        }
        archive.guidedRun = StudioGuidedRun(lessonID: next.lessonID, position: position)
      }
    }
  }

  @discardableResult
  func advanceGuided(now: Date = Date()) -> Bool {
    change { archive in
      guard var run = archive.guidedRun,
            let index = archive.lessons.firstIndex(where: { $0.id == run.lessonID }) else {
        throw StudioFailure("Non c'è un passo aperto da continuare.")
      }
      switch run.phase {
      case .reading:
        if let following = archive.lessons[index].readablePositions.first(where: { $0 > run.position }) {
          run.position = following
          archive.lessons[index].position = run.position
        } else {
          let due = StudioSchedule.due(in: archive, lessonID: run.lessonID, now: now)
          if let existing = archive.reviewRun, !existing.remaining.isEmpty {
            // Il tentativo libero resta intatto, anche se iniziato durante una pausa della guida.
            run.phase = existing.lessonID == run.lessonID ? .recall : .finished
          } else if due.isEmpty {
            run.phase = .finished
          } else {
            archive.reviewRun = StudioReviewRun(lessonID: run.lessonID, remaining: Array(due.prefix(3).map(\.id)))
            run.phase = .recall
          }
        }
      case .recall:
        guard archive.reviewRun?.remaining.isEmpty == true else {
          throw StudioFailure("Confronta la risposta oppure scegli una pausa.")
        }
        run.phase = .finished
      case .finished: break
      }
      archive.guidedRun = run
    }
  }

  @discardableResult
  func finishGuided() -> Bool {
    change {
      guard let run = $0.guidedRun, run.phase == .finished else {
        throw StudioFailure("Il passo non è ancora concluso. Puoi sempre fare una pausa.")
      }
      var path = StudioPathEngine.path(in: $0)
      if path.lessonIDs.contains(run.lessonID), !path.completedIDs.contains(run.lessonID) {
        path.completedIDs.append(run.lessonID)
      }
      $0.path = path
      $0.guidedRun = nil
    }
  }

  @discardableResult
  func endReview() -> Bool {
    change {
      if $0.guidedRun?.phase == .recall {
        $0.guidedRun?.phase = .finished
      }
      $0.reviewRun = nil
    }
  }

  @discardableResult
  func previousGuidedPart() -> Bool {
    change {
      guard let run = $0.guidedRun,
            let lesson = $0.lessons.first(where: { $0.id == run.lessonID }),
            let previous = lesson.readablePositions.last(where: { $0 < run.position }) else {
        throw StudioFailure("Sei già alla prima parte del testo.")
      }
      $0.guidedRun?.position = previous
    }
  }
}
