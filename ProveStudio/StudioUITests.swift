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
    #endif
  }

  func testAvvioStudioSenzaMicrofono() {
    XCTAssertTrue(app.buttons["studio.add"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.buttons["studio.adult"].exists)
    XCTAssertFalse(app.buttons["Inizia la calibrazione"].exists)
    fotografia("Studio — primo avvio")
  }

  func testGuidaSpiegaUsoEScelte() {
    premi(app.buttons["studio.help"])
    XCTAssertTrue(app.staticTexts["Come si usa"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Perché questa scelta"].firstMatch.exists)
    fotografia("Studio — guida con motivazioni")
    premi(app.buttons["studio.help.close"])
    XCTAssertTrue(app.buttons["studio.add"].waitForExistence(timeout: 5))
  }

  func testLezioneSiSalvaERestaDopoIlRilancio() {
    creaLezione()
    app.terminate()
    app.launch()
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
    premi(app.buttons["studio.adult"])
    scegli("Area", attuale: "Voce e testo", opzione: "Domande e fonti")
    scegli("Lezione", attuale: "Scegli una lezione", opzione: "Costo e ricavo")
    scrivi(app.textViews["studio.card.question"], "Quando nasce un costo?")
    scrivi(app.textViews["studio.card.answer"], "Quando compriamo una risorsa.")
    premi(app.buttons["studio.card.save"])
    XCTAssertTrue(app.staticTexts["Domanda approvata e disponibile per il ripasso."].exists)
    premi(app.buttons["studio.home"])
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
    return element.value as? String ?? element.label
  }

  private func creaLezione() {
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
