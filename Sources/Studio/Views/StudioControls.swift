import SwiftUI

private extension EnvironmentValues {
  @Entry var studioIsPrimary = false
}

struct StudioButton: View {
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  @Environment(\.studioIsPrimary) private var primary
  @Environment(\.isEnabled) private var enabled
  let title: String
  let icon: String
  let id: String
  let action: () -> Void

  init(_ title: String, icon: String, id: String = "", action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.id = id
    self.action = action
  }

  var body: some View {
    Group {
      if primary {
        BigButton(title: title, symbol: icon, a11y: a11y, action: action)
          .accessibilityIdentifier(id)
      } else {
        Button(action: action) {
          Label(title, systemImage: icon)
            .font(a11y.font(.etichetta, .semibold))
            .padding(.horizontal, a11y.size(Metrica.spazioMedio))
            .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
            .frame(minWidth: a11y.bersaglio, minHeight: a11y.bersaglio, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
        .foregroundStyle(palette.foreground)
        .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
          .stroke(palette.muted.opacity(0.35), lineWidth: 1.5))
        .accessibilityIdentifier(id)
      }
    }
    .opacity(enabled ? 1 : 0.55)
  }
}

struct StudioTextEditor: View {
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  @FocusState private var editing: Bool
  let title: String
  @Binding var text: String
  var id = ""

  var body: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
      Text(title).font(a11y.font(.corpo, .semibold))
      #if os(iOS)
      if editing {
        StudioButton("Fine scrittura", icon: "keyboard.chevron.compact.down", id: "studio.keyboard.done") {
          editing = false
        }
      }
      #endif
      TextEditor(text: $text)
        .font(a11y.font(.corpo))
        .foregroundStyle(palette.foreground)
        .scrollContentBackground(.hidden)
        .focused($editing)
        .frame(minHeight: a11y.size(140))
        .padding(Metrica.spazioMinimo)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
        .overlay(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).stroke(palette.muted))
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
  }
}

enum StudioFontRole {
  case largeTitle, title, title2, title3, headline, callout
}

private struct StudioFont: ViewModifier {
  @Environment(\.impostazioni) private var a11y
  let role: StudioFontRole
  let weight: Font.Weight

  private var font: Font {
    switch role {
    case .largeTitle: a11y.font(.titoloGrande, weight)
    case .title: a11y.font(.titolo, weight)
    case .title2, .title3: a11y.font(.guida, weight)
    case .headline: a11y.font(.corpo, .semibold)
    case .callout: a11y.font(.etichetta, weight)
    }
  }

  func body(content: Content) -> some View { content.font(font) }
}

private struct StudioMuted: ViewModifier {
  @Environment(\.palette) private var palette
  func body(content: Content) -> some View { content.foregroundStyle(palette.muted) }
}

extension View {
  func studioPrimary() -> some View { environment(\.studioIsPrimary, true) }
  func studioFont(_ role: StudioFontRole, weight: Font.Weight = .regular) -> some View {
    modifier(StudioFont(role: role, weight: weight))
  }
  func studioMuted() -> some View { modifier(StudioMuted()) }
}
