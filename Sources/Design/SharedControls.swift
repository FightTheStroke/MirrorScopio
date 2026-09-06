import SwiftUI

/// Le misure originali dell'app, condivise senza varianti fra Mac e iOS.
enum Metrica {
  static let raggioMinimo: CGFloat = 3
  static let raggioPiccolo: CGFloat = 10
  static let raggio: CGFloat = 14
  static let raggioGrande: CGFloat = 18
  static let filo: CGFloat = 2
  static let briciola: CGFloat = 4
  static let spazioMinimo: CGFloat = 6
  static let spazioStretto: CGFloat = 8
  static let spazioPiccolo: CGFloat = 12
  static let spazioMedio: CGFloat = 16
  static let spazio: CGFloat = 20
  static let spazioLargo: CGFloat = 24
  static let spazioGrande: CGFloat = 32
  static let spazioEnorme: CGFloat = 40
  static let margine: CGFloat = 26
  static let bersaglio: CGFloat = 44
}

/// La forma di un pulsante: serve all'anello di fuoco per stare aderente.
enum FormaPulsante {
  case capsula
  case arrotondata(CGFloat)
  case rettangolo
}

/// Lo stile originale: fuoco visibile anche senza navigazione da tastiera di sistema.
struct StilePulsante: ButtonStyle {
  var forma: FormaPulsante = .rettangolo
  var a11y: EffettiveImpostazioniAccessibilita = EffettiveImpostazioniAccessibilita()

  func makeBody(configuration: Configuration) -> some View {
    Corpo(configuration: configuration, forma: forma, a11y: a11y)
  }

  private struct Corpo: View {
    let configuration: Configuration
    let forma: FormaPulsante
    let a11y: EffettiveImpostazioniAccessibilita
    @Environment(\.isFocused) private var aFuoco
    @Environment(\.palette) private var palette

    var body: some View {
      configuration.label
        .opacity(configuration.isPressed ? 0.55 : 1)
        .focusable()
        .overlay { if aFuoco { bordo(palette.background, spessore: 2, fuori: 2) } }
        .overlay { if aFuoco { bordo(palette.accent, spessore: 3, fuori: 5) } }
        .animation(a11y.animation(0.12), value: aFuoco)
    }

    @ViewBuilder
    private func bordo(_ colore: Color, spessore: CGFloat, fuori: CGFloat) -> some View {
      switch forma {
      case .capsula:
        Capsule().strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      case .arrotondata(let raggio):
        RoundedRectangle(cornerRadius: raggio + fuori)
          .strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      case .rettangolo:
        RoundedRectangle(cornerRadius: Metrica.raggioMinimo + fuori)
          .strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      }
    }
  }
}

/// Il bottone di servizio, con testo e sfondo sempre presi dal tema.
struct SmallButton: View {
  @Environment(\.palette) private var palette
  let title: String
  var symbol: String? = nil
  var a11y: EffettiveImpostazioniAccessibilita
  var distruttivo = false
  var prominente = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioStretto) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.font(.etichetta, .semibold))
      .padding(.horizontal, a11y.size(Metrica.spazioMedio))
      .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
      #if os(iOS)
      .frame(minWidth: a11y.bersaglio, minHeight: a11y.bersaglio)
      #endif
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(prominente ? palette.onAccent
                     : (distruttivo ? palette.wrong : palette.foreground))
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
      .fill(prominente ? palette.accent : palette.surface))
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
        .stroke(prominente ? .clear
                : (distruttivo ? palette.wrong.opacity(0.5) : palette.muted.opacity(0.35)),
                lineWidth: 1.5))
    .frame(minHeight: Metrica.bersaglio)
    #if os(iOS)
    .fixedSize(horizontal: false, vertical: true)
    #else
    .fixedSize(horizontal: true, vertical: false)
    #endif
  }
}

/// Il pulsante principale: il contrasto del testo è quello di `onAccent`, mai un bianco fisso.
struct BigButton: View {
  @Environment(\.palette) private var palette
  let title: String
  var symbol: String? = nil
  var a11y: EffettiveImpostazioniAccessibilita
  var prominent = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioPiccolo) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
          #if os(iOS)
          .fixedSize(horizontal: false, vertical: true)
          #endif
      }
      .font(a11y.font(.titolo, .bold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(Metrica.spazio))
      #if os(iOS)
      .frame(minHeight: a11y.bersaglio)
      #endif
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggio), a11y: a11y))
    .foregroundStyle(prominent ? palette.onAccent : palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .fill(prominent ? palette.accent : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .stroke(prominent ? .clear : palette.muted.opacity(0.35), lineWidth: 2)
    )
    .frame(minHeight: 56)
  }
}

/// Una scelta grande: selezione indicata anche da simbolo e parola, non solo dal colore.
struct ChoiceCard: View {
  @Environment(\.palette) private var palette
  let title: String
  var subtitle: String? = nil
  var symbol: String? = nil
  let selected: Bool
  var a11y: EffettiveImpostazioniAccessibilita
  let action: () -> Void

  private var selezioneOpaca: Bool {
    #if os(iOS)
    selected && a11y.menoTrasparenza
    #else
    false
    #endif
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: Metrica.spazioStretto) {
        if let symbol {
          Image(systemName: symbol).font(.system(size: a11y.size(30)))
        }
        Text(title)
          .font(a11y.font(.guida, .semibold))
          .interlinea(a11y)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle {
          Text(subtitle)
            .font(a11y.font(.nota))
            .interlinea(a11y)
            .foregroundStyle(selezioneOpaca ? palette.onAccent : palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      #if os(iOS)
      // Lascia spazio alla spunta anche quando il titolo va a capo sul telefono.
      .padding(.horizontal, a11y.size(18))
      #endif
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical, a11y.size(Metrica.spazioMedio))
      .padding(.horizontal, Metrica.spazioStretto)
      #if os(iOS)
      .frame(minHeight: a11y.bersaglio)
      #endif
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggio), a11y: a11y))
    .foregroundStyle(selezioneOpaca ? palette.onAccent : palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .fill(selected ? palette.accent.opacity(a11y.velo(palette.isDark ? 0.32 : 0.16))
                       : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .stroke(selected ? palette.accent : Color.clear, lineWidth: 3)
    )
    .overlay(alignment: .topTrailing) {
      if selected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: a11y.size(18)))
          .foregroundStyle(selezioneOpaca ? palette.onAccent : palette.accent)
          .padding(Metrica.spazioStretto)
          .accessibilityHidden(true)
      }
    }
    .frame(minHeight: 64)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    .accessibilityValue(selected ? "scelto" : "")
  }
}

struct SectionTitle: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: EffettiveImpostazioniAccessibilita

  var body: some View {
    Text(text)
      .font(a11y.font(.sezione, .bold))
      .foregroundStyle(palette.foreground)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct Explain: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: EffettiveImpostazioniAccessibilita
  var size: Double = 17

  var body: some View {
    Text(.init(text))
      .font(a11y.typeface.font(size: a11y.size(size)))
      .interlinea(a11y)
      .foregroundStyle(palette.muted)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
