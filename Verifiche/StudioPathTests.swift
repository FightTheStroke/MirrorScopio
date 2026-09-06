import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@MainActor
@Suite("Percorso: avvio immediato e ripresa persistente")
struct StudioPathTests {
  private func withStore(_ operation: (StudioStore, URL) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("percorso-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try operation(StudioStore(folder: folder), folder)
  }

  @Test("Un archivio precedente resta leggibile senza percorso")
  func migration() throws {
    var archive = StudioArchive()
    archive.lessons = [try StudioPathEngine.example().0]
    let data = try StudioCodec.encode(archive)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["path"] == nil)
    #expect(json["guidedRun"] == nil)
    let decoded = try StudioCodec.decode(data)
    #expect(decoded == archive)
    #expect(StudioPathEngine.path(in: decoded).lessonIDs == archive.lessons.map(\.id))
  }

  @Test("Primo avvio senza preparazione e ripresa esatta dopo rilancio")
  func startAndResume() throws {
    try withStore { store, folder in
      #expect(store.startGuided())
      #expect(store.archive.lessons.count == 1)
      #expect(store.archive.cards.count == 2)
      #expect(store.advanceGuided())
      #expect(store.archive.lessons[0].position == 1)
      let reopened = StudioStore(folder: folder)
      #expect(reopened.startGuided())
      #expect(reopened.archive.lessons.count == 1)
      #expect(reopened.archive.lessons[0].position == 1)
      #expect(reopened.archive.guidedRun == store.archive.guidedRun)
    }
  }

  @Test("Percorso completo, autovalutazioni e prossimo ripasso")
  func completionAndDue() throws {
    try withStore { store, _ in
      #expect(store.startGuided())
      let future = Date().addingTimeInterval(10)
      for _ in 0..<3 { #expect(store.advanceGuided(now: future)) }
      #expect(store.archive.guidedRun?.phase == .recall)
      #expect(!store.finishGuided())
      for _ in 0..<2 {
        let id = try #require(store.archive.reviewRun?.remaining.first)
        #expect(store.change { $0.reviewRun?.revealed = true })
        #expect(store.record(cardID: id, text: "", help: .source, recall: .helped, now: future))
      }
      #expect(store.advanceGuided())
      #expect(store.finishGuided())
      #expect(store.archive.path?.completedIDs.count == 1)
      #expect(StudioPathEngine.next(in: store.archive, now: future)?.action == "Rivedi")
      let tomorrow = future.addingTimeInterval(86_401)
      #expect(StudioPathEngine.next(in: store.archive, now: tomorrow)?.reviewOnly == true)
      #expect(store.startGuided(now: tomorrow))
      #expect(store.archive.guidedRun?.phase == .recall)
    }
  }

  @Test("L'ordine del genitore precede l'ordine di creazione")
  func orderedPath() throws {
    var archive = StudioArchive()
    let first = try StudioPathEngine.example().0
    let second = try StudioPathEngine.example().0
    archive.lessons = [first, second]
    archive.path = StudioPath(lessonIDs: [second.id, first.id])
    #expect(StudioPathEngine.next(in: archive, now: Date())?.lessonID == second.id)
    archive.path?.completedIDs = [second.id]
    #expect(StudioPathEngine.next(in: archive, now: Date())?.lessonID == first.id)
    archive.currentSession = StudioSession(lessonID: second.id, startedAt: Date())
    #expect(StudioPathEngine.next(in: archive, now: Date())?.lessonID == second.id)
  }

  @Test("Cancellazione e riferimenti errati non lasciano percorsi fantasma")
  func deletionAndValidation() throws {
    try withStore { store, _ in
      #expect(store.startGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      #expect(!store.change { $0.path?.lessonIDs.append(id) })
      #expect(!store.change { $0.path?.completedIDs.append(UUID()) })
      #expect(store.change { $0.deleteLesson(id) })
      #expect(store.archive.guidedRun == nil)
      #expect(store.archive.path?.lessonIDs.isEmpty == true)
      #expect(store.archive.cards.isEmpty)
    }
  }

  @Test("Il percorso riprende un ripasso libero senza perdere il tentativo")
  func preserveReview() throws {
    try withStore { store, _ in
      let (lesson, cards) = try StudioPathEngine.example()
      #expect(store.change {
        $0.lessons.append(lesson)
        $0.cards = cards
        $0.reviewRun = StudioReviewRun(lessonID: lesson.id, remaining: [cards[0].id],
                                     text: "La mia risposta", help: .map, revealed: true)
      })
      let saved = store.archive.reviewRun
      #expect(store.startGuided())
      #expect(store.archive.guidedRun?.phase == .recall)
      #expect(store.archive.reviewRun == saved)
      #expect(store.endReview())
      #expect(store.archive.reviewRun == nil)
      #expect(store.archive.guidedRun?.phase == .finished)
    }
  }

  @Test("Un percorso svuotato con lezioni esistenti ha comunque un passo pronto")
  func emptyPath() throws {
    try withStore { store, _ in
      let lesson = try StudioPathEngine.example().0
      #expect(store.change { $0.lessons = [lesson]; $0.path = StudioPath() })
      #expect(StudioPathEngine.next(in: store.archive, now: Date())?.lessonID == lesson.id)
      #expect(store.startGuided())
      #expect(store.archive.path?.lessonIDs == [lesson.id])
    }
  }

  @Test("Consultare liberamente il testo non sposta il segnalibro guidato")
  func independentBookmark() throws {
    try withStore { store, _ in
      #expect(store.startGuided())
      #expect(store.advanceGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      #expect(store.editLesson(id) { $0.position = 2 })
      #expect(store.archive.guidedRun?.position == 1)
      #expect(!store.change { $0.guidedRun?.position = -1 })
    }
  }

  @Test("Righe vuote conservate nella fonte, mai come passi da leggere")
  func blankLines() throws {
    try withStore { store, _ in
      let lesson = try StudioLesson(title: "Acqua", subject: "", source: "\n\nL'acqua evapora.\n\nIl vapore si condensa.\n\n")
      #expect(store.change { $0.lessons = [lesson] })
      #expect(store.startGuided())
      let first = try #require(store.archive.guidedRun?.position)
      #expect(lesson.segments[first].text == "L'acqua evapora.")
      #expect(store.advanceGuided())
      let second = try #require(store.archive.guidedRun?.position)
      #expect(lesson.segments[second].text == "Il vapore si condensa.")
      #expect(store.previousGuidedPart())
      #expect(store.archive.guidedRun?.position == first)
      #expect(store.advanceGuided())
      #expect(store.advanceGuided())
      #expect(store.archive.guidedRun?.phase == .finished)
      #expect(store.archive.lessons[0].source == lesson.source)
    }
  }

  @Test("Passare dalla lettura alle domande conserva un ripasso iniziato durante la pausa")
  func preserveReviewAfterReading() throws {
    try withStore { store, _ in
      #expect(store.startGuided())
      let lessonID = try #require(store.archive.guidedRun?.lessonID)
      let cardID = try #require(store.archive.cards.first?.id)
      let review = StudioReviewRun(lessonID: lessonID, remaining: [cardID],
                                   text: "Una risposta già pensata", help: .map, revealed: true)
      #expect(store.change { $0.reviewRun = review })
      for _ in 0..<3 { #expect(store.advanceGuided()) }
      #expect(store.archive.guidedRun?.phase == .recall)
      #expect(store.archive.reviewRun == review)
    }
  }
}
