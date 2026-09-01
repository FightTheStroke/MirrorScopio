import Testing
import SwiftUI
import AppKit
@testable import MirrorScopio

/// Il rapporto di contrasto fra due colori, come lo definisce la WCAG.
///
/// Il livello minimo — 4,5 a 1 — è pensato per chi legge senza fatica. Qui
/// legge chi fatica, e `docs/ACCESSIBILITA.md` prometteva il livello alto da
/// prima che fosse vero: la misura c'era e si fermava al minimo. Adesso la
/// soglia è 7 a 1 per tutto quello che l'app scrive, e 3 a 1 per le forme che
/// portano informazione senza essere testo — bordi, medaglie, fiamme — che è
/// quello che la WCAG chiede per loro.
@MainActor
func contrasto(_ a: Color, _ b: Color) -> Double {
  func luminanza(_ c: Color) -> Double {
    let n = NSColor(c).usingColorSpace(.sRGB) ?? .black
    func canale(_ v: Double) -> Double {
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * canale(Double(n.redComponent))
         + 0.7152 * canale(Double(n.greenComponent))
         + 0.0722 * canale(Double(n.blueComponent))
  }
  let x = luminanza(a), y = luminanza(b)
  return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

/// Ogni parola che l'app scrive deve leggersi davvero, in tutti i temi e per
/// tutti i modi di vedere i colori.
///
/// Questo controllo esiste perché due volte di fila abbiamo messo in giro del
/// testo illeggibile senza accorgercene: bianco su giallo sui pulsanti che
/// aprono l'esercizio, e la parola «giusta» a 1,76 a 1 per chi vede in grigio
/// col tema scuro — cioè la parola che dice com'è andata era la meno leggibile
/// dello schermo. A occhio non si vede. A numeri sì.
/// Tutti i temi veri per tutti i modi di vedere i colori.
/// «Automatico» non è un tema: è «prendi quello di sistema», e quello di
/// sistema è già fra i temi provati qui sotto.
let combinazioniDiTemaEVista: [(ThemeChoice, ColorVision)] =
  ThemeChoice.allCases
    .filter { $0 != .auto }
    .flatMap { tema in ColorVision.allCases.map { (tema, $0) } }

@Suite("Contrasto dei colori")
@MainActor
struct Contrasto {

  @Test("Tutto quello che l'app scrive si legge", arguments: combinazioniDiTemaEVista)
  func tuttoSiLegge(tema: ThemeChoice, vista: ColorVision) {
    let p = Palette.resolve(theme: tema, vision: vista, system: .light)
    let prove: [(String, Color, Color)] = [
      ("testo sul fondo",       p.foreground, p.background),
      ("testo sulla carta",     p.foreground, p.surface),
      ("testo smorzato",        p.muted,      p.background),
      ("«giusta»",              p.ok,         p.background),
      ("«ancora»",              p.wrong,      p.background),
      ("«giusta» sulla carta",  p.ok,         p.surface),
      ("«ancora» sulla carta",  p.wrong,      p.surface),
      ("scritta sull'accento",  p.onAccent,   p.accent),
    ]
    for (che, davanti, dietro) in prove {
      let r = contrasto(davanti, dietro)
      #expect(
        r >= 7.0,
        "\(tema.label) · \(vista.label) · \(che): \(String(format: "%.2f", r)) a 1, serve almeno 7,00"
      )
    }
  }

  /// Le forme che dicono qualcosa senza parlare.
  ///
  /// L'oro di un obiettivo conquistato, la fiamma dei giorni di fila e il rosso
  /// del comando che ferma tutto erano scritti a mano dentro le viste, uguali
  /// su ogni tema: sul nero di «Altissimo contrasto» restavano quelli del
  /// bianco. Adesso stanno nella palette e cambiano col tema, e qui si misura
  /// che si vedano — 3 a 1 è la soglia della WCAG per le forme, non per il
  /// testo.
  @Test("Anche le forme che dicono qualcosa si vedono", arguments: combinazioniDiTemaEVista)
  func leFormeSiVedono(tema: ThemeChoice, vista: ColorVision) {
    let p = Palette.resolve(theme: tema, vision: vista, system: .light)
    let prove: [(String, Color)] = [
      ("oro dell'obiettivo conquistato", p.premio),
      ("fiamma dei giorni di fila", p.serie),
      ("rosso del comando che ferma", p.stop),
    ]
    for (che, colore) in prove {
      for (dove, dietro) in [("sul fondo", p.background), ("sulla carta", p.surface)] {
        let r = contrasto(colore, dietro)
        #expect(
          r >= 3.0,
          "\(tema.label) · \(vista.label) · \(che) \(dove): \(String(format: "%.2f", r)) a 1, serve almeno 3,00"
        )
      }
    }

    let campo: [(String, Color, Color)] = [
      ("pista del gioco", p.secondoPianoCampoSport, p.sfondoCampoSport),
      ("contorno sul campo", p.segnoCampoSport, p.sfondoCampoSport),
    ]
    for (che, davanti, dietro) in campo {
      let r = contrasto(davanti, dietro)
      #expect(
        r >= 3.0,
        "\(tema.label) · \(vista.label) · \(che): \(String(format: "%.2f", r)) a 1, serve almeno 3,00"
      )
    }

    let arena = PaletteArena.resolve(theme: tema, palette: p)
    let righeArena = contrasto(arena.segno, arena.pista)
    #expect(
      righeArena >= 3.0,
      "\(tema.label) · \(vista.label) · righe dell'arena: \(String(format: "%.2f", righeArena)) a 1, serve almeno 3,00"
    )
  }

  /// Un controllo che non sa fallire non sta controllando niente.
  ///
  /// Bianco su giallo è il difetto vero che avevamo messo in giro: 1,41 a 1.
  /// Se un giorno questo test diventasse verde, vorrebbe dire che la misura si
  /// è rotta, non che il difetto è sparito.
  @Test("La misura sa ancora bocciare: bianco su giallo resta illeggibile")
  func laMisuraSaBocciare() {
    let r = contrasto(.white, Color(red: 1, green: 0.85, blue: 0))
    #expect(r < 7.0, "bianco su giallo deve risultare illeggibile, invece dà \(r)")
    #expect(r < 2.0, "il valore atteso è intorno a 1,41 a 1; qui è \(r)")
  }
}

