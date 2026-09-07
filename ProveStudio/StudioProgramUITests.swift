import XCTest

@MainActor
final class StudioProgramUITests: XCTestCase {
  private var app: XCUIApplication!
  private var identifier = ""
  private var folder: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("studio-programma-ui-\(identifier)")
  }

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      continueAfterFailure = false
      identifier = UUID().uuidString
      app = XCUIApplication()
      app.launchEnvironment["MIRRORSCOPIO_STUDIO_TEST_ID"] = identifier
      #if os(macOS)
      app.launchEnvironment["MIRRORSCOPIO_CARTELLA_DATI"] = folder.path
      #endif
      app.launchArguments = ["-controllaAggiornamenti", "NO"]
      app.launch()
    }
  }

  override func tearDown() async throws {
    try await MainActor.run {
      app.terminate()
      #if os(macOS)
      if FileManager.default.fileExists(atPath: folder.path) {
        try FileManager.default.removeItem(at: folder)
      }
      #endif
    }
    try await super.tearDown()
  }

  func testAttivazioneSceltaEPausaConSegnalibro() {
    activate()
    press("studio.start")
    XCTAssertTrue(app.descendants(matching: .any)["studio.program.instruction"].waitForExistence(timeout: 10))
    press("studio.program.cover")
    press("studio.program.option.0")
    XCTAssertFalse(app.buttons["studio.program.compare"].isEnabled)
    press("studio.guided.pause")
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["studio.start"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.buttons["studio.start"].label, "Continua")
    press("studio.start")
    XCTAssertFalse(app.staticTexts["studio.program.material"].exists)
    XCTAssertTrue(app.buttons["studio.program.option.0"].exists)
    XCTAssertFalse(app.buttons["studio.program.option.0"].isEnabled)
    press("studio.program.option.1")
    press("studio.program.compare")
    XCTAssertTrue(app.descendants(matching: .any)["studio.program.result"].waitForExistence(timeout: 5))
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Programma — confronto dopo la ripresa"
    image.lifetime = .keepAlways
    add(image)
    press("studio.program.next")
    let instruction = app.descendants(matching: .any)["studio.program.instruction"]
    XCTAssertTrue(testo(instruction).contains("consegne"), testo(instruction))
  }

  #if os(iOS)
  func testProgrammaConTestoDoppio() {
    app.terminate()
    app.launchEnvironment["MIRRORSCOPIO_STUDIO_TEST_SCALA"] = "2"
    app.launch()
    press("studio.shell.settings")
    XCTAssertTrue(app.staticTexts["×2.00"].exists)
    press("studio.settings.close")
    testIncontroInteroAvviaIlSuccessivoSenzaSceltaManuale()
  }
  #endif

  func testIncontroInteroAvviaIlSuccessivoSenzaSceltaManuale() {
    activate()
    press("studio.start")
    // Primo incontro: due sequenze, cinque parti di lettura, tre scelte e sette risposte aperte.
    for _ in 0..<2 {
      press("studio.program.option.0")
      press("studio.program.option.1")
      press("studio.program.compare")
      press("studio.program.next")
    }
    for _ in 0..<5 { press("studio.program.compare") }
    for _ in 0..<3 {
      press("studio.program.option.0")
      press("studio.program.compare")
      press("studio.program.next")
    }
    for _ in 0..<7 {
      press("studio.program.compare")
      XCTAssertFalse(app.buttons["studio.program.next"].isEnabled)
      press("studio.program.self.helped")
      press("studio.program.next")
    }
    XCTAssertTrue(app.descendants(matching: .any)["studio.guided.finished"].waitForExistence(timeout: 10))
    press("studio.guided.finish")
    press("studio.start")
    XCTAssertTrue(app.staticTexts["studio.program.position"].waitForExistence(timeout: 10))
    let position = app.staticTexts["studio.program.position"]
    XCTAssertTrue(testo(position).contains("Incontro 2 di 5"), testo(position))
  }

  private func testo(_ element: XCUIElement) -> String {
    let label = element.label
    return label.isEmpty ? (element.value as? String ?? "") : label
  }

  private func activate() {
    press("studio.parent")
    press("studio.program.prepare")
    XCTAssertTrue(app.buttons["studio.program.activate"].waitForExistence(timeout: 10))
    press("studio.program.activate")
    press("studio.home")
  }

  private func press(_ identifier: String) {
    let element = app.buttons[identifier]
    XCTAssertTrue(element.waitForExistence(timeout: 10), identifier)
    #if os(macOS)
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<14 where !element.isHittable && scroll.exists {
      scroll.scroll(byDeltaX: 0, deltaY: element.frame.midY < scroll.frame.minY ? 300 : -300)
    }
    XCTAssertTrue(element.isHittable, identifier)
    element.click()
    #else
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<14 where !element.isHittable && scroll.exists {
      if element.frame.midY < scroll.frame.minY { scroll.swipeDown() }
      else { scroll.swipeUp() }
    }
    XCTAssertTrue(element.isHittable, identifier)
    element.tap()
    #endif
  }
}
