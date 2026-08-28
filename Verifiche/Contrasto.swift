import Testing
import SwiftUI
import AppKit
@testable import MirrorScopio

/// Il rapporto di contrasto fra due colori, come lo definisce la WCAG.
/// Sotto 4,5 a 1 un testo normale non si legge, se si vede poco.
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
        r >= 4.5,
        "\(tema.label) · \(vista.label) · \(che): \(String(format: "%.2f", r)) a 1, serve almeno 4,50"
      )
    }
  }

  /// Un controllo che non sa fallire non sta controllando niente.
  ///
  /// Bianco su giallo è il difetto vero che avevamo messo in giro: 1,41 a 1.
  /// Se un giorno questo test diventasse verde, vorrebbe dire che la misura si
  /// è rotta, non che il difetto è sparito.
  @Test("La misura sa ancora bocciare: bianco su giallo resta illeggibile")
  func laMisuraSaBocciare() {
    let r = contrasto(.white, Color(red: 1, green: 0.85, blue: 0))
    #expect(r < 4.5, "bianco su giallo deve risultare illeggibile, invece dà \(r)")
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
