import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@MainActor
@Suite("Programma Studio: quaranta incontri, aiuti e segnalibri")
struct StudioProgramTests {
  private func withStore(_ operation: (StudioStore, URL) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-programma-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try operation(StudioStore(folder: folder), folder)
  }

  @Test("Otto tappe per cinque incontri con testi originali distinti e quattro blocchi")
  func catalog() throws {
    let lessons = try StudioProgramCatalog.lessons()
    #expect(lessons.count == 40)
    #expect(Set(lessons.map(\.title)).count == 40)
    #expect(Set(lessons.map(\.source)).count == 40)
    #expect(Set(lessons.compactMap { $0.program?.catalogID }).count == 40)
    for stage in 1...8 {
      #expect(lessons.filter { $0.program?.stage == stage }.count == 5)
    }
    for lesson in lessons {
      let program = try #require(lesson.program)
      #expect(Set(program.activities.map(\.block)) == Set(StudioProgramBlock.allCases))
      #expect(program.activities.first?.block == .activation)
      #expect(program.activities.last?.block == .retrieval)
      #expect(program.activities.contains { $0.id.hasSuffix("-scheda") })
      #expect(program.activities.contains { $0.id.hasSuffix("-luogo") })
      #expect(program.activities.contains { $0.id.hasSuffix("-evento") })
      #expect(program.activities.contains { $0.id.hasSuffix("-legame") })
      #expect(program.activities.contains { $0.id.hasSuffix("-poi") })
      #expect(program.activities.contains { $0.id.hasSuffix("-parole") })
      #expect(program.activities.contains { $0.id.hasSuffix("-riassunto") })
    }
    var archive = StudioArchive()
    archive.lessons = lessons
    #expect(try StudioCodec.decode(StudioCodec.encode(archive)) == archive)
  }

