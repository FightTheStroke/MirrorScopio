import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@MainActor
@Suite("Preparazione locale: struttura, fonti e consenso del genitore")
struct StudioGenerationTests {
  private func proposal(source: String = "L'acqua evapora. Il vapore si condensa.") -> StudioGenerationDraft {
    StudioGenerationDraft(
      input: StudioGenerationInput(topic: "Il ciclo dell'acqua", subject: "Scienze", source: source),
      content: StudioGeneratedLesson(explanation: "L'acqua evapora. Il vapore si condensa.",
        ideas: ["Acqua", "Vapore", "Condensa"], connection: "L'acqua cambia forma.",
        procedures: ["Descrivi il passaggio."]),
      cards: [
        StudioGeneratedCard(question: "Che cosa evapora?", answer: "L'acqua.", hint: "Pensa all'acqua.",
                            segmentNumber: 1, quote: "L'acqua evapora."),
        StudioGeneratedCard(question: "Che cosa fa il vapore?", answer: "Si condensa.", hint: "",
                            segmentNumber: 2, quote: "Il vapore si condensa.")
      ])
  }

  @Test("Solo argomento: provenienza sintetica visibile e riferimenti al testo davvero salvato")
  func topicOnly() throws {
    let draft = proposal(source: "")
    try draft.validate()
    #expect(draft.provenance == StudioGenerationValidation.syntheticLabel)
    let approved = try draft.prepareApproval()
    #expect(approved.lesson.source.hasPrefix(StudioGenerationValidation.syntheticLabel))
    #expect(approved.lesson.source.contains(draft.content.explanation))
    #expect(approved.lesson.map.connection.contains(StudioGenerationValidation.syntheticLabel))
    for (generated, card) in zip(draft.cards, approved.cards) {
      let segment = try #require(approved.lesson.segments.first { $0.id == card.segmentID })
      #expect(segment.text.contains(generated.quote))
      #expect(card.approved)
    }
    var archive = StudioArchive()
    try approved.insert(into: &archive)
    #expect(try StudioCodec.decode(StudioCodec.encode(archive)) == archive)
  }

  @Test("Fonte conservata identica, spiegazione nella mappa, spunti nelle risposte")
  func originalSource() throws {
    let draft = proposal(source: "L'acqua evapora. Il vapore si condensa.\n\n")
    let approved = try draft.prepareApproval()
    #expect(approved.lesson.source == draft.input.source)
    #expect(approved.lesson.segments.map(\.text).joined() == draft.input.source)
    #expect(approved.lesson.map.ideas == draft.content.ideas)
    #expect(approved.lesson.map.connection.contains(draft.content.explanation))
    #expect(approved.lesson.procedures.map(\.text) == draft.content.procedures)
    #expect(approved.cards[0].answer.contains("Spunto: Pensa all'acqua."))
    #expect(approved.cards[1].answer == draft.cards[1].answer)
    #expect(draft.provenance == StudioGenerationValidation.sourceLabel)
  }

  @Test("Citazioni inventate, parti inesistenti e riferimenti spostati vengono rifiutati")
  func malformedGrounding() {
    for number in [0, -1, Int.min, Int.max, 3] {
      var draft = proposal()
      draft.cards[0].segmentNumber = number
      #expect(throws: StudioFailure.self) { try draft.validate() }
    }
    for quote in ["", " \n ", "L'acqua congela.", "l'acqua evapora.", "evapora. Il vapore"] {
      var draft = proposal()
      draft.cards[0].quote = quote
      #expect(throws: StudioFailure.self) { try draft.prepareApproval() }
    }
    var moved = proposal()
    moved.cards[0].segmentNumber = 2
    #expect(throws: StudioFailure.self) { try moved.validate() }
  }

  @Test("Una modifica della spiegazione sintetica richiede riferimenti ancora validi")
  func changedExplanation() throws {
    var draft = proposal(source: "")
    draft.content.explanation = "Le foglie ricevono luce."
    #expect(throws: StudioFailure.self) { try draft.validate() }
    draft.content.explanation = "L'acqua evapora. Il vapore si condensa."
    try draft.validate()
  }

  @Test("Limiti espliciti, senza tagli, anche con caratteri composti")
  func inputBounds() throws {
    var input = StudioGenerationInput(topic: "Acqua")
    try input.validate()
    input.topic = " \n "
    #expect(throws: StudioFailure.self) { try input.validate() }
    input.topic = String(repeating: "a", count: 201)
    #expect(throws: StudioFailure.self) { try input.validate() }
    input.topic = "Acqua"
    input.source = String(repeating: "a", count: StudioGenerationInput.sourceLimit)
    try input.validate()
    let original = input.source + "a"
    input.source = original
    #expect(throws: StudioFailure.self) { try input.validate() }
    #expect(input.source == original)
    input.source = String(repeating: "a\u{0301}", count: 1_800)
    #expect(input.source.count < StudioGenerationInput.sourceLimit)
    #expect(throws: StudioFailure.self) { try input.validate() }
    input.source = String(repeating: ".", count: 41)
    #expect(throws: StudioFailure.self) { try input.validate() }
  }

