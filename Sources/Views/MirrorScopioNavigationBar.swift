import SwiftUI

struct MirrorScopioNavigationBar: View {
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  let name: String
  var onHome: (() -> Void)?
  let openSettings: () -> Void
  let openProgress: () -> Void
  let openAudioCheck: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Metrica.spazioPiccolo) {
        greeting
        Spacer()
        controls
      }
      VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
        greeting
        controls
      }
    }
    .padding(.horizontal, Metrica.spazio)
    .padding(.vertical, Metrica.spazioPiccolo)
  }

  @ViewBuilder private var greeting: some View {
    if let onHome {
      iconButton("house.fill", "Casa", id: "studio.shell.home", action: onHome)
    } else if !name.isEmpty {
      Text("Ciao, \(name)")
        .font(a11y.font(.corpo, .semibold))
        .foregroundStyle(palette.foreground)
    }
  }

  @ViewBuilder private var controls: some View {
    AudioMenu(a11y: a11y, palette: palette, openAudioCheck: openAudioCheck)
    iconButton("chart.line.uptrend.xyaxis", "I tuoi progressi", action: openProgress)
    iconButton("gearshape.fill", "Impostazioni", id: "studio.shell.settings", action: openSettings)
  }

  private func iconButton(_ symbol: String, _ label: String, id: String = "",
                          action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioMinimo) {
        Image(systemName: symbol)
        Text(label).font(a11y.font(.etichetta))
      }
      .padding(.horizontal, Metrica.spazioPiccolo)
      .frame(minHeight: a11y.bersaglio)
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(palette.muted)
    .accessibilityLabel(label)
    .accessibilityIdentifier(id)
  }
}
