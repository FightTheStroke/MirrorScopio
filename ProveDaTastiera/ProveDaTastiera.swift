import XCTest

/// Le prove che aprono MirrorScopio davvero e lo usano **senza mouse**.
///
/// Perché queste esistono. Per settimane ho scritto che l'app era usabile da
/// tastiera e che le etichette erano a posto: era vero solo nel senso che
/// avevo letto il codice. Nessuno aveva mai attraversato l'app premendo solo
/// Tab e Invio, e nessuno aveva mai ascoltato che cosa avrebbe letto VoiceOver.
/// Una promessa di accessibilità controllata a occhio non è una promessa.
///
/// Il punto tecnico che rende tutto questo possibile: XCUITest non guarda i
/// pixel, legge **l'albero di accessibilità** — la stessa identica struttura
/// che VoiceOver pronuncia ad alta voce. Quindi «ogni comando ha un nome» qui
/// non è una metafora: se una prova qui sotto fallisce, c'è un pulsante che
/// VoiceOver annuncerebbe come «pulsante» e basta, lasciando la persona a
/// indovinare.
///
/// Queste prove girano a ogni push, per sempre. È la differenza fra aver
/// sistemato l'accessibilità una volta e non lasciarla più rompere.
final class ProveDaTastiera: XCTestCase {

  static let bundleID = "org.fightthestroke.mirrorscopio"

  var app: XCUIApplication!
  /// La cartella usa-e-getta dove l'app sotto prova scrive i suoi dati.
  var cartellaDati: URL!

  override func setUpWithError() throws {
    continueAfterFailure = false

    cartellaDati = FileManager.default.temporaryDirectory
      .appendingPathComponent("prove-\(UUID().uuidString)", isDirectory: true)

    app = XCUIApplication()
    // I dati veri di un bambino non si toccano nemmeno per sbaglio: l'app sotto
    // prova scrive in una cartella nuova, buttata via alla fine.
    app.launchEnvironment["MIRRORSCOPIO_CARTELLA_DATI"] = cartellaDati.path
    // Le preferenze passate come argomenti finiscono nel dominio più alto di
    // UserDefaults: l'app le legge senza sapere di essere sotto esame, e il
    // Mac di chi lancia le prove resta com'era.
    app.launchArguments += [
      "-onboardingFatto", "YES",       // il primo avvio ha una prova sua
      "-controllaAggiornamenti", "NO", // nessuna prova deve toccare la rete
    ]
    app.launch()
  }

  override func tearDownWithError() throws {
    app?.terminate()
    if let cartellaDati { try? FileManager.default.removeItem(at: cartellaDati) }
  }

  // MARK: - Quello che VoiceOver direbbe

  /// Ogni comando che si può premere deve avere un nome pronunciabile.
  ///
  /// Il difetto tipico è il pulsante fatto di sola icona: sullo schermo si
  /// capisce, ad alta voce diventa «pulsante». Chi non vede lo schermo si
  /// trova davanti a quattro «pulsante» in fila e deve premerli per scoprire
  /// che cosa fanno — cioè esattamente quello che non si può fare quando uno
  /// dei quattro cancella dei dati.
  func testOgniComandoHaUnNome() throws {
    let finestra = app.windows.firstMatch
    XCTAssertTrue(finestra.waitForExistence(timeout: 30), "l'app non ha aperto nessuna finestra")

    var muti: [String] = []
    for tipo in [XCUIElement.ElementType.button, .checkBox, .radioButton,
                 .popUpButton, .slider, .textField, .secureTextField] {
      for elemento in finestra.descendants(matching: tipo).allElementsBoundByIndex {
        guard elemento.exists, elemento.isHittable else { continue }
        if diSistema(elemento) { continue }
        if etichetta(di: elemento).isEmpty {
          muti.append("\(descrizione(tipo)) senza nome in \(elemento.frame)")
        }
      }
    }

    XCTAssertTrue(muti.isEmpty, """
      Ci sono \(muti.count) comandi che VoiceOver annuncerebbe senza dire che cosa fanno:
      \(muti.joined(separator: "\n"))
      Si aggiusta con .accessibilityLabel("…") sul comando.
      """)
  }