  @Test("Ogni risposta chiusa è risolvibile e un ordine diverso non coincide")
  func deterministicAnswers() throws {
    for load in [StudioProgramLoad(), StudioProgramLoad(memory: 4, instructions: 3, sentences: 5)] {
      for lesson in try StudioProgramCatalog.lessons(load: load) {
        for activity in try #require(lesson.program).activities {
          if activity.kind == .open || activity.kind == .reading {
            #expect(activity.answer.isEmpty)
            #expect(StudioProgramEngine.matches(activity, selection: [999]) == nil)
          } else {
            #expect(activity.answer.allSatisfy { id in activity.options.contains { $0.id == id } })
            #expect(StudioProgramEngine.matches(activity, selection: activity.answer) == true)
            #expect(StudioProgramEngine.matches(activity, selection: []) == false)
            if activity.kind == .sequence {
              #expect(StudioProgramEngine.matches(activity, selection: Array(activity.answer.reversed())) == false)
            }
          }
        }
      }
    }
  }

  @Test("Le otto tappe contengono le attività specifiche, non solo carte")
  func educationalCoverage() throws {
    let lessons = try StudioProgramCatalog.lessons(load: StudioProgramLoad(memory: 4, instructions: 3, sentences: 5))
    let required: [Int: [String]] = [
      1: ["chi", "dove", "cosa"], 2: ["idea", "dettaglio"], 3: ["ordine"],
      4: ["calcolo", "causa", "conseguenza"], 5: ["inferenza", "indizio"],
      6: ["ricostruisco", "riassunto"], 7: ["secondo-recupero"],
      8: ["strategia", "titolo", "secondo-recupero"]
    ]
    for lesson in lessons {
      let program = try #require(lesson.program)
      for suffix in required[program.stage] ?? [] {
        #expect(program.activities.contains { $0.id.hasSuffix("-" + suffix) })
      }
      let memory = try #require(program.activities.first)
      if program.stage == 3 { #expect(memory.answer == Array(memory.options.map(\.id).sorted().reversed())) }
      if program.stage == 5 { #expect(memory.answer == [2, 3, 4]) }
    }
  }

  @Test("Gli indizi proposti sono frasi del testo e non dettagli alternativi")
  func evidenceInSource() throws {
    #expect(StudioProgramCatalog.passages.count == 40)
    for passage in StudioProgramCatalog.passages {
      #expect(passage.text.contains(passage.evidence))
      #expect(passage.evidence != passage.detail)
      #expect(!passage.summary.isEmpty)
      #expect(Set(passage.keywords).count == 3)
    }
  }

  @Test("L'installazione è atomica, riutilizzabile e conserva le lezioni manuali")
  func installation() throws {
    try withStore { store, _ in
      let (manual, cards) = try StudioPathEngine.example()
      #expect(store.change { $0.lessons = [manual]; $0.cards = cards })
      #expect(store.installProgram(load: StudioProgramLoad(), activate: false))
      #expect(store.archive.lessons.count == 41)
      #expect(store.archive.path?.lessonIDs.first == manual.id)
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.archive.lessons.count == 41)
      #expect(store.archive.cards == cards)
      #expect(store.archive.lessons.first { $0.id == manual.id } == manual)
      #expect(StudioPathEngine.next(in: store.archive, now: Date())?.title.hasPrefix("1.1") == true)
      let ids = store.archive.path?.lessonIDs
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.archive.path?.lessonIDs == ids)
    }
  }

  @Test("Un'attività in pausa non viene sostituita dall'attivazione")
  func preserveManualBookmark() throws {
    try withStore { store, _ in
      #expect(store.startGuided())
      #expect(store.advanceGuided())
      let before = store.archive
      #expect(!store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.archive == before)
      #expect(store.error != nil)
      #expect(store.installProgram(load: StudioProgramLoad(), activate: false))
      #expect(store.archive.guidedRun == before.guidedRun)
    }
  }

  @Test("Il limite di lezioni rifiuta l'intera aggiunta senza dati parziali")
  func capacity() throws {
    try withStore { store, _ in
      let lessons = try (0..<61).map { _ in try StudioPathEngine.example().0 }
      #expect(store.change { $0.lessons = lessons })
      let before = store.archive
      #expect(!store.installProgram(load: StudioProgramLoad(), activate: false))
      #expect(store.archive == before)
    }
  }

  @Test("Le bozze, la scelta e il testo coperto sopravvivono a pausa e rilancio")
  func bookmarkAndPause() throws {
    try withStore { store, folder in
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.startGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      var time: TimeInterval = 0
      let tracker = StudioSessionTracker(store: store, uptime: { time })
      #expect(tracker.start(lessonID: id))
      #expect(store.change {
        $0.guidedRun?.programStep?.selection = [0]
        $0.guidedRun?.programStep?.hidden = true
        $0.guidedRun?.programStep?.help = .source
      })
      time = 7
      tracker.pause()
      let reopened = StudioStore(folder: folder)
      #expect(reopened.startGuided(now: Date().addingTimeInterval(365 * 86_400)))
      #expect(reopened.archive.guidedRun == store.archive.guidedRun)
      #expect(reopened.archive.currentSession?.activeSeconds == 7)
      #expect(reopened.archive.guidedRun?.phase == .program)
      #expect(reopened.archive.guidedRun?.programStep?.position == 0)
    }
  }

  @Test("L'intero incontro segue i quattro blocchi e porta al successivo, senza calendario")
  func completeEncounter() throws {
    try withStore { store, _ in
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.startGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      let tracker = StudioSessionTracker(store: store)
      #expect(tracker.start(lessonID: id))
      let program = try #require(store.archive.lessons.first(where: { $0.id == id })?.program)
      for (position, activity) in program.activities.enumerated() {
        #expect(store.archive.guidedRun?.programStep?.position == position)
        #expect(!store.advanceProgramStep())
        #expect(store.change {
          $0.guidedRun?.programStep?.selection = activity.answer
          if activity.kind == .open { $0.guidedRun?.programStep?.text = "Le mie parole, non un test automatico." }
        })
        #expect(store.revealProgramStep())
        if activity.kind == .open {
          #expect(!store.advanceProgramStep())
          #expect(store.change { $0.guidedRun?.programStep?.selfAssessment = .helped })
        }
        #expect(store.advanceProgramStep())
      }
      #expect(store.archive.guidedRun?.phase == .finished)
      #expect(store.archive.guidedRun?.programStep == nil)
      #expect(tracker.finish(.completed))
      #expect(store.finishGuided())
      #expect(store.archive.sessions.last?.programResponses?.count == program.activities.count)
      #expect(StudioPathEngine.next(in: store.archive, now: Date())?.title.hasPrefix("1.2") == true)
      #expect(store.startGuided())
      #expect(store.archive.guidedRun?.programStep?.position == 0)
    }
  }

  @Test("Un confronto Ancora non blocca; riprovare resta una scelta con riferimento dichiarato")
  func againIsNotPenalty() throws {
    try withStore { store, _ in
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.startGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      let tracker = StudioSessionTracker(store: store)
      #expect(tracker.start(lessonID: id))
      #expect(store.change { $0.guidedRun?.programStep?.selection = [1, 0] })
      #expect(store.revealProgramStep())
      #expect(store.advanceProgramStep())
      #expect(store.archive.currentSession?.programResponses?.last?.matched == false)
      #expect(store.archive.guidedRun?.programStep?.position == 1)
    }
  }

  @Test("Nessun testo aperto è giudicato corretto, anche se coincide con l'esempio")
  func openSelfReport() throws {
    let lesson = try #require(StudioProgramCatalog.lessons().first)
    let activity = try #require(lesson.program?.activities.first { $0.kind == .open })
    var step = StudioProgramStep(text: activity.reference, revealed: true)
    #expect(throws: StudioFailure.self) { try StudioProgramEngine.response(activity, step: step, now: Date()) }
    step.selfAssessment = .remembered
    let response = try StudioProgramEngine.response(activity, step: step, now: Date())
    #expect(response.matched == nil)
    #expect(response.matchedUnits == nil)
    #expect(response.totalUnits == nil)
    #expect(response.selfAssessment == .remembered)
  }

  @Test("Nuovi campi opzionali: un archivio vecchio resta byte-logicamente compatibile")
  func oldArchive() throws {
    var archive = StudioArchive()
    archive.lessons = [try StudioPathEngine.example().0]
    archive.guidedRun = StudioGuidedRun(lessonID: archive.lessons[0].id)
    archive.currentSession = StudioSession(lessonID: archive.lessons[0].id, startedAt: Date())
    let data = try StudioCodec.encode(archive)
    let json = String(decoding: data, as: UTF8.self)
    #expect(!json.contains("\"program\""))
    #expect(!json.contains("\"programStep\""))
    #expect(!json.contains("\"programResponses\""))
    #expect(try StudioCodec.decode(data) == archive)
  }

  @Test("Importazione ed esportazione conservano il confronto aperto e il carico")
  func transfer() throws {
    try withStore { store, _ in
      #expect(store.installProgram(load: StudioProgramLoad(memory: 3, instructions: 2, sentences: 3), activate: true))
      #expect(store.startGuided())
      #expect(store.change {
        $0.guidedRun?.programStep?.selection = [0, 1, 2]
        $0.guidedRun?.programStep?.help = .adult
        $0.guidedRun?.programStep?.usedReference = true
      })
      #expect(store.revealProgramStep())
      let original = store.archive
      let backup = try StudioCodec.encode(original)
      try withStore { other, _ in
        #expect(other.replace(with: backup))
        #expect(other.archive == original)
        #expect(other.startGuided())
        #expect(other.archive == original)
      }
    }
  }

  @Test("Il carico cambia soltanto su richiesta, un asse alla volta e non sugli incontri aperti")
  func configuredLoad() throws {
    try withStore { store, _ in
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.startGuided())
      let currentID = try #require(store.archive.guidedRun?.lessonID)
      let current = store.archive.lessons.first { $0.id == currentID }
      #expect(!store.updateProgramLoad(StudioProgramLoad(memory: 4, instructions: 3, sentences: 5)))
      #expect(store.updateProgramLoad(StudioProgramLoad(memory: 3, instructions: 2, sentences: 2)))
      #expect(store.archive.lessons.first { $0.id == currentID } == current)
      #expect(store.archive.lessons.filter { $0.id != currentID }.allSatisfy { $0.program?.load.memory == 3 })
      #expect(store.startGuided(now: Date().addingTimeInterval(10_000_000)))
      #expect(store.archive.lessons.first { $0.id == currentID } == current)
    }
  }

  @Test("Dati malformati, segnalibri inesistenti e correttori sulle risposte aperte sono rifiutati")
  func invalidArchive() throws {
    var base = StudioArchive()
    base.lessons = try StudioProgramCatalog.lessons()
    var invalid = base
    invalid.lessons[0].program?.activities[0].answer = [999]
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(invalid) }
    invalid = base
    invalid.lessons[1].program?.catalogID = base.lessons[0].program?.catalogID ?? ""
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(invalid) }
    invalid = base
    invalid.guidedRun = StudioGuidedRun(lessonID: base.lessons[0].id, phase: .program,
      programStep: StudioProgramStep(position: 999))
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(invalid) }
    invalid = base
    let position = try #require(invalid.lessons[0].program?.activities.firstIndex { $0.kind == .open })
    invalid.lessons[0].program?.activities[position].answer = [0]
    #expect(throws: StudioFailure.self) { try StudioCodec.encode(invalid) }
  }

  @Test("Un salvataggio fallito mostra il problema e non finge l'attivazione")
  func failedSave() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-programma-fallimento-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    var fail = true
    let store = StudioStore(folder: folder, writer: { data, url in
      if fail { throw CocoaError(.fileWriteNoPermission) }
      try StudioStore.atomicWrite(data, url)
    })
    #expect(!store.installProgram(load: StudioProgramLoad(), activate: true))
    #expect(store.archive.lessons.isEmpty)
    #expect(store.hasPendingSave)
    #expect(store.error != nil)
    #expect(!store.startGuided())
    fail = false
    store.retry()
    #expect(!store.hasPendingSave)
    #expect(store.archive.lessons.count == 40)
    #expect(StudioStore(folder: folder).archive == store.archive)
  }

  @Test("Cancellare una lezione elimina insieme il suo segnalibro e i suoi dati")
  func deletion() throws {
    try withStore { store, _ in
      #expect(store.installProgram(load: StudioProgramLoad(), activate: true))
      #expect(store.startGuided())
      let id = try #require(store.archive.guidedRun?.lessonID)
      #expect(store.change { $0.deleteLesson(id) })
      #expect(store.archive.guidedRun == nil)
      #expect(store.archive.lessons.count == 39)
      #expect(try StudioCodec.decode(StudioCodec.encode(store.archive)) == store.archive)
    }
  }

  @Test("Il resoconto distingue confronto deterministico e autovalutazione")
  func descriptiveExport() throws {
    var archive = StudioArchive()
    let lesson = try #require(StudioProgramCatalog.lessons().first)
    archive.lessons = [lesson]
    let activities = try #require(lesson.program).activities
    let closed = try #require(activities.first)
    let open = try #require(activities.first { $0.kind == .open })
    let responses = [
      try StudioProgramEngine.response(closed,
        step: StudioProgramStep(selection: closed.answer, help: .source, revealed: true), now: Date()),
      try StudioProgramEngine.response(open,
        step: StudioProgramStep(text: "=testo", revealed: true, selfAssessment: .again), now: Date())
    ]
    archive.sessions = [StudioSession(lessonID: lesson.id, startedAt: Date(), endedAt: Date(),
      outcome: .completed, programResponses: responses)]
    let csv = String(decoding: StudioReport.csv(archive), as: UTF8.self)
    #expect(csv.contains("confronto deterministico"))
    #expect(csv.contains("Autovalutazione: Ancora"))
    #expect(csv.contains("'=testo"))
    #expect(try StudioCodec.decode(StudioCodec.encode(archive)) == archive)
  }
}
