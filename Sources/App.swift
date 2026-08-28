import SwiftUI

@main
struct MirrorScopioApp: App {
  @StateObject private var store = Store()
  @StateObject private var engine = SessionEngine()
  @StateObject private var readiness = Readiness()
  @StateObject private var nav = Navigazione()

  init() {
    FontLoader.registerBundledFonts()
  }

  var body: some Scene {
    WindowGroup("MirrorScopio") {
      RootView(store: store, engine: engine, readiness: readiness, nav: nav)
        .frame(minWidth: 900, minHeight: 700)
    }
    .defaultSize(width: 1100, height: 850)
    .commands {
      ComandiMenu(nav: nav, engine: engine)
    }
  }
}

/// Decide che cosa mostrare. Una schermata alla volta, mai due finestre:
/// l'app deve essere comprensibile da un bambino senza spiegazioni.
struct RootView: View {
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  @ObservedObject var readiness: Readiness
  @ObservedObject var nav: Navigazione
  @StateObject private var promemoria = Promemoria()
  /// Quello che chi usa il Mac ha già chiesto al Mac. Vive qui, in cima, così
  /// nessuna schermata può dimenticarsene: da qui scende nell'ambiente e ci
  /// arriva da sola.
  @StateObject private var mac = AccessibilitaDelMac()
  @Environment(\.colorScheme) private var systemScheme

  private var a11y: EffettiveImpostazioniAccessibilita {
    EffettiveImpostazioniAccessibilita(store.current.a11y, mac: mac.stato)
  }

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
    .background(FrameClock(attivo: engine.serveIlBattito) { engine.tick($0) }
      .frame(width: 0, height: 0))
    .environment(\.palette, palette)
    .environment(\.impostazioni, a11y)
    .tint(palette.accent)
    .preferredColorScheme(a11y.theme == .auto ? nil : (palette.isDark ? .dark : .light))
    .onAppear {
      syncEngine()
      // Al primo avvio si controlla da soli che il Mac abbia microfono, modello
      // vocale italiano e voce: meglio scoprirlo ora che a metà lettura.
      readiness.voceScelta = store.current.a11y.voiceIdentifier
      Task {
        await readiness.controlla()
        // Il primo avvio è una guida passo passo; dopo, si interviene solo se
        // manca qualcosa di necessario.
        if !UserDefaults.standard.bool(forKey: "onboardingFatto") {
          nav.schermata = .benvenuto
        } else if !readiness.puoIniziare, nav.schermata == .casa {
          nav.schermata = .preparazione
        }
        // I promemoria si riprogrammano a ogni avvio: così la giornata in cui
        // ci si è già allenati viene saltata invece di ricevere un invito
        // inutile.
        let giaFattoOggi = store.current.lastSessionDay == Gamification.dayKey(Date())
        await promemoria.ripianifica(
          giaFattoOggi: giaFattoOggi,
          serieGiorni: store.current.streakCurrent)
        // I promemoria sono accesi di serie, ma senza il permesso del Mac non
        // arriva niente: un interruttore acceso che non fa succedere nulla e'
        // una bugia. Chi ha gia' fatto il primo avvio non e' mai passato dalla
        // schermata che lo chiede, quindi glielo si chiede qui — mai prima,
        // che sarebbe la richiesta a freddo che si finisce per negare.
        await promemoria.aggiornaPermesso()
        if UserDefaults.standard.bool(forKey: "onboardingFatto"),
           promemoria.acceso, promemoria.permesso == .notDetermined {
          await promemoria.accendi(giaFattoOggi: giaFattoOggi,
                                   serieGiorni: store.current.streakCurrent)
        }
      }
    }
    .onChange(of: store.currentID) { _, _ in syncEngine() }
    .onChange(of: store.current.a11y) { _, _ in syncEngine() }
    // Il Mac può cambiare idea mentre l'app è aperta — «Riduci movimento» si
    // accende dalle Impostazioni di Sistema senza chiudere niente. Anche i
    // suoni devono accorgersene, non solo lo schermo.
    .onChange(of: mac.stato) { _, _ in syncEngine() }
  }

  @ViewBuilder
  private var content: some View {
    switch engine.phase {
    case .idle, .finished:
      if case .finished = engine.phase, engine.finishedRecord != nil {
        ReportView(engine: engine, store: store)
      } else if nav.mostraAiuto {
        // L'aiuto compare solo a riposo: sopra una lettura in corso
        // nasconderebbe la parola che lampeggia.
        AiutoView(store: store, onClose: { nav.mostraAiuto = false })
      } else {
        switch nav.schermata {
        case .casa:
          HomeView(engine: engine, store: store,
                   openSettings: { nav.schermata = .impostazioni },
                   openProgress: { nav.schermata = .progressi },
                   openAudioCheck: { nav.schermata = .audio },
                   openReadiness: { nav.schermata = .preparazione })
        case .impostazioni:
          SettingsView(store: store, engine: engine, onClose: { nav.schermata = .casa },
                       onCalibrate: { engine.startCalibration() },
                       onReadiness: { nav.schermata = .preparazione })
        case .progressi, .obiettivi:
          DashboardView(store: store, onClose: { nav.schermata = .casa })
        case .audio:
          AudioCheckView(store: store, onClose: { nav.schermata = .casa })
        case .benvenuto:
          OnboardingView(readiness: readiness, store: store, promemoria: promemoria, onFinish: {
            UserDefaults.standard.set(true, forKey: "onboardingFatto")
            nav.schermata = .casa
          }, onCalibrate: {
            UserDefaults.standard.set(true, forKey: "onboardingFatto")
            nav.schermata = .casa
            engine.startCalibration()
          })
        case .preparazione:
          ReadinessView(readiness: readiness, a11y: a11y,
                        onClose: { nav.schermata = .casa },
                        onContinue: { nav.schermata = .casa })
        }
      }

    case .instructions:
      InstructionsView(engine: engine, a11y: a11y, onFixMic: {
        engine.abort()
        nav.schermata = .audio
      })

    case .typing:
      TypingView(engine: engine, a11y: a11y)

    case .pausa:
      PauseView(engine: engine, a11y: a11y)

    default:
      StageView(engine: engine, a11y: a11y)
    }
  }

  private func syncEngine() {
    engine.a11y = a11y.perIlMotore
    engine.config = store.current.config
    readiness.voceScelta = a11y.voiceIdentifier
  }
}
