import SwiftUI

// MARK: - Temi

/// Come deve apparire l'app. "Auto" segue il Mac.
enum ThemeChoice: String, CaseIterable, Identifiable, Codable {
  case auto, chiaro, scuro, altoContrasto, sabbia

  var id: String { rawValue }

  var label: String {
    switch self {
    case .auto: "Come il Mac"
    case .chiaro: "Chiaro"
    case .scuro: "Scuro"
    case .altoContrasto: "Altissimo contrasto"
    case .sabbia: "Carta (crema)"
    }
  }

  /// Perché uno sceglierebbe questo tema, detto senza gergo.
  var hint: String {
    switch self {
    case .auto: "Segue l'impostazione del Mac."
    case .chiaro: "Sfondo bianco, lettere nere."
    case .scuro: "Sfondo scuro: stanca meno gli occhi la sera."
    case .altoContrasto: "Nero pieno e bianco pieno: per chi vede poco."
    case .sabbia: "Sfondo color crema: molti lettori dislessici lo trovano più riposante del bianco."
    }
  }
}

/// Come vede i colori chi usa l'app. Cambia i colori di esito, non il testo.
///
/// Le voci descrivono **cosa succede guardando lo schermo**, non che cosa manca
/// a chi guarda. La prima si chiamava "Normale", e chiamare normale un modo di
/// vedere significa dire a tutti gli altri quello che sono. Chi apre questa
/// app ha già sentito abbastanza spesso di essere l'eccezione.
enum ColorVision: String, CaseIterable, Identifiable, Codable {
  case standard, deuteranopia, protanopia, tritanopia, monocromia

  var id: String { rawValue }

  var label: String {
    switch self {
    case .standard: "Distinguo tutti i colori"
    case .deuteranopia: "Il verde e il rosso si somigliano"
    case .protanopia: "Il rosso mi sembra spento"
    case .tritanopia: "Il blu e il giallo si somigliano"
    case .monocromia: "Vedo tutto in tonalità di grigio"
    }
  }

  /// Colore per "giusto". Mai solo il colore: è sempre accompagnato da un simbolo.
  ///
  /// Dipende dallo sfondo, e per un pezzo non è stato così: c'era un colore
  /// solo, calcolato per lo sfondo bianco, riusato tale e quale sul nero. I
  /// numeri di quel riuso: «giusta» in verde sul tema scuro faceva 4,28 a 1
  /// contro il 4,5 richiesto, «ancora» in rosso 3,42, e per chi vede tutto in
  /// grigio e sceglie il tema scuro «giusta» faceva **1,76** — cioè quasi lo
  /// sfondo. La parola che dice com'è andata era la meno leggibile dello
  /// schermo, per chi ha più bisogno di leggerla.
  ///
  /// Non è un dettaglio da manuale: si è visto in un PNG disegnato dal banco
  /// di prova, e poi misurato. Adesso ogni combinazione sta sopra 7 a 1 — il
  /// livello alto della WCAG, non quello minimo — su tutti e quattro i temi e
  /// per tutti e cinque i modi di vedere i colori. Il livello minimo è pensato
  /// per chi legge senza fatica; qui legge chi fatica, e il documento di
  /// accessibilità prometteva il livello alto da prima che fosse vero.
  func ok(isDark: Bool) -> Color {
    switch self {
    case .standard:
      isDark ? Color(red: 0.44, green: 0.76, blue: 0.52) : Color(red: 0.10, green: 0.34, blue: 0.17)
    case .deuteranopia, .protanopia:
      isDark ? Color(red: 0.41, green: 0.71, blue: 0.95) : Color(red: 0.00, green: 0.30, blue: 0.54)
    case .tritanopia:
      isDark ? Color(red: 0.34, green: 0.76, blue: 0.63) : Color(red: 0.00, green: 0.34, blue: 0.24)
    case .monocromia:
      // Qui il colore non dice niente per definizione: a distinguere sono la
      // forma e la parola. La differenza di chiarezza resta comunque netta,
      // perché è l'unico indizio in più che si può dare.
      isDark ? Color(white: 0.95) : Color(white: 0.15)
    }
  }

