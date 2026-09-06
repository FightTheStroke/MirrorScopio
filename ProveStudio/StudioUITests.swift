import XCTest

@MainActor
final class StudioUITests: XCTestCase {
  private var app: XCUIApplication!
  private var testID: String!

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
    continueAfterFailure = false
    testID = UUID().uuidString
    app = XCUIApplication()
    app.launchEnvironment["MIRRORSCOPIO_STUDIO_TEST_ID"] = testID
    #if os(macOS)
    app.launchEnvironment["MIRRORSCOPIO_CARTELLA_DATI"] = legacyFolder.path
    #endif
    app.launchArguments = ["-controllaAggiornamenti", "NO"]
    app.launch()
    }
  }

  override func tearDown() async throws {
    try await MainActor.run {
    app.terminate()
    try removeTestArchive()
    }
    try await super.tearDown()
  }

  private func removeTestArchive() throws {
    #if os(macOS)
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: false)
    let folder = base.appendingPathComponent("MirrorScopio/Studio-Prove-\(testID!)")
    if FileManager.default.fileExists(atPath: folder.path) {
      try FileManager.default.removeItem(at: folder)
    }
    if FileManager.default.fileExists(atPath: legacyFolder.path) {
      try FileManager.default.removeItem(at: legacyFolder)
    }
    #endif
  }

  private var legacyFolder: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("studio-interfaccia-\(testID!)")
  }

  func testAvvioStudioSenzaMicrofono() {
    XCTAssertTrue(app.buttons["studio.start"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.buttons["studio.start"].isHittable)
    XCTAssertTrue(app.buttons["studio.parent"].exists)
    XCTAssertFalse(app.buttons["studio.add"].exists)
    XCTAssertFalse(app.buttons["Inizia la calibrazione"].exists)
    XCTAssertTrue(app.buttons["studio.shell.settings"].exists)
    #if os(macOS)
    XCTAssertTrue(app.buttons["studio.mode"].exists)
    XCTAssertTrue(app.buttons["I tuoi progressi"].exists)
    #endif
    fotografia("Studio — primo avvio")
  }

  #if os(macOS)
  func testRitornoDaLeggiAStudio() {
    premi(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Leggi")).firstMatch)
    premi(app.buttons["navigation.back"])
    XCTAssertTrue(app.buttons["studio.start"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["navigation.back"].exists)
  }

  func testImpostazioniOriginaliConStudioNelloStessoElenco() {
    premi(app.buttons["studio.shell.settings"])
    XCTAssertTrue(app.buttons["Colori e luce"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Come si legge"].exists)
    XCTAssertTrue(app.buttons["Ritmo e calma"].exists)
    XCTAssertTrue(app.buttons["I giochi"].exists)
    premi(app.buttons["Studio e percorso"])
    premi(app.buttons["studio.settings.path"])
    XCTAssertTrue(app.buttons["studio.ai.open"].exists)
    fotografia("Studio — dentro le impostazioni originali")
  }

  func testImpostazioniNonPerdonoLaBozza() {
    premi(app.buttons["studio.parent"])
    premi(app.buttons["studio.ai.open"])
    let argomento = app.textFields["studio.ai.topic"]
    scrivi(argomento, "Le frazioni")
    premi(app.buttons["studio.shell.settings"])
    premi(app.buttons["Chiudi impostazioni"])
    XCTAssertTrue(argomento.waitForExistence(timeout: 5))
    XCTAssertEqual(argomento.value as? String, "Le frazioni")
  }
  #endif

  #if os(iOS)
  func testIstruzioniConTestoDoppio() {
    app.terminate()
    app.launchEnvironment["MIRRORSCOPIO_STUDIO_TEST_SCALA"] = "2"
    app.launch()
    premi(app.buttons["studio.shell.settings"])
    XCTAssertTrue(app.staticTexts["×2.00"].exists)
    premi(app.buttons["studio.settings.close"])
    testEsempioCompletoSenzaPreparareMateriali()
  }

  func testImpostazioniConCaratteriOriginali() {
    premi(app.buttons["studio.shell.settings"])
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Atkinson")).firstMatch
      .waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "OpenDyslexic")).firstMatch.exists)
    fotografia("Studio — impostazioni e caratteri condivisi")
    premi(app.buttons["studio.settings.close"])
    XCTAssertTrue(app.buttons["studio.start"].waitForExistence(timeout: 5))
  }
  #endif

  func testGuidaSpiegaUsoEScelte() {
    premi(app.buttons["studio.help"])
    XCTAssertTrue(app.staticTexts["Come si usa"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Perché questa scelta"].firstMatch.exists)
    fotografia("Studio — guida con motivazioni")
    premi(app.buttons["studio.help.close"])
    XCTAssertTrue(app.buttons["studio.start"].waitForExistence(timeout: 5))
  }

  func testLezioneSiSalvaERestaDopoIlRilancio() {
    creaLezione()
    app.terminate()
    app.launch()
    premi(app.buttons["studio.library"])
    let savedLesson = app.buttons["studio.openLesson"].firstMatch
    XCTAssertTrue(savedLesson.waitForExistence(timeout: 15))
    XCTAssertEqual(savedLesson.label, "Costo e ricavo")
    premi(savedLesson)
    XCTAssertTrue(app.staticTexts["Un costo nasce quando compriamo una risorsa."].firstMatch
      .waitForExistence(timeout: 5))
    fotografia("Studio — lezione conservata")
  }

  func testMappaFormularioESessioneRestanoDisponibili() {
    creaLezione()
    premi(app.buttons["studio.session.start"])
    premi(app.buttons["studio.map"])
    scrivi(app.textViews.firstMatch, "Il costo riguarda le risorse.")
    premi(app.buttons["studio.back"])
    premi(app.buttons["studio.procedures"])
    premi(app.buttons["Aggiungi un passo"])
    scrivi(app.textViews.firstMatch, "Confronta il costo con il ricavo.")
    premi(app.buttons["studio.back"])
    premi(app.buttons["studio.session.finish"])
    premi(app.buttons["studio.session.completed"])
    XCTAssertTrue(app.staticTexts["Sessione salvata. I tuoi appunti restano qui."].exists)
    app.terminate()
    app.launch()
    premi(app.buttons["studio.library"])
    premi(app.buttons["studio.openLesson"].firstMatch)
    premi(app.buttons["studio.map"])
    XCTAssertEqual(app.textViews.firstMatch.value as? String, "Il costo riguarda le risorse.")
    fotografia("Studio — mappa conservata")
    premi(app.buttons["studio.back"])
    premi(app.buttons["studio.procedures"])
    XCTAssertEqual(app.textViews.firstMatch.value as? String, "Confronta il costo con il ricavo.")
    fotografia("Studio — formulario conservato")
  }

  func testDomandaApprovataSiRipassaConAiuto() {
    creaLezione()
    premi(app.buttons["studio.home"])
    premi(app.buttons["studio.parent"])
    premi(app.buttons["studio.adult"])
    scegli("Area", attuale: "Ripasso", opzione: "Domande e fonti")
    scegli("Lezione", attuale: "Scegli una lezione", opzione: "Costo e ricavo")
    scrivi(app.textViews["studio.card.question"], "Quando nasce un costo?")
    scrivi(app.textViews["studio.card.answer"], "Quando compriamo una risorsa.")
    premi(app.buttons["studio.card.save"])
    XCTAssertTrue(app.staticTexts["Domanda approvata e disponibile per il ripasso."].exists)
    premi(app.buttons["studio.home"])
    premi(app.buttons["studio.library"])
    premi(app.buttons["studio.openLesson"].firstMatch)
    premi(app.buttons["studio.review"])
    premi(app.buttons["studio.review.start"])
    XCTAssertEqual(testo(app.staticTexts["studio.review.question"]), "Quando nasce un costo?")
    premi(app.buttons["studio.map"])
    premi(app.buttons["studio.review"])
    premi(app.buttons["studio.review.reveal"])
    XCTAssertEqual(testo(app.staticTexts["studio.review.model"]), "Quando compriamo una risorsa.")
    fotografia("Studio — risposta di riferimento e fonte")
    premi(app.buttons["Con aiuto"])
    XCTAssertTrue(app.staticTexts[
      "Per ora non ci sono domande da riprendere. Puoi sempre usare testo, mappa e formulario."
    ].waitForExistence(timeout: 5))
  }

  private func scegli(_ label: String, attuale: String, opzione: String) {
    #if os(macOS)
    premi(app.popUpButtons.matching(NSPredicate(
      format: "label CONTAINS %@ OR value CONTAINS %@", label, attuale)).firstMatch)
    premi(app.menuItems[opzione])
    #else
    premi(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", attuale)).firstMatch)
    premi(app.buttons[opzione])
    #endif
  }

  private func testo(_ element: XCUIElement) -> String {
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    #if os(macOS)
    return element.value as? String ?? element.label
    #else
    return element.label
    #endif
  }

  private func creaLezione() {
    premi(app.buttons["studio.parent"])
    premi(app.buttons["studio.add"])
    let title = app.textFields["studio.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    premi(title)
    title.typeText("Costo e ricavo")
    attendiTesto("Costo e ricavo", in: title)
    let subject = app.textFields["studio.subject"]
    premi(subject)
    subject.typeText("Economia aziendale")
    let source = app.textViews["studio.source"]
    XCTAssertTrue(source.exists)
    scrivi(source, "Un costo nasce quando compriamo una risorsa. Un ricavo nasce dalla vendita.")
    fotografia("Studio — testo prima del salvataggio")
    premi(app.buttons["studio.save"])
    let heading = app.descendants(matching: .any).matching(identifier: "studio.lesson.title").firstMatch
    XCTAssertTrue(heading.waitForExistence(timeout: 10))
    XCTAssertEqual(heading.label, "Costo e ricavo")
  }

  func testUnSoloToccoAvviaERiprendeDalloStessoPunto() {
    premi(app.buttons["studio.start"])
    XCTAssertEqual(testo(app.staticTexts["studio.guided.text"]),
      "Quando un compito sembra lungo, puoi dividerlo in piccoli passi.")
    premi(app.buttons["studio.guided.next"])
    let second = "Scegli un passo e tieni vicino ciò che ti serve."
    XCTAssertEqual(testo(app.staticTexts["studio.guided.text"]), second)
    premi(app.buttons["studio.guided.pause"])
    app.terminate()
    app.launch()
    XCTAssertEqual(app.buttons["studio.start"].label, "Continua")
    premi(app.buttons["studio.start"])
    XCTAssertEqual(testo(app.staticTexts["studio.guided.text"]), second)
    fotografia("Percorso — riprende senza cercare la lezione")
  }

  func testEsempioCompletoSenzaPreparareMateriali() {
    premi(app.buttons["studio.start"])
    XCTAssertTrue(app.staticTexts["studio.instructions.reading"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["studio.instructions.reading"].isHittable)
    XCTAssertTrue(app.buttons["studio.instructions.listen"].exists)
    fotografia("Primi passi — leggi o ascolta")
    for _ in 0..<3 { premi(app.buttons["studio.guided.next"]) }
    for index in 0..<2 {
      XCTAssertTrue(app.staticTexts["studio.guided.question"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["studio.instructions.recall"].exists)
      XCTAssertTrue(app.staticTexts["studio.instructions.recall"].isHittable)
      if index == 0 { fotografia("Primi passi — rispondi a voce") }
      premi(app.buttons["studio.guided.reveal"])
      XCTAssertTrue(app.staticTexts["studio.guided.answer"].exists)
      XCTAssertTrue(app.staticTexts["studio.instructions.comparison"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["studio.instructions.comparison"].isHittable)
      XCTAssertEqual(app.buttons["studio.guided.helped"].label, "Con aiuto: ho usato un aiuto")
      if index == 0 { fotografia("Primi passi — scegli come è andata") }
      premi(app.buttons["studio.guided.helped"])
    }
    XCTAssertTrue(app.descendants(matching: .any)["studio.guided.finished"].exists)
    fotografia("Percorso — un passo fatto senza voti")
    premi(app.buttons["studio.guided.finish"])
    XCTAssertEqual(app.buttons["studio.start"].label, "Rivedi")
  }

  func testGenitoreTrovaPreparazioneAIENonLaMostraAlRagazzo() {
    XCTAssertFalse(app.buttons["studio.ai.open"].exists)
    premi(app.buttons["studio.parent"])
    XCTAssertTrue(app.staticTexts["studio.instructions.parent"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["studio.ai.open"].exists)
    premi(app.buttons["studio.ai.open"])
    fotografia("Percorso — preparazione locale per il genitore")
    XCTAssertFalse(app.buttons["studio.start"].exists)
    premi(app.buttons["studio.home"])
    premi(app.buttons["studio.start"])
    XCTAssertTrue(app.staticTexts["studio.guided.text"].waitForExistence(timeout: 5))
  }

  private func scrivi(_ editor: XCUIElement, _ text: String) {
    premi(editor)
    editor.typeText(text)
    attendiTesto(text, in: editor)
    #if os(iOS)
    premi(app.buttons["studio.keyboard.done"])
    #endif
  }

  private func attendiTesto(_ text: String, in element: XCUIElement) {
    let written = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", text), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 3), .completed)
    XCTAssertEqual(element.value as? String, text)
  }

  private func premi(_ element: XCUIElement) {
    XCTAssertTrue(element.waitForExistence(timeout: 10))
    #if os(macOS)
    element.click()
    #else
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<8 where !element.isHittable && scroll.exists {
      if element.frame.midY < scroll.frame.minY { scroll.swipeDown() }
      else { scroll.swipeUp() }
    }
    XCTAssertTrue(element.isHittable)
    element.tap()
    #endif
  }

  private func fotografia(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
