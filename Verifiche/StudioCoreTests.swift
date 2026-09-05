import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@MainActor
@Suite("Studio locale: dati, ripasso e misure descrittive")
struct StudioCoreTests {
  func temporary(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("studio-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory)
  }

  func lesson() throws -> StudioLesson {
    try StudioLesson(title: "Il ciclo dell'acqua", subject: "Scienze",
                     source: "L'acqua evapora. Poi si condensa!\nLa pioggia torna a terra.")
  }

  @Test("Segmentazione senza perdita di spazi, accenti e caratteri composti")
  func segmentation() throws {
    let source = "  Perché? Caffè e citta\u{0300}.\n\nL’acqua! 👨‍👩‍👧 Un'altra frase lunga senza punto"
    let segments = try StudioSegmenter.split(source, limit: 12)
    #expect(segments.joined() == source)
    #expect(segments.allSatisfy { !$0.isEmpty && $0.count <= 12 })
    #expect(throws: StudioFailure.self) { try StudioSegmenter.split("testo", limit: 0) }
    #expect(throws: StudioFailure.self) { try StudioSegmenter.split(" \n ") }
    #expect(throws: StudioFailure.self) { try StudioSegmenter.split(String(repeating: "à", count: StudioLimits.text + 1)) }
    let exact = String(repeating: "è", count: StudioLimits.text)
    #expect(try StudioSegmenter.split(exact).joined() == exact)
  }

  @Test("Salvataggio atomico e ripresa conservano testo, posizione, strumenti e bozze")
  func roundTrip() throws {
    try temporary { directory in
      let store = StudioStore(folder: directory)
      var lesson = try lesson()
      lesson.position = 1
      lesson.map.ideas = ["Acqua", "Vapore", "Pioggia"]
      lesson.map.connection = "L'acqua cambia forma."
      lesson.procedures = [StudioProcedure(text: "Descrivo il cambiamento.")]
      #expect(store.change {
        $0.lessons.append(lesson)
        $0.draft = StudioLessonDraft(title: "La prossima", subject: "", source: "Una bozza.")
        $0.cardDraft = StudioCardDraft(lessonID: lesson.id, segmentID: lesson.segments[0].id,
                                     question: "Che cosa evapora?", answer: "L'acqua.")
      })
      let reopened = StudioStore(folder: directory)
      #expect(reopened.archive == store.archive)
      #expect(reopened.fileURL.path.contains("/Studio/studio.json"))
      #expect(try reopened.fileURL.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
  }

  @Test("Corruzione e schema futuro non vengono sovrascritti")
  func recoveryPreservesOriginal() throws {
    for contents in ["{rotto", "{\"version\":99}", "{\"version\":1}"] {
      try temporary { directory in
        let studio = directory.appendingPathComponent("Studio")
        try FileManager.default.createDirectory(at: studio, withIntermediateDirectories: true)
        let url = studio.appendingPathComponent("studio.json")
        let original = Data(contents.utf8)
        try original.write(to: url)
        let store = StudioStore(folder: directory)
        #expect(store.recovery)
        #expect(store.error != nil)
        #expect(!store.change { $0.settings.largeText = true })
        store.retry()
        #expect(try StudioStore.readFile(url) == original)
        let valid = try StudioCodec.encode(StudioArchive())
        #expect(store.replace(with: valid))
        #expect(!store.recovery)
        let names = try FileManager.default.contentsOfDirectory(atPath: studio.path)
        let backup = try #require(names.first { $0.hasPrefix("prima-del-ripristino-") })
        #expect(try StudioStore.readFile(studio.appendingPathComponent(backup)) == original)
      }
    }
  }

  @Test("Scrittura fallita: memoria e disco precedenti intatti, modifica ritentabile")
  func rollback() throws {
    try temporary { directory in
      var fail = false
      let store = StudioStore(folder: directory) { data, url in
        if fail { throw StudioFailure("Disco non disponibile nella prova.") }
        try StudioStore.atomicWrite(data, url)
      }
      let lesson = try lesson()
      #expect(store.change { $0.lessons.append(lesson) })
      let previous = store.archive
      let bytes = try StudioStore.readFile(store.fileURL)
      fail = true
      #expect(!store.editLesson(lesson.id) { $0.position = 1 })
      #expect(store.archive == previous)
      #expect(try StudioStore.readFile(store.fileURL) == bytes)
      #expect(store.hasPendingSave && store.error != nil)
      #expect(!store.change { $0.settings.largeText = true })
      fail = false
      store.retry()
      #expect(store.archive.lessons[0].position == 1)
      #expect(!store.hasPendingSave && store.error == nil)
      #expect(StudioStore(folder: directory).archive == store.archive)
    }
  }