  /// Un nome c'è, ma dice qualcosa?
  ///
  /// «Pulsante», «OK», «Image», «Button»: nomi che passano il controllo qui
  /// sopra e non aiutano nessuno. Questa prova li rifiuta per nome.
  func testINomiDiconoQualcosa() throws {
    let finestra = app.windows.firstMatch
    XCTAssertTrue(finestra.waitForExistence(timeout: 30))

    let inutili: Set<String> = ["button", "pulsante", "image", "immagine", "icon",
                                "icona", "ok", "item", "elemento", "view", "vista",
                                "label", "etichetta", "text", "testo", "?", "…", "..."]
    var vaghi: [String] = []
    for elemento in finestra.descendants(matching: .button).allElementsBoundByIndex
    where elemento.exists && elemento.isHittable {
      let nome = etichetta(di: elemento).lowercased()
      if inutili.contains(nome) { vaghi.append("«\(nome)»") }
    }

    XCTAssertTrue(vaghi.isEmpty,
      "Questi nomi non dicono che cosa succede premendo: \(vaghi.joined(separator: ", "))")
  }

  // MARK: - Quello che si riesce a fare senza mouse

  /// Premendo Tab si deve arrivare da qualche parte.
  ///
  /// Se dopo dieci Tab niente ha il fuoco, l'app non si attraversa da tastiera:
  /// chi non usa il mouse è entrato in una stanza senza porte.
  func testSiArrivaDaQualchePartePremendoTab() throws {
    try richiedeNavigazioneDaTastiera()
    let finestra = app.windows.firstMatch
    XCTAssertTrue(finestra.waitForExistence(timeout: 30))

    var raggiunti: Set<String> = []
    for _ in 0..<10 {
      finestra.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
      if let messoAFuoco = elementoAFuoco(in: finestra) { raggiunti.insert(messoAFuoco) }
    }

    XCTAssertFalse(raggiunti.isEmpty, """
      Dieci Tab e niente ha preso il fuoco: la schermata principale non si
      attraversa da tastiera. Chi non usa il mouse non può fare niente qui.
      """)
  }

  /// Il fuoco deve muoversi, non restare incollato al primo comando.
  func testIlFuocoSiMuove() throws {
    try richiedeNavigazioneDaTastiera()
    let finestra = app.windows.firstMatch
    XCTAssertTrue(finestra.waitForExistence(timeout: 30))

    var raggiunti: Set<String> = []
    for _ in 0..<12 {
      finestra.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
      if let messoAFuoco = elementoAFuoco(in: finestra) { raggiunti.insert(messoAFuoco) }
    }

    XCTAssertGreaterThanOrEqual(raggiunti.count, 2, """
      Il fuoco resta fermo sempre sullo stesso comando (\(raggiunti)): gli altri
      non sono raggiungibili da tastiera.
      """)
  }

  /// Si deve poter entrare in una schermata e uscirne, tutto da tastiera. Se si
  /// entra e non si esce, è una trappola.
  func testSiEntraESiEsceDaTastiera() throws {
    let finestra = app.windows.firstMatch
    XCTAssertTrue(finestra.waitForExistence(timeout: 30))

    // Il menu dell'app promette Cmd-virgola per le Impostazioni: una
    // scorciatoia dichiarata e non funzionante è peggio di nessuna scorciatoia.
    app.activate()
    app.typeKey(",", modifierFlags: .command)
    // Il titolo della pagina è quello che VoiceOver annuncia per dire dove si
    // è finiti: se non lo si trova qui, non lo sente nemmeno una persona.
    let titolo = app.staticTexts["Impostazioni"]
    XCTAssertTrue(titolo.waitForExistence(timeout: 10),
      "Cmd-virgola non ha aperto le Impostazioni: la scorciatoia del menu non funziona")

    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    XCTAssertFalse(titolo.waitForExistence(timeout: 3),
      "Esc non ha chiuso le Impostazioni: da tastiera si entra e non si esce più")
  }