/// Nessuna schermata deve poter nascondere il proprio ultimo pulsante.
///
/// Misurata una volta, «Pronti?» era alta 742 punti a ingrandimento normale e
/// 1467 con i caratteri grandi, dentro una finestra da 700: «Scegli il
/// microfono» finiva sotto il bordo e non c'era modo di arrivarci. Chi ha
/// bisogno dei caratteri grandi era esattamente chi non poteva piu' usare
/// l'app.
///
/// La regola qui non e' «tutte le schermate scorrono»: e' «una schermata piu'
/// alta della finestra deve scorrere». Si misura quanto e' alto il contenuto
/// davvero, con i caratteri al massimo, e solo se sfora si pretende lo
/// scorrimento. Cosi' il palcoscenico della lettura, che deve restare fermo
/// perche' la parola non scappi sotto gli occhi, resta libero di non scorrere
/// finche' ci sta.
@Suite("Niente finisce sotto il bordo della finestra")
@MainActor
struct SottoIlBordo {

  /// L'altezza vera del contenuto, misurata come farebbe SwiftUI.
  ///
  /// Attenzione: misura il contenuto **anche dentro uno ScrollView**. Serve
  /// proprio a questo — dice se il contenuto sfora, non se qualcuno ha messo
  /// un rimedio. Il rimedio si controlla sul codice.
  func altezza<V: View>(_ vista: V, larghezza: CGFloat) -> CGFloat {
    ImageRenderer(content: vista.frame(width: larghezza)
      .fixedSize(horizontal: false, vertical: true)).nsImage?.size.height ?? 0
  }

  /// L'altezza della finestra dell'applicazione.
  static let finestra: CGFloat = 700

  static var vistaDir: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/Views")
  }

  func scorre(_ nome: String) throws -> Bool {
    let testo = try String(
      contentsOf: Self.vistaDir.appendingPathComponent("\(nome).swift"), encoding: .utf8)
    // «PaginaConElenco» porta il proprio scorrimento con se': le Impostazioni e
    // i Progressi non scrivono piu' «ScrollView» perche' lo fa il guscio.
    return testo.contains("ScrollView") || testo.contains("PaginaConElenco")
  }

  var temaChiaro: Palette { Palette.resolve(theme: .chiaro, vision: .standard, system: .light) }

  var caratteriGrandi: EffettiveImpostazioniAccessibilita {
    var a = A11ySettings()
    a.textScale = 1.8
    return EffettiveImpostazioniAccessibilita(a)
  }

  @Test("«Scrivi» non nasconde il campo dove si scrive")
  func scrivi() throws {
    let h = altezza(TypingView(engine: SessionEngine(), a11y: caratteriGrandi)
      .environment(\.palette, temaChiaro), larghezza: 900)
    if h > Self.finestra {
      #expect(try scorre("TypingView"),
        "il contenuto e' alto \(Int(h)) punti in una finestra da \(Int(Self.finestra)) e la schermata non scorre: il campo dove si scrive finisce sotto il bordo")
    }
  }

  @Test("Il gioco non nasconde il pulsante per chiudere")
  func gioco() throws {
    let h = altezza(StaffettaView(a11y: caratteriGrandi, onClose: {})
      .environment(\.palette, temaChiaro), larghezza: 900)
    if h > Self.finestra {
      #expect(try scorre("StaffettaView"),
        "il gioco e' alto \(Int(h)) punti in una finestra da \(Int(Self.finestra)) e non scorre: la parte bassa della festa resta fuori schermo, e resta fuori proprio a chi ha ingrandito il testo")
    }
  }

  /// Le schermate che occupano tutta la finestra: qui lo scorrimento si
  /// pretende sempre, perche' il testo dentro puo' crescere quanto vuole.
  static let schermateIntere = [
    "HomeView", "SettingsView", "DashboardView", "AiutoView", "ReportView",
    "OnboardingView", "ReadinessView", "AudioCheckView", "InstructionsView",
  ]

  @Test("Ogni schermata intera scorre", arguments: schermateIntere)
  func schermataScorre(nome: String) throws {
    #expect(try scorre(nome),
      "\(nome) non scorre: con i caratteri grandi il contenuto finisce sotto il bordo e non si puo' piu' raggiungere")
  }
}