  @Test("Calendario deterministico: 1, 3, 7, 14, 30 giorni, con aiuti dichiarati")
  func schedule() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let intervals = StudioSchedule.defaults
    for (stage, delay) in intervals.enumerated() {
      let result = StudioSchedule.next(stage: stage, recall: .remembered, help: .none,
                                       intervals: intervals, now: now)
      #expect(result.stage == min(stage + 1, 4))
      #expect(result.due == now.addingTimeInterval(Double(delay) * 86_400))
    }
    for help in StudioHelp.allCases {
      let result = StudioSchedule.next(stage: 3, recall: .remembered, help: help,
                                       intervals: intervals, now: now)
      #expect(result.stage == (help == .none ? 4 : 3))
    }
    let again = StudioSchedule.next(stage: 4, recall: .again, help: .adult, intervals: intervals, now: now)
    #expect(again.stage == 0)
    #expect(again.due == now.addingTimeInterval(86_400))
    let helped = StudioSchedule.next(stage: 3, recall: .helped, help: .map, intervals: intervals, now: now)
    #expect(helped.stage == 2)
    #expect(helped.due == now.addingTimeInterval(7 * 86_400))
    #expect(StudioHelp.map.adding(.procedure) == .several)
    #expect(StudioHelp.adult.adding(.map) == .several)
  }

  @Test("Le battute non riscrivono l'archivio; cambio schermata e riprova conservano la bozza")
  func stagedEdits() throws {
    try temporary { directory in
      var writes = 0
      var fail = false
      let store = StudioStore(folder: directory) { data, url in
        if fail { throw StudioFailure("Disco non disponibile nella prova.") }
        writes += 1
        try StudioStore.atomicWrite(data, url)
      }
      for length in 1...100 {
        store.stage { $0.draft.source = String(repeating: "a", count: length) }
      }
      #expect(writes == 0)
      #expect(store.archive.draft.source.isEmpty)
      #expect(store.displayArchive.draft.source.count == 100)
      #expect(store.flushStaged())
      #expect(writes == 1 && store.archive.draft.source.count == 100)
      store.stage { $0.draft.title = "Bozza conservata" }
      #expect(store.change { $0.settings.largeText = true })
      #expect(store.archive.draft.title == "Bozza conservata" && store.staged == nil)
      store.stage { $0.draft.subject = "Scienze" }
      fail = true
      #expect(!store.flushStaged())
      #expect(store.archive.draft.subject.isEmpty)
      #expect(store.displayArchive.draft.subject == "Scienze" && store.hasPendingSave)
      fail = false
      store.retry()
      #expect(StudioStore(folder: directory).archive.draft.subject == "Scienze")
    }
  }

  @Test("Un checkpoint non salvato ferma il tempo e conserva la pausa nel tentativo di scrittura")
  func failedCheckpoint() throws {
    try temporary { directory in
      var fail = false
      var uptime = 100.0
      let now = Date(timeIntervalSince1970: 1_700_000_000)
      let store = StudioStore(folder: directory) { data, url in
        if fail { throw StudioFailure("Disco non disponibile nella prova.") }
        try StudioStore.atomicWrite(data, url)
      }
      let lesson = try lesson()
      #expect(store.change { $0.lessons = [lesson] })
      let tracker = StudioSessionTracker(store: store, uptime: { uptime }, now: { now })
      #expect(tracker.start(lessonID: lesson.id))
      fail = true
      uptime += 10
      tracker.checkpoint()
      #expect(!tracker.active && store.hasPendingSave)
      #expect(store.archive.currentSession?.activeSeconds == 0)
      fail = false
      uptime += 500
      store.retry()
      #expect(store.archive.currentSession?.activeSeconds == 10)
      #expect(store.archive.currentSession?.events.map(\.kind) == [.start, .pause])
    }
  }

  @Test("Ripasso: solo carte approvate e disponibili, ogni carta una volta per giro")
  func dueAndReview() throws {
    try temporary { directory in
      let now = Date(timeIntervalSince1970: 1_700_000_000)
      let store = StudioStore(folder: directory)
      let lesson = try lesson()
      let card = StudioCard(lessonID: lesson.id, segmentID: lesson.segments[0].id,
                            question: "Che cosa evapora?", answer: "L'acqua.", approved: true, due: now)
      var later = card
      later.id = UUID(); later.due = now.addingTimeInterval(1)
      var unapproved = card
      unapproved.id = UUID(); unapproved.approved = false
      #expect(store.change { $0.lessons = [lesson]; $0.cards = [card, later, unapproved] })
      #expect(StudioSchedule.due(in: store.archive, lessonID: lesson.id, now: now).map(\.id) == [card.id])
      #expect(store.beginReview(lessonID: lesson.id, now: now))
      #expect(!store.record(cardID: card.id, text: "", help: .none, recall: .remembered, now: now))
      #expect(store.archive.attempts.isEmpty)
      #expect(store.change { $0.reviewRun?.text = "Il liquido."; $0.reviewRun?.help = .map; $0.reviewRun?.revealed = true })
      #expect(StudioStore(folder: directory).archive.reviewRun == store.archive.reviewRun)
      #expect(store.record(cardID: card.id, text: "Il liquido.", help: .map, recall: .helped, now: now))
      #expect(store.archive.reviewRun?.remaining.isEmpty == true)
      #expect(!store.record(cardID: card.id, text: "Il liquido.", help: .map, recall: .helped, now: now))
      #expect(store.archive.attempts.count == 1)
      let attempt = try #require(store.archive.attempts.first)
      #expect(attempt.question == card.question && attempt.answer == card.answer && attempt.text == "Il liquido.")
      #expect(attempt.help == .map && attempt.recall == .helped && attempt.date == now)
      #expect(attempt.segmentID == card.segmentID)
      #expect(StudioSchedule.due(in: store.archive, lessonID: lesson.id, now: now).isEmpty)
      #expect(store.beginReview(lessonID: lesson.id, now: now))
      #expect(store.archive.reviewRun?.remaining.isEmpty == true)
    }
  }

  @Test("Backup rifiuta duplicati, riferimenti orfani, segmenti e limiti non validi")
  func validatesBackup() throws {
    let lesson = try lesson()
    var archive = StudioArchive()
    archive.lessons = [lesson]
    #expect(try StudioCodec.decode(StudioCodec.encode(archive)) == archive)
    var duplicate = archive
    duplicate.lessons.append(lesson)
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(duplicate) }
    var orphan = archive
    orphan.cards = [StudioCard(lessonID: lesson.id, segmentID: UUID(), question: "Quale?", answer: "Acqua.")]
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(orphan) }
    var badText = archive
    badText.lessons[0].segments[0].text = "Altro testo."
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(badText) }
    var badPosition = archive
    badPosition.lessons[0].position = -1
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(badPosition) }
    var badIntervals = archive
    badIntervals.settings.intervals = [1, 3, 3, 14, 30]
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(badIntervals) }
    var badDuration = archive
    badDuration.currentSession = StudioSession(lessonID: lesson.id, startedAt: Date(), activeSeconds: 1e100)
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(badDuration) }
    var badFatigue = archive
    badFatigue.currentSession = StudioSession(lessonID: lesson.id, startedAt: Date(), fatigue: 6)
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(badFatigue) }
    #expect(throws: StudioFailure.self) { try StudioCodec.decode(Data(repeating: 32, count: StudioLimits.fileBytes + 1)) }
  }

  @Test("Eliminare una lezione elimina tutti e soli i suoi dati collegati")
  func cascade() throws {
    var archive = StudioArchive()
    let first = try lesson()
    let second = try lesson()
    archive.lessons = [first, second]
    let card = StudioCard(lessonID: first.id, segmentID: first.segments[0].id, question: "Quale?", answer: "Acqua.", approved: true)
    archive.cards = [card]
    archive.attempts = [StudioAttempt(cardID: card.id, lessonID: first.id, segmentID: card.segmentID,
      question: card.question, answer: card.answer, text: "", help: .none, recall: .again, date: Date())]
    archive.currentSession = StudioSession(lessonID: first.id, startedAt: Date())
    let date = Date()
    archive.sessions = [
      StudioSession(lessonID: first.id, startedAt: date, endedAt: date, outcome: .interrupted),
      StudioSession(lessonID: second.id, startedAt: date, endedAt: date, outcome: .completed)
    ]
    archive.reviewRun = StudioReviewRun(lessonID: first.id, remaining: [card.id])
    archive.cardDraft = StudioCardDraft(lessonID: first.id, segmentID: card.segmentID)
    archive.deleteLesson(first.id)
    #expect(archive.lessons.map(\.id) == [second.id])
    #expect(archive.cards.isEmpty && archive.attempts.isEmpty && archive.currentSession == nil)
    #expect(archive.sessions.map(\.lessonID) == [second.id])
    #expect(archive.reviewRun == nil && archive.cardDraft.lessonID == nil)
    try StudioCodec.validate(archive)
  }

}
