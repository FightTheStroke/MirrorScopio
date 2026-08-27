import SwiftUI

// MARK: - Profili di accessibilità

/// Un profilo imposta in un colpo solo carattere, dimensioni, colori e ritmo.
/// Ereditato da MirrorBuddy (`lib/accessibility/accessibility-store/profiles.ts`),
/// tradotto per un'app nativa e per un compito di lettura rapida.
enum A11yProfile: String, CaseIterable, Identifiable, Codable {
  case nessuno, dislessia, autismo, adhd, ipovisione, paralisiCerebrale

  var id: String { rawValue }

  var label: String {
    switch self {
    case .nessuno: "Nessuno in particolare"
    case .dislessia: "Dislessia"
    case .autismo: "Autismo"
    case .adhd: "ADHD"
    case .ipovisione: "Vedo poco"
    case .paralisiCerebrale: "Paralisi cerebrale"
    }
  }

  var symbol: String {
    switch self {
    case .nessuno: "person.fill"
    case .dislessia: "textformat.abc"
    case .autismo: "leaf.fill"
    case .adhd: "target"
    case .ipovisione: "eye.fill"
    case .paralisiCerebrale: "figure.roll"
    }
  }

  /// Che cosa cambia davvero, detto senza gergo.
  var hint: String {
    switch self {
    case .nessuno: "Impostazioni standard."
    case .dislessia: "Carattere OpenDyslexic, lettere più distanziate, sfondo crema, più tempo."
    case .autismo: "Niente animazioni né sorprese, colori calmi, ritmo sempre uguale, pause regolari."
    case .adhd: "Schermo pulito, sessioni corte, pause frequenti, niente distrazioni ai bordi."
    case .ipovisione: "Tutto molto più grande, altissimo contrasto, parola letta ad alta voce."
    case .paralisiCerebrale: "Tutto grande, più tempo per rispondere, si usa solo la voce o pochi tasti."
    }
  }

  func apply(to s: inout A11ySettings) {
    // Si riparte sempre dai valori standard, così i profili non si sommano fra loro.
    s = A11ySettings()
    switch self {
    case .nessuno:
      break
    case .dislessia:
      s.typeface = .openDyslexic
      s.letterSpacing = 6
      s.textScale = 1.15
      s.theme = .sabbia
      s.extraResponseTime = 1.3
    case .autismo:
      s.reducedMotion = true
      s.calmMode = true
      s.showFeedbackPerWord = true
      s.soundsEnabled = false
      s.pauseEveryNWords = 5
      s.textScale = 1.1
      s.theme = .chiaro
    case .adhd:
      s.distractionFree = true
      s.pauseEveryNWords = 5
      s.reducedMotion = true
      s.shorterSessions = true
    case .ipovisione:
      s.typeface = .atkinson
      s.textScale = 1.45
      s.theme = .altoContrasto
      s.speakCorrectWord = true
      s.letterSpacing = 4
    case .paralisiCerebrale:
      s.textScale = 1.3
      s.extraResponseTime = 1.6
      s.reducedMotion = true
      s.speakCorrectWord = true
    }
    s.profile = self
  }
}

/// Tutte le preferenze che riguardano *come* si vede e si usa l'app,
/// separate dai parametri clinici della prova.
struct A11ySettings: Codable, Equatable {
  var profile: A11yProfile = .nessuno

  // Aspetto
  var theme: ThemeChoice = .auto
  var colorVision: ColorVision = .standard
  var typeface: TypefaceChoice = .arrotondato
  /// Moltiplica ogni dimensione di testo dell'interfaccia. 1.0 = già grande.
  var textScale: Double = 1.0
  /// Spazio extra fra le lettere della parola-stimolo, in punti.
  var letterSpacing: Double = 2
  /// Dimensione della parola-stimolo, in punti.
  var stimulusSize: Double = 120

  // Ritmo e sensorialità
  var reducedMotion = false
  /// Niente colori accesi, niente esclamazioni, nessun elemento che compare a sorpresa.
  var calmMode = false
  /// Toglie tutto ciò che non serve dai bordi dello schermo durante la prova.
  var distractionFree = false
  var soundsEnabled = false
  /// Ogni quante parole proporre una pausa. 0 = mai.
  var pauseEveryNWords = 0
  /// Sessioni più corte (usato dal profilo ADHD).
  var shorterSessions = false
  /// Moltiplica il tempo concesso per rispondere.
  var extraResponseTime: Double = 1.0

  // Feedback
  var showFeedbackPerWord = true
  /// Nasconde punteggi, percentuali e stelle: per chi si mette in ansia.
  var hideScore = false
  /// A fine parola il Mac pronuncia la parola giusta.
  var speakCorrectWord = false

  /// Dimensione di un testo dell'interfaccia, già scalata.
  func size(_ base: Double) -> CGFloat { CGFloat(base * textScale) }

  /// Durata di un'animazione: zero quando il movimento va evitato.
  func animation(_ base: Double = 0.25) -> Animation? {
    reducedMotion ? nil : .easeOut(duration: base)
  }
}
