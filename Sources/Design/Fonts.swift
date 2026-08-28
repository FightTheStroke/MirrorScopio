import SwiftUI
import Synchronization
import AppKit
import CoreText

// MARK: - Caratteri

/// I caratteri disponibili. Quelli "per la dislessia" sono inclusi nell'app
/// con licenza SIL Open Font License (vedi Resources/Fonts/LICENSES.md).
enum TypefaceChoice: String, CaseIterable, Identifiable, Codable {
  case sistema, arrotondato, monospaziato, openDyslexic, atkinson, lexend

  var id: String { rawValue }

  var label: String {
    switch self {
    case .sistema: "Sistema"
    case .arrotondato: "Arrotondato"
    case .monospaziato: "Monospaziato"
    case .openDyslexic: "OpenDyslexic"
    case .atkinson: "Atkinson Hyperlegible"
    case .lexend: "Lexend"
    }
  }

  var hint: String {
    switch self {
    case .sistema: "Il carattere di serie del Mac."
    case .arrotondato: "Lettere più tonde, piacevoli per i più piccoli."
    case .monospaziato: "Tutte le lettere larghe uguali: aiuta a contarle."
    case .openDyslexic: "Lettere appesantite in basso, pensate per la dislessia."
    case .atkinson: "Disegnato per l'ipovisione: lettere simili molto diverse fra loro."
    case .lexend: "Studiato per leggere più in fretta con meno fatica."
    }
  }

  /// Il nome della famiglia installata, quando il carattere è incluso nell'app.
  var bundledFamily: String? {
    switch self {
    case .openDyslexic: "OpenDyslexic"
    case .atkinson: "Atkinson Hyperlegible"
    case .lexend: "Lexend"
    default: nil
    }
  }

  /// Vero se il file del carattere è davvero disponibile su questo Mac.
  var isAvailable: Bool {
    guard let family = bundledFamily else { return true }
    return FontLoader.availableFamilies.contains(family)
  }

  var design: Font.Design {
    switch self {
    case .arrotondato: .rounded
    case .monospaziato: .monospaced
    default: .default
    }
  }

  /// Il font concreto da usare, con ritorno al carattere di sistema se il file manca.
  func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    if let family = bundledFamily, FontLoader.availableFamilies.contains(family) {
      let bold = [Font.Weight.semibold, .bold, .heavy, .black].contains(weight)
      return .custom(FontLoader.postScriptName(for: family, bold: bold) ?? family, size: size)
    }
    return .system(size: size, weight: weight, design: design)
  }
}

/// Registra i caratteri inclusi nell'app all'avvio e tiene traccia di quali
/// sono davvero disponibili, così l'interfaccia non offre scelte che non funzionano.
enum FontLoader {

  /// I due elenchi stanno dietro un lucchetto solo.
  ///
  /// Sembrano innocui perché si riempiono una volta all'avvio e poi si leggono
  /// e basta, ed è esattamente il motivo per cui erano rimasti così. Ma chi li
  /// legge è chi disegna ogni schermata, e chi li scrive è l'avvio dell'app:
  /// se un giorno qualcuno registrasse un carattere mentre una schermata è
  /// già a video — un profilo che cambia, un carattere aggiunto a caldo — il
  /// risultato sarebbe un guasto che non lascia traccia e non si riproduce.
  /// Costa due righe evitarlo adesso.
  private struct Registro {
    var famiglie: Set<String> = []
    var nomiPostScript: [String: String] = [:]
  }

  private static let registro = Mutex(Registro())

  /// Le famiglie di caratteri che sono state davvero registrate, così
  /// l'interfaccia non offre scelte che non funzionano.
  static var availableFamilies: Set<String> { registro.withLock { $0.famiglie } }

  /// `da` serve solo al banco di prova che disegna le schermate: quello non ha
  /// un pacchetto applicazione, quindi senza questo parametro ripiegherebbe sul
  /// carattere di sistema e le immagini mostrerebbero una cosa diversa da
  /// quella che vede chi usa l'app — cioe' mentirebbero proprio su OpenDyslexic.
  static func registerBundledFonts(da cartella: URL? = nil) {
    guard let dir = cartella ?? Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
          let files = try? FileManager.default.contentsOfDirectory(at: dir,
                                                                   includingPropertiesForKeys: nil)
    else { return }

    for url in files where ["otf", "ttf"].contains(url.pathExtension.lowercased()) {
      var error: Unmanaged<CFError>?
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
      // Un errore qui di solito significa "già registrato": non è fatale.
      if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
        for d in descriptors {
          let family = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String
          let psName = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String
          registro.withLock { r in
            if let family { r.famiglie.insert(family) }
            if let family, let psName {
              let bold = psName.lowercased().contains("bold")
              r.nomiPostScript["\(family)|\(bold)"] = psName
              if r.nomiPostScript["\(family)|false"] == nil {
                r.nomiPostScript["\(family)|false"] = psName
              }
            }
          }
        }
      }
    }
  }

  static func postScriptName(for family: String, bold: Bool) -> String? {
    registro.withLock { r in
      r.nomiPostScript["\(family)|\(bold)"] ?? r.nomiPostScript["\(family)|false"]
    }
  }
}