  /// Colore per la parola che non è venuta.
  func wrong(isDark: Bool) -> Color {
    switch self {
    case .standard:
      isDark ? Color(red: 1.00, green: 0.56, blue: 0.56) : Color(red: 0.58, green: 0.11, blue: 0.11)
    case .deuteranopia, .protanopia:
      isDark ? Color(red: 0.88, green: 0.64, blue: 0.21) : Color(red: 0.41, green: 0.26, blue: 0.00)
    case .tritanopia:
      isDark ? Color(red: 0.98, green: 0.56, blue: 0.66) : Color(red: 0.56, green: 0.13, blue: 0.23)
    case .monocromia:
      isDark ? Color(white: 0.69) : Color(white: 0.29)
    }
  }

  /// Simbolo per "giusto"/"sbagliato": la forma porta l'informazione anche senza colore.
  static let okSymbol = "checkmark.circle.fill"
  /// Non una croce: una freccia che torna indietro.
  ///
  /// La croce dice "hai sbagliato", e a un ragazzo che sbaglia da anni quella
  /// croce è già arrivata abbastanza volte. La freccia dice "di nuovo", che è
  /// l'unica cosa vera: la parola non è ancora venuta, e si riprova. Resta una
  /// forma nettamente diversa dal segno di spunta, così chi non distingue i
  /// colori vede comunque la differenza.
  static let wrongSymbol = "arrow.counterclockwise.circle.fill"
}

/// I colori concreti usati dalle viste, già risolti.
struct Palette {
  var background: Color
  var surface: Color
  var foreground: Color
  var muted: Color
  var accent: Color
  /// Il colore del testo **sopra** `accent`.
  ///
  /// Non e' sempre bianco, ed e' un errore che abbiamo fatto davvero: dopo aver
  /// tolto il blu di sistema dai pulsanti principali li abbiamo riempiti di
  /// accent con la scritta bianca sopra. Con «Altissimo contrasto» l'accent e'
  /// giallo pieno, e bianco su giallo fa circa 1,1 a 1: illeggibile. Cioe'
  /// avevamo reso invisibili «Via!» e «Consenti il microfono» esattamente nel
  /// tema che sceglie chi vede poco.
  var onAccent: Color
  var ok: Color
  var wrong: Color
  /// L'oro di un obiettivo conquistato.
  ///
  /// Era scritto a mano in tre punti diversi — la medaglia, la cornice della
  /// cella nei progressi — con lo stesso oro copiato ogni volta, e quell'oro
  /// non cambiava mai col tema: sul nero di «Altissimo contrasto» restava lo
  /// stesso di sul bianco. Un colore che dice «questo l'hai preso» porta
  /// informazione, e i colori che portano informazione stanno qui.
  var premio: Color
  /// La fiamma dei giorni di fila.
  var serie: Color
  /// Il comando che ferma tutto a metà esercizio.
  ///
  /// Rosso perché interrompe, non perché sia un errore: chi preme «Basta» non
  /// ha sbagliato niente. Sta separato da `wrong` proprio per questo.
  var stop: Color
  /// Vero quando lo sfondo è scuro: serve per scegliere il colore delle ombre.
  var isDark: Bool

