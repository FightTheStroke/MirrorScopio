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
  var ok: Color {
    switch self {
    case .standard: Color(red: 0.13, green: 0.55, blue: 0.24)
    case .deuteranopia, .protanopia: Color(red: 0.00, green: 0.45, blue: 0.80)
    case .tritanopia: Color(red: 0.00, green: 0.50, blue: 0.35)
    case .monocromia: Color(white: 0.25)
    }
  }

  /// Colore per "sbagliato".
  var wrong: Color {
    switch self {
    case .standard: Color(red: 0.80, green: 0.16, blue: 0.16)
    case .deuteranopia, .protanopia: Color(red: 0.85, green: 0.55, blue: 0.00)
    case .tritanopia: Color(red: 0.85, green: 0.20, blue: 0.35)
    case .monocromia: Color(white: 0.55)
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
  /// Vero quando lo sfondo è scuro: serve per scegliere il colore delle ombre.
  var isDark: Bool

  static func resolve(theme: ThemeChoice, vision: ColorVision, system: ColorScheme) -> Palette {
    let effective: ThemeChoice = theme == .auto ? (system == .dark ? .scuro : .chiaro) : theme

    switch effective {
    case .chiaro, .auto:
      return Palette(background: Color(white: 1.0),
                     surface: Color(white: 0.95),
                     foreground: Color(white: 0.08),
                     muted: Color(white: 0.38),
                     accent: Color(red: 0.15, green: 0.39, blue: 0.92), onAccent: .white,
                     ok: vision.ok, wrong: vision.wrong, isDark: false)
    case .scuro:
      return Palette(background: Color(red: 0.07, green: 0.08, blue: 0.11),
                     surface: Color(red: 0.13, green: 0.14, blue: 0.18),
                     foreground: Color(white: 0.96),
                     muted: Color(white: 0.68),
                     accent: Color(red: 0.42, green: 0.62, blue: 1.0),
                     onAccent: Color(white: 0.05),
                     ok: vision.ok, wrong: vision.wrong, isDark: true)
    case .altoContrasto:
      return Palette(background: .black,
                     surface: Color(white: 0.12),
                     foreground: .white,
                     muted: Color(white: 0.85),
                     accent: Color(red: 1.0, green: 0.84, blue: 0.0),
                     onAccent: .black,
                     ok: Color(red: 0.35, green: 1.0, blue: 0.45),
                     wrong: Color(red: 1.0, green: 0.65, blue: 0.0),
                     isDark: true)
    case .sabbia:
      return Palette(background: Color(red: 0.98, green: 0.95, blue: 0.87),
                     surface: Color(red: 0.95, green: 0.91, blue: 0.81),
                     foreground: Color(red: 0.16, green: 0.14, blue: 0.10),
                     muted: Color(red: 0.40, green: 0.36, blue: 0.28),
                     accent: Color(red: 0.15, green: 0.36, blue: 0.72), onAccent: .white,
                     ok: vision.ok, wrong: vision.wrong, isDark: false)
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
