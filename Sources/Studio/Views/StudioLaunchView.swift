import SwiftUI

struct StudioLaunchView: View {
  @ObservedObject var store: StudioStore
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  @FocusState private var startFocused: Bool
  let open: (StudioDestination) -> Void

  private var next: StudioNextStep? { StudioPathEngine.next(in: store.displayArchive, now: Date()) }

  var body: some View {
    VStack(spacing: a11y.size(Metrica.spazio)) {
      VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
        Text(next?.title ?? StudioOrientation.trialTitle)
          .font(a11y.font(.titolo, .bold))
          .foregroundStyle(palette.foreground)
          .multilineTextAlignment(.center)
          .accessibilityIdentifier("studio.suggestion")
        Text(next?.reason ?? StudioOrientation.trialExplanation)
          .font(a11y.font(.guida))
          .foregroundStyle(palette.muted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      BigButton(title: next?.action ?? "Inizia", symbol: "play.fill", a11y: a11y) {
        if StudioRuntime.shared.startGuided() { open(.guided) }
      }
      .focused($startFocused)
      .accessibilityIdentifier("studio.start")
      .disabled(store.recovery || store.hasPendingSave)
      if let error = store.error {
        Text(error).foregroundStyle(palette.wrong)
        StudioButton("Riprova a salvare", icon: "arrow.clockwise") { store.retry() }
      }
      Text(StudioOrientation.showsInstructions(in: store.displayArchive)
           ? StudioOrientation.parentExplanation
           : "Leggi o ascolta. Gli aiuti restano con te e puoi fermarti quando vuoi.")
        .font(a11y.font(.etichetta))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.center)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Metrica.spazioPiccolo) { links }.fixedSize(horizontal: true, vertical: false)
        VStack(spacing: Metrica.spazioPiccolo) { links }
      }
    }
    .defaultFocus($startFocused, true)
  }

  @ViewBuilder private var links: some View {
    StudioButton("Le mie lezioni", icon: "books.vertical", id: "studio.library") { open(.library) }
    StudioButton("Per il genitore", icon: "person.crop.circle", id: "studio.parent") { open(.path) }
    StudioButton("Aiuto sullo studio", icon: "questionmark.circle", id: "studio.help") { open(.help) }
  }
}