  // MARK: - Attrezzi

  /// Le prove con il tasto Tab hanno bisogno di due cose che non dipendono
  /// dall'applicazione. Quando mancano, la prova si ferma dichiarando perché
  /// invece di passare: una prova che passa senza aver provato niente è peggio
  /// di una prova che manca, perché la prima volta che qualcuno rompe la
  /// navigazione da tastiera la spunta resterebbe verde.
  func richiedeNavigazioneDaTastiera() throws {
    guard Accessibilita.navigazioneDaTastieraAttiva else {
      throw XCTSkip("""
        Su questo Mac «Navigazione da tastiera» è spenta, quindi Tab non
        raggiunge i pulsanti e questa prova non proverebbe niente.
        Si accende in Impostazioni di Sistema › Tastiera, oppure da terminale:
          defaults write -g AppleKeyboardUIMode -int 3
        """)
    }
  }

  /// I tre pallini in alto a sinistra — chiudi, riduci, ingrandisci — li mette
  /// macOS, non noi. VoiceOver li annuncia bene per conto suo; XCUITest invece
  /// li riporta senza nome. Accusarli qui vorrebbe dire tenere una prova rossa
  /// per un difetto che non possiamo aggiustare, e una prova rossa che nessuno
  /// può aggiustare finisce ignorata — insieme a tutte le altre.
  func diSistema(_ elemento: XCUIElement) -> Bool {
    elemento.identifier.hasPrefix("_XCUI:")
  }

  /// Il nome che VoiceOver pronuncerebbe per questo comando.
  func etichetta(di elemento: XCUIElement) -> String {
    let label = elemento.label.trimmingCharacters(in: .whitespacesAndNewlines)
    if !label.isEmpty { return label }
    // Le voci di menu e alcuni comandi AppKit si presentano con `title`.
    let titolo = elemento.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !titolo.isEmpty { return titolo }
    // Un campo di testo può essere descritto dal segnaposto: è comunque
    // qualcosa che VoiceOver legge.
    return (elemento.placeholderValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Chi ha il fuoco della tastiera, chiesto a XCUITest.
  ///
  /// `hasFocus` esiste su iPhone e iPad ma non su Mac: nell'intestazione di
  /// sistema è racchiuso in `#if !TARGET_OS_OSX`. La prima strada tentata era
  /// chiederlo all'accessibilità di sistema, lo stesso sportello di VoiceOver —
  /// ma quello sportello vuole un permesso, e il permesso andrebbe concesso al
  /// lanciatore delle prove, che viene ricostruito a ogni compilazione. Una
  /// prova che ha bisogno di un permesso da riconcedere ogni volta è una prova
  /// che smette di girare, e nessuno se ne accorge.
  ///
  /// La fotografia che XCUITest scatta dell'albero, invece, il fuoco lo dice
  /// già: ogni riga porta scritto «Keyboard Focused». Nessun permesso, quindi
  /// funziona anche sulla macchina che esegue le prove a ogni push.
  func elementoAFuoco(in finestra: XCUIElement) -> String? {
    finestra.debugDescription
      .split(separator: "\n")
      .first { $0.contains("Keyboard Focused") }
      .map { $0.trimmingCharacters(in: .whitespaces) }
  }

  /// Come si chiama, in italiano, il tipo di comando.
  func descrizione(_ tipo: XCUIElement.ElementType) -> String {
    switch tipo {
    case .button: "un pulsante"
    case .checkBox: "un interruttore"
    case .radioButton: "una scelta"
    case .popUpButton: "un menu a tendina"
    case .slider: "un cursore"
    case .textField, .secureTextField: "un campo di testo"
    default: "un comando"
    }
  }
}