  @Test("Struttura incompleta o risposte vuote non diventano carte approvate")
  func malformedStructure() {
    var draft = proposal()
    draft.content.ideas.removeLast()
    #expect(throws: StudioFailure.self) { try draft.validate() }
    draft = proposal()
    draft.cards.removeLast()
    #expect(throws: StudioFailure.self) { try draft.validate() }
    draft = proposal()
    draft.cards[0].answer = " \n"
    #expect(throws: StudioFailure.self) { try draft.validate() }
    draft = proposal()
    draft.cards[1].question = draft.cards[0].question
    #expect(throws: StudioFailure.self) { try draft.validate() }
    draft = proposal()
    draft.content.explanation = String(repeating: "a", count: 1_401)
    #expect(throws: StudioFailure.self) { try draft.validate() }
  }

  @Test("Validare la struttura non certifica la correttezza della risposta")
  func noAccuracyClaim() throws {
    var draft = proposal()
    draft.cards[0].answer = "Una risposta da correggere dal genitore."
    try draft.validate()
    #expect(draft.provenance.contains("non prova l'accuratezza"))
  }

  @Test("Un risultato tardivo dopo annullamento o nuova richiesta non può essere pubblicato")
  func cancellationTokens() {
    var run = StudioGenerationRun()
    let first = run.begin()
    #expect(run.accepts(first))
    run.cancel()
    #expect(!run.accepts(first))
    let second = run.begin()
    #expect(!run.accepts(first) && run.accepts(second))
    let third = run.begin()
    #expect(!run.accepts(second) && run.accepts(third))
  }

  @Test("Inserimento completo o nulla, anche se l'archivio è pieno")
  func atomicValidation() throws {
    let prepared = try proposal().prepareApproval()
    var archive = StudioArchive()
    archive.lessons = try (0..<StudioLimits.lessons).map { _ in
      try StudioLesson(title: "Lezione", subject: "", source: "Testo.")
    }
    let before = archive
    #expect(throws: StudioFailure.self) { try prepared.insert(into: &archive) }
    #expect(archive == before)
    archive = StudioArchive()
    try prepared.insert(into: &archive)
    let once = archive
    #expect(throws: StudioFailure.self) { try prepared.insert(into: &archive) }
    #expect(archive == once)
  }

  @Test("L'anteprima non scrive; conferma e riprova non duplicano e notificano solo dopo il salvataggio")
  func consentAndPersistence() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-generazione-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    var failing = true
    var writes = 0
    let store = StudioStore(folder: folder) { data, url in
      writes += 1
      if failing { throw StudioFailure("Disco non disponibile nella prova.") }
      try StudioStore.atomicWrite(data, url)
    }
    let generator = StudioGeneration()
    generator.draft = proposal()
    #expect(writes == 0)
    #expect(store.archive.lessons.isEmpty && store.archive.cards.isEmpty)
    #expect(generator.takeApprovedID(in: store) == nil)
    #expect(!generator.approve(in: store))
    #expect(writes == 1 && store.hasPendingSave)
    #expect(store.archive.lessons.isEmpty && store.archive.cards.isEmpty)
    #expect(generator.takeApprovedID(in: store) == nil)
    #expect(!generator.approve(in: store))
    #expect(writes == 1)
    failing = false
    generator.retryApproval(in: store)
    let id = try #require(generator.takeApprovedID(in: store))
    #expect(generator.takeApprovedID(in: store) == nil)
    #expect(writes == 2 && store.archive.lessons.count == 1 && store.archive.cards.count == 2)
    #expect(store.archive.lessons[0].id == id)
    #expect(StudioStore(folder: folder).archive == store.archive)
    #expect(store.archive.path?.lessonIDs == [id])
  }

  @Test("Annullare una proposta non scrive né modifica la bozza importata")
  func cancelWithoutAI() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-annulla-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = StudioStore(folder: folder)
    #expect(store.change { $0.draft.source = "Testo importato." })
    let before = store.archive
    let generator = StudioGeneration()
    generator.draft = proposal()
    generator.cancel()
    generator.reviseInput()
    #expect(generator.draft == nil && !generator.busy)
    #expect(store.archive == before)
  }

  @Test("Generazione reale sul dispositivo e consenso", .serialized, .enabled(
    if: ProcessInfo.processInfo.environment["MIRRORSCOPIO_TEST_AI"] == "1"),
    arguments: [false, true])
  func realGeneration(withSource: Bool) async throws {
    #expect(StudioGeneration.unavailableMessage == nil)
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-ai-reale-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = StudioStore(folder: folder)
    let generator = StudioGeneration()
    let source = withSource
      ? "L'acqua evapora con il calore. Il vapore si condensa formando gocce. La pioggia riporta l'acqua a terra."
      : ""
    generator.start(StudioGenerationInput(topic: "Il ciclo dell'acqua", subject: "Scienze", source: source))
    let deadline = ContinuousClock.now.advanced(by: .seconds(180))
    while generator.busy && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(250))
    }
    if generator.busy { generator.cancel(); Issue.record("Il modello non ha concluso entro tre minuti.") }
    let draft = try #require(generator.draft, "\(generator.message ?? "Nessuna proposta")")
    try draft.validate()
    #expect(store.archive.lessons.isEmpty && store.archive.cards.isEmpty)
    #expect(generator.approve(in: store))
    #expect(generator.takeApprovedID(in: store) != nil)
    #expect(store.archive.cards.count >= 2)
    if withSource { #expect(store.archive.lessons[0].source == source) }
    #expect(StudioStore(folder: folder).archive == store.archive)
  }
}
