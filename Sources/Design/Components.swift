import SwiftUI

// MARK: - Mattoncini condivisi

/// Il pulsante principale di una schermata: enorme, con un'icona e una parola sola.
/// Grande davvero, non "grande per un'app per adulti".
struct BigButton: View {
  @Environment(\.palette) private var palette
  let title: String
  var symbol: String? = nil
  var a11y: A11ySettings
  var prominent = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(20))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(prominent ? Color.white : palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(prominent ? palette.accent : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(prominent ? .clear : palette.muted.opacity(0.35), lineWidth: 2)
    )
    .frame(minHeight: 56)
  }
}

/// Una scelta fra poche, presentata come una carta cliccabile grande.
struct ChoiceCard: View {
  @Environment(\.palette) private var palette
  let title: String
  var subtitle: String? = nil
  var symbol: String? = nil
  let selected: Bool
  var a11y: A11ySettings
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        if let symbol {
          Image(systemName: symbol).font(.system(size: a11y.size(30)))
        }
        Text(title)
          .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
          .multilineTextAlignment(.center)
        if let subtitle {
          Text(subtitle)
            .font(a11y.typeface.font(size: a11y.size(13)))
            .foregroundStyle(palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(18))
      .padding(.horizontal, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(selected ? palette.accent.opacity(palette.isDark ? 0.32 : 0.16) : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(selected ? palette.accent : Color.clear, lineWidth: 3)
    )
    // Il bordo da solo non basta: chi non distingue i colori deve poterlo capire lo stesso.
    .overlay(alignment: .topTrailing) {
      if selected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: a11y.size(18)))
          .foregroundStyle(palette.accent)
          .padding(8)
      }
    }
    .frame(minHeight: 64)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}

/// Titolo di sezione, sempre della stessa taglia in tutta l'app.
struct SectionTitle: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: A11ySettings

  var body: some View {
    Text(text)
      .font(a11y.typeface.font(size: a11y.size(24), weight: .bold))
      .foregroundStyle(palette.foreground)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Riga di testo esplicativo. Serve a dire *perché*, mai a riempire.
struct Explain: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: A11ySettings
  var size: Double = 17

  var body: some View {
    Text(.init(text))
      .font(a11y.typeface.font(size: a11y.size(size)))
      .foregroundStyle(palette.muted)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Esito di una parola: colore *e* simbolo *e* parola. Mai il colore da solo.
struct Verdict: View {
  @Environment(\.palette) private var palette
  let correct: Bool
  var a11y: A11ySettings
  var size: Double = 20

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: correct ? ColorVision.okSymbol : ColorVision.wrongSymbol)
      Text(correct ? "giusta" : "sbagliata")
    }
    .font(a11y.typeface.font(size: a11y.size(size), weight: .semibold))
    .foregroundStyle(correct ? palette.ok : palette.wrong)
    .accessibilityLabel(correct ? "risposta giusta" : "risposta sbagliata")
  }
}

/// Il pulsante per fermarsi.
///
/// Prima era una scritta grigia di 16 punti in un angolo: per chi ha ipovisione
/// era invisibile, per chi ha difficoltà di controllo del movimento era un
/// bersaglio troppo piccolo da colpire. Fermarsi deve essere la cosa più facile
/// dello schermo, non la più difficile: se l'unica via d'uscita è nascosta, chi
/// è in difficoltà resta intrappolato in un esercizio che non regge più.
///
/// Ha la forma del comando di registrazione che si trova ovunque — cerchio
/// pieno, quadrato dentro — perché quella forma si riconosce senza leggere e
/// senza distinguere i colori. Il rosso è **suo**, diverso dal rosso delle
/// risposte sbagliate: smettere non è sbagliare, e i due gesti non devono
/// somigliarsi.
struct StopButton: View {
  @Environment(\.palette) private var palette
  var a11y: A11ySettings
  var titolo = "Basta"
  let action: () -> Void

  private var rosso: Color {
    palette.isDark
      ? Color(red: 1.0, green: 0.36, blue: 0.36)
      : Color(red: 0.85, green: 0.13, blue: 0.16)
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: a11y.size(10)) {
        ZStack {
          Circle().fill(rosso)
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.white)
            .frame(width: a11y.size(16), height: a11y.size(16))
        }
        .frame(width: a11y.size(38), height: a11y.size(38))

        Text(titolo)
          .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
      }
      .padding(.horizontal, a11y.size(16))
      .padding(.vertical, a11y.size(8))
      // 60 punti: la soglia dei 44 di Apple è il minimo per una mano ferma.
      .frame(minHeight: max(60, a11y.size(56)))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.foreground)
    .background(Capsule().fill(palette.surface))
    .overlay(Capsule().stroke(rosso.opacity(0.55), lineWidth: 2))
    .accessibilityLabel("interrompi la sessione")
  }
}