  static func resolve(theme: ThemeChoice, vision: ColorVision, system: ColorScheme) -> Palette {
    let effective: ThemeChoice = theme == .auto ? (system == .dark ? .scuro : .chiaro) : theme

    switch effective {
    case .chiaro, .auto:
      return Palette(background: Color(white: 1.0),
                     surface: Color(white: 0.95),
                     foreground: Color(white: 0.08),
                     muted: Color(white: 0.345),
                     accent: Color(red: 0.11, green: 0.31, blue: 0.74), onAccent: .white,
                     ok: vision.ok(isDark: false), wrong: vision.wrong(isDark: false),
                     premio: Self.premioChiaro, serie: Self.serieChiara, stop: Self.stopChiaro,
                     isDark: false)
    case .scuro:
      return Palette(background: Color(red: 0.07, green: 0.08, blue: 0.11),
                     surface: Color(red: 0.13, green: 0.14, blue: 0.18),
                     foreground: Color(white: 0.96),
                     muted: Color(white: 0.68),
                     accent: Color(red: 0.42, green: 0.62, blue: 1.0),
                     onAccent: Color(white: 0.05),
                     ok: vision.ok(isDark: true), wrong: vision.wrong(isDark: true),
                     premio: Self.premioScuro, serie: Self.serieScura, stop: Self.stopScuro,
                     isDark: true)
    case .altoContrasto:
      return Palette(background: .black,
                     surface: Color(white: 0.12),
                     foreground: .white,
                     muted: Color(white: 0.85),
                     accent: Color(red: 1.0, green: 0.84, blue: 0.0),
                     onAccent: .black,
                     ok: Color(red: 0.35, green: 1.0, blue: 0.45),
                     wrong: Color(red: 1.0, green: 0.65, blue: 0.0),
                     premio: Self.premioScuro, serie: Self.serieScura, stop: Self.stopScuro,
                     isDark: true)
    case .sabbia:
      return Palette(background: Color(red: 0.98, green: 0.95, blue: 0.87),
                     surface: Color(red: 0.95, green: 0.91, blue: 0.81),
                     foreground: Color(red: 0.16, green: 0.14, blue: 0.10),
                     muted: Color(red: 0.35, green: 0.31, blue: 0.24),
                     accent: Color(red: 0.14, green: 0.33, blue: 0.67), onAccent: .white,
                     ok: vision.ok(isDark: false), wrong: vision.wrong(isDark: false),
                     premio: Self.premioChiaro, serie: Self.serieChiara, stop: Self.stopChiaro,
                     isDark: false)
    }
  }

  // I tre colori che portano informazione fuori dagli esiti. Non seguono il
  // modo di vedere i colori perché non c'è niente da distinguere: sono uno
  // solo per volta, e accanto c'è sempre la forma e la parola che lo dicono.
  private static let premioChiaro = Color(red: 0.62, green: 0.45, blue: 0.05)
  private static let premioScuro  = Color(red: 0.95, green: 0.78, blue: 0.30)
  private static let serieChiara  = Color(red: 0.72, green: 0.36, blue: 0.00)
  private static let serieScura   = Color(red: 1.00, green: 0.66, blue: 0.30)
  private static let stopChiaro   = Color(red: 0.72, green: 0.11, blue: 0.13)
  private static let stopScuro    = Color(red: 1.00, green: 0.50, blue: 0.50)
}

/// I materiali dell'arena 3D. Le tinte vivono qui, non nelle viste, e le
/// figure importanti restano ad almeno 3:1 dalle superfici su cui compaiono.
struct PaletteArena {
  var cieloAlto: Color
  var cieloBasso: Color
  var terra: Color
  var terraLuce: Color
  var pista: Color
  var pistaLato: Color
  var ostacolo: Color
  var dettaglioOstacolo: Color
  var eroe: Color
  var squadra: Color
  var premio: Color
  var traguardo: Color
  var decorazione: Color
  var segno: Color
  var ombra: Color
  var altoContrasto: Bool

