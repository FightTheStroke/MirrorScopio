import SwiftUI

@main
struct MirrorScopioApp: App {
  @StateObject private var store = Store()
  @StateObject private var engine = SessionEngine()

  init() {
    FontLoader.registerBundledFonts()
  }

  var body: some Scene {
    WindowGroup("MirrorScopio") {
      RootView(store: store, engine: engine)
        .frame(minWidth: 900, minHeight: 700)
    }
    .defaultSize(width: 1100, height: 850)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}

/// Decide che cosa mostrare. Una schermata alla volta, mai due finestre:
/// l'app deve essere comprensibile da un bambino senza spiegazioni.
struct RootView: View {
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  @Environment(\.colorScheme) private var systemScheme

  @State private var screen: Screen = .casa

  enum Screen: Equatable { case casa, impostazioni, progressi, obiettivi }

  private var a11y: A11ySettings { store.current.a11y }

  private var palette: Palette {
    Palette.resolve(theme: a11y.theme, vision: a11y.colorVision, system: systemScheme)
  }

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()
      content
    }
    // L'orologio dei frame vive qui e non nella schermata di presentazione, così
    // il livello del microfono si vede già durante la prova iniziale.
    .background(FrameClock { engine.tick($0) }.frame(width: 0, height: 0))
    .environment(\.palette, palette)
    .tint(palette.accent)
    .preferredColorScheme(a11y.theme == .auto ? nil : (palette.isDark ? .dark : .light))
    .onAppear { syncEngine() }
    .onChange(of: store.currentID) { _, _ in syncEngine() }
    .onChange(of: store.current.a11y) { _, new in engine.a11y = new }
  }

  @ViewBuilder
  private var content: some View {
    switch engine.phase {
    case .idle, .finished:
      if case .finished = engine.phase, engine.finishedRecord != nil {
        ReportView(engine: engine, store: store)
      } else {
        switch screen {
        case .casa:
          HomeView(engine: engine, store: store,
                   openSettings: { screen = .impostazioni },
                   openProgress: { screen = .progressi })
        case .impostazioni:
          SettingsView(store: store, engine: engine, onClose: { screen = .casa })
        case .progressi, .obiettivi:
          DashboardView(store: store, onClose: { screen = .casa })
        }
      }

    case .instructions:
      InstructionsView(engine: engine, a11y: a11y)

    case .typing:
      TypingView(engine: engine, a11y: a11y)

    case .pausa:
      PauseView(engine: engine, a11y: a11y)

    default:
      StageView(engine: engine, a11y: a11y)
    }
  }

  private func syncEngine() {
    engine.a11y = store.current.a11y
    engine.config = store.current.config
  }
}