/// Le due schermate lunghe devono restare la stessa schermata.
///
/// «Impostazioni» e «I tuoi progressi» condividevano già l'intestazione e
/// l'elenco laterale, eppure a schermo erano diverse: titolo rientrato di 54
/// punti invece di 26, una riga di separazione in più, contenuto largo 860
/// invece di 720. Condividere i pezzi non basta se ognuno li monta a modo suo.
/// Ora c'è un guscio unico, e questo controllo esiste perché fra sei mesi
/// nessuno rimetta i numeri a mano «solo per questa volta».
@Suite("Le schermate lunghe restano uguali")
struct SchermateLunghe {

  static var vistaDir: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/Views")
  }

  @Test("Usano il guscio condiviso invece di montarselo da sole",
        arguments: ["SettingsView", "DashboardView"])
  func usanoIlGuscio(nome: String) throws {
    let testo = try String(
      contentsOf: Self.vistaDir.appendingPathComponent("\(nome).swift"), encoding: .utf8)
    #expect(testo.contains("PaginaConElenco"),
      "\(nome) non usa PaginaConElenco: se si monta il layout da sola, prima o poi si sposta di qualche punto e le due schermate tornano a somigliarsi solo per caso")
    #expect(!testo.contains("ElencoPagine("),
      "\(nome) monta l'elenco laterale a mano: e' esattamente cosi' che le due schermate erano divergute")
  }
}

/// Il testo grande non deve sfondare la larghezza.
///
/// Finora si misurava solo l'altezza, e l'altezza è la metà del problema: il
/// testo ingrandito allarga anche. La colonna laterale delle schermate lunghe
/// era larga 260 punti *moltiplicati per l'ingrandimento* — a testo quasi
/// doppio diventava mezzo schermo, e si mangiava lo spazio proprio a chi aveva
/// chiesto testo grande perché lo spazio gli serviva per leggere. Le tabelle
/// avevano colonne da 130, 120 e 80 punti fissi con dentro testo che cresce:
/// le parole finivano fuori dalla loro casella.
@Suite("Il testo grande non sfonda la larghezza")
@MainActor
struct LarghezzaColTestoGrande {

  /// Le voci dell'elenco laterale, ridotte all'osso: qui si misura il guscio,
  /// non le Impostazioni.
  enum PaginaDiProva: String, PaginaLaterale {
    case prima, seconda, terza, quarta, quinta
    var id: String { rawValue }
    var titolo: String {
      switch self {
      case .prima: "Come si vede"
      case .seconda: "Ritmo e calma"
      case .terza: "Colori e luce"
      case .quarta: "Suoni e voce"
      case .quinta: "I dati"
      }
    }
    var simbolo: String { "gearshape" }
  }

  func altezza<V: View>(_ vista: V, larghezza: CGFloat) -> CGFloat {
    ImageRenderer(content: vista.frame(width: larghezza)
      .fixedSize(horizontal: false, vertical: true)).nsImage?.size.height ?? 0
  }

  /// La larghezza che una vista chiede quando nessuno gliela impone.
  func larghezza<V: View>(_ vista: V) -> CGFloat {
    ImageRenderer(content: vista.fixedSize()).nsImage?.size.width ?? 0
  }

  var temaChiaro: Palette { Palette.resolve(theme: .chiaro, vision: .standard, system: .light) }

  /// La larghezza della finestra dell'applicazione.
  static let finestra: CGFloat = 1100

  func impostazioni(scala: Double) -> EffettiveImpostazioniAccessibilita {
    var a = A11ySettings()
    a.textScale = scala
    return EffettiveImpostazioniAccessibilita(a)
  }