  static func resolve(theme: ThemeChoice, palette: Palette,
                      vision: ColorVision) -> PaletteArena {
    let effective = theme == .auto ? (palette.isDark ? ThemeChoice.scuro : .chiaro) : theme
    let figure = coloriFigure(vision)

    switch effective {
    case .chiaro, .auto:
      return colorata(
        cieloAlto: Color(red: 0.10, green: 0.18, blue: 0.58),
        cieloBasso: Color(red: 0.58, green: 0.27, blue: 0.84),
        terra: Color(red: 0.02, green: 0.10, blue: 0.15),
        terraLuce: Color(red: 0.04, green: 0.30, blue: 0.28),
        pista: Color(red: 0.04, green: 0.14, blue: 0.32),
        pistaLato: Color(red: 0.02, green: 0.08, blue: 0.18),
        figure: figure)
    case .scuro:
      return colorata(
        cieloAlto: Color(red: 0.03, green: 0.05, blue: 0.17),
        cieloBasso: Color(red: 0.30, green: 0.12, blue: 0.53),
        terra: Color(red: 0.01, green: 0.07, blue: 0.11),
        terraLuce: Color(red: 0.03, green: 0.20, blue: 0.20),
        pista: Color(red: 0.03, green: 0.10, blue: 0.24),
        pistaLato: Color(red: 0.01, green: 0.05, blue: 0.13),
        figure: figure)
    case .sabbia:
      return colorata(
        cieloAlto: Color(red: 0.16, green: 0.28, blue: 0.57),
        cieloBasso: Color(red: 0.78, green: 0.35, blue: 0.32),
        terra: Color(red: 0.05, green: 0.11, blue: 0.13),
        terraLuce: Color(red: 0.12, green: 0.28, blue: 0.22),
        pista: Color(red: 0.08, green: 0.16, blue: 0.28),
        pistaLato: Color(red: 0.04, green: 0.09, blue: 0.15),
        figure: figure)
    case .altoContrasto:
      return PaletteArena(
        cieloAlto: palette.background, cieloBasso: palette.background,
        terra: palette.background, terraLuce: palette.surface,
        pista: palette.surface, pistaLato: palette.background,
        ostacolo: figure.ostacolo, dettaglioOstacolo: palette.background,
        eroe: palette.accent, squadra: figure.squadra,
        premio: palette.foreground, traguardo: palette.foreground,
        decorazione: Color(white: 0.35),
        segno: palette.foreground, ombra: palette.background,
        altoContrasto: true)
    }
  }

  private static func colorata(cieloAlto: Color, cieloBasso: Color,
                               terra: Color, terraLuce: Color,
                               pista: Color, pistaLato: Color,
                               figure: (ostacolo: Color, squadra: Color)) -> PaletteArena {
    PaletteArena(
      cieloAlto: cieloAlto, cieloBasso: cieloBasso,
      terra: terra, terraLuce: terraLuce,
      pista: pista, pistaLato: pistaLato,
      ostacolo: figure.ostacolo, dettaglioOstacolo: .black,
      eroe: Color(red: 1.00, green: 0.88, blue: 0.20),
      squadra: figure.squadra,
      premio: Color(red: 0.35, green: 0.85, blue: 1.00),
      traguardo: Color(white: 0.96),
      decorazione: Color(red: 0.20, green: 0.48, blue: 0.55),
      segno: .white, ombra: .black, altoContrasto: false)
  }

  private static func coloriFigure(_ vision: ColorVision) -> (ostacolo: Color, squadra: Color) {
    switch vision {
    case .standard:
      (Color(red: 1.00, green: 0.84, blue: 0.88),
       Color(red: 0.35, green: 1.00, blue: 0.62))
    case .deuteranopia, .protanopia:
      (Color(red: 1.00, green: 0.92, blue: 0.62),
       Color(red: 0.55, green: 0.86, blue: 1.00))
    case .tritanopia:
      (Color(red: 1.00, green: 0.84, blue: 0.91),
       Color(red: 0.48, green: 1.00, blue: 0.72))
    case .monocromia:
      (Color(white: 0.92), Color(white: 0.68))
    }
  }
}

/// La palette viaggia nell'ambiente così ogni vista la trova senza passarsela a mano.
private struct PaletteKey: EnvironmentKey {
  static let defaultValue = Palette.resolve(theme: .chiaro, vision: .standard, system: .light)
}

extension EnvironmentValues {
  var palette: Palette {
    get { self[PaletteKey.self] }
    set { self[PaletteKey.self] = newValue }
  }
}