  @Test("La colonna laterale non si mangia la finestra")
  func colonnaNonSiMangiaLaFinestra() {
    var scelta = PaginaDiProva.prima
    // Il cursore in Impostazioni ha passo 0,03 su 0,8…2,0: le scale possibili
    // sono un continuo, non sei valori tondi. La prova provava solo i sei, e
    // saltava proprio quelli che rompono: a ×1,4 la colonna misura 364 punti su
    // 366 disponibili — passa per due punti — e a ×1,5, che si raggiunge
    // benissimo, ne chiede 390. Ora si prova tutto l'intervallo.
    for scala in stride(from: 0.8, through: 2.0, by: 0.05) {
      let a = impostazioni(scala: scala)
      // Sopra la soglia l'elenco non sta più di fianco al contenuto: sta sopra,
      // in fila, e la larghezza gliela dà la finestra. Lì la misura giusta è
      // l'altezza, ed è la prova qui sotto.
      guard !a.testoGrande else { continue }
      let l = larghezza(ElencoPagine(scelta: Binding(get: { scelta }, set: { scelta = $0 }),
                                     a11y: a, palette: temaChiaro)
        .environment(\.palette, temaChiaro))
      #expect(l <= Self.finestra / 3,
        "con il testo a ×\(scala) l'elenco delle pagine chiede \(Int(l)) punti su \(Int(Self.finestra)): si mangia lo spazio proprio a chi ha ingrandito il testo per avere spazio")
    }
  }

  @Test("Col testo grande l'elenco diventa una barra, non resta una colonna")
  func diventaBarra() {
    var scelta = PaginaDiProva.prima
    func alto(_ a: EffettiveImpostazioniAccessibilita) -> CGFloat {
      altezza(ElencoPagine(scelta: Binding(get: { scelta }, set: { scelta = $0 }),
                           a11y: a, palette: temaChiaro)
        .environment(\.palette, temaChiaro), larghezza: Self.finestra)
    }
    let colonna = alto(impostazioni(scala: 1.0))
    let barra = alto(impostazioni(scala: 2.0))
    #expect(barra < colonna,
      "col testo a ×2 l'elenco è alto \(Int(barra)) punti contro i \(Int(colonna)) del testo normale: non si è messo in fila in alto, è rimasto una colonna")
  }

  static var sorgenti: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Sources")
  }

  /// Rimpicciolire il testo di chi ha chiesto testo grande è l'esatto contrario
  /// di quello che ha chiesto. Se un numero non ci sta, va a capo.
  @Test("Nessuna scritta si rimpicciolisce per stare dentro")
  func nienteRimpicciolimenti() throws {
    // Il file si legge dal percorso, non dall'URL: leggere da un URL accetta
    // anche un indirizzo di rete, e il cancello che difende la regola «niente
    // esce da questo Mac» lo vieta ovunque, prove comprese. Giustamente: una
    // prova che porta fuori i dati li porta fuori uguale.
    let trovati = try file(sotto: Self.sorgenti).filter {
      guard let dati = FileManager.default.contents(atPath: $0.path) else { return false }
      return String(decoding: dati, as: UTF8.self).contains("minimumScaleFactor")
    }
    #expect(trovati.isEmpty,
      "\(trovati.map(\.lastPathComponent).joined(separator: ", ")): il testo si rimpicciolisce da solo invece di andare a capo")
  }

  /// Il testo clinico non sta in colonne a larghezza scritta a mano: il testo
  /// cresce con l'ingrandimento, la colonna no, e la parola finisce fuori.
  @Test("Il riepilogo non ha colonne a larghezza fissa")
  func nienteColonneFisse() throws {
    // Come sopra: dal percorso, non dall'URL.
    let dati = FileManager.default.contents(
      atPath: Self.sorgenti.appendingPathComponent("Views/ReportView.swift").path)
    let testo = String(decoding: dati ?? Data(), as: UTF8.self)
    #expect(dati != nil, "ReportView.swift non si legge: la prova qui sotto non proverebbe niente")
    // `frame(width: 0, height: 0)` è il pulsante invisibile delle scorciatoie:
    // non contiene testo e non è una colonna.
    let colonne = testo.split(separator: "\n").filter {
      $0.contains(".frame(width:") && !$0.contains("width: 0")
    }
    #expect(colonne.isEmpty,
      "colonne a larghezza fissa nel riepilogo: \(colonne.map { $0.trimmingCharacters(in: .whitespaces) })")
  }

  func file(sotto cartella: URL) throws -> [URL] {
    let e = FileManager.default.enumerator(at: cartella, includingPropertiesForKeys: nil)
    return (e?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
  }
}
