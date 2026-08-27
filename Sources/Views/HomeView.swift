import SwiftUI

/// La schermata di casa. Deve rispondere a tre domande in tre secondi:
/// che cosa fa questa app, che cosa devo fare io, dove premo per cominciare.
struct HomeView: View {
  @ObservedObject var engine: SessionEngine
  @ObservedObject var store: Store
  @Environment(\.palette) private var palette
  var openSettings: () -> Void
  var openProgress: () -> Void
  var openAudioCheck: () -> Void
  var openReadiness: () -> Void

  @State private var showAdvanced = false
  @State private var showCalibrationIntro = false

  private var a11y: A11ySettings { store.current.a11y }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      ScrollView {
        VStack(spacing: a11y.size(28)) {
          title
          modePicker
          levels
          startArea
          if !calibrated { calibrationInvite }
          warning
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
      }
    }
    .sheet(isPresented: $showAdvanced) {
      AdvancedSheet(store: store, engine: engine)
    }
  }

  // MARK: - Barra in alto

  private var topBar: some View {
    HStack(spacing: 12) {
      if !store.current.name.isEmpty {
        Text("Ciao, \(store.current.name)")
          .font(a11y.typeface.font(size: a11y.size(18), weight: .semibold))
          .foregroundStyle(palette.foreground)
      }
      Spacer()
      iconButton("waveform.badge.mic", "Mi senti?", action: openAudioCheck)
      iconButton("checklist", "Prepara il Mac", action: openReadiness)
      iconButton("chart.line.uptrend.xyaxis", "I tuoi progressi", action: openProgress)
      iconButton("gearshape.fill", "Impostazioni", action: openSettings)
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 14)
  }

  private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: symbol)
        Text(label).font(a11y.typeface.font(size: a11y.size(15)))
      }
      .padding(.horizontal, 12)
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.muted)
    .accessibilityLabel(label)
  }

  // MARK: - Che cos'è

  private var title: some View {
    VStack(spacing: a11y.size(14)) {
      Text("MirrorScopio")
        .font(a11y.typeface.font(size: a11y.size(48), weight: .bold))
        .foregroundStyle(palette.foreground)

      Text(engine.config.mode.childHint)
        .font(a11y.typeface.font(size: a11y.size(21)))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 6)
  }

  // MARK: - Leggi o scrivi

  private var modePicker: some View {
    VStack(spacing: 10) {
      SectionTitle(text: "Che cosa vuoi allenare?", a11y: a11y)
      HStack(spacing: 12) {
        ForEach(SessionMode.allCases) { mode in
          ChoiceCard(title: mode.label, subtitle: mode.childHint, symbol: mode.symbol,
                     selected: engine.config.mode == mode, a11y: a11y) {
            engine.config.mode = mode
            persist()
          }
        }
      }
    }
  }

  // MARK: - Velocità

  private var levels: some View {
    VStack(spacing: 10) {
      SectionTitle(text: engine.config.mode == .lettura ? "Quanto veloce?" : "Quanto difficile?", a11y: a11y)
      HStack(spacing: 10) {
        ForEach(Level.allCases.filter { $0 != .personalizzato }) { level in
          ChoiceCard(title: level.title,
                     subtitle: level.subtitle(for: engine.config.mode),
                     symbol: level.symbol,
                     selected: engine.config.level == level, a11y: a11y) {
            engine.config.level = level
            level.apply(to: &engine.config)
            persist()
          }
        }
      }
      Explain(text: summaryLine, a11y: a11y, size: 15)
        .multilineTextAlignment(.leading)
    }
  }

  private var summaryLine: String {
    let c = engine.config
    if c.mode == .scrittura {
      return "\(c.trials) parole dalla lista «\(c.set.label.lowercased())». Il Mac le dice, tu le scrivi. Puoi farle ripetere quante volte vuoi."
    }
    return "\(c.trials) parole dalla lista «\(c.set.label.lowercased())». Le prime \(c.warmupTrials) restano a lungo, per prendere la mano. Poi va più veloce solo se indovini."
  }

  // MARK: - Comincia

  private var startArea: some View {
    VStack(spacing: 12) {
      BigButton(title: "Via!", symbol: "play.fill", a11y: a11y) {
        persist()
        engine.start()
      }
      .keyboardShortcut(.return, modifiers: [])

      HStack(spacing: 12) {
        secondary("Impostazioni avanzate", "slider.horizontal.3") { showAdvanced = true }
        if let last = store.currentHistory.first, !last.missedWords.isEmpty {
          secondary("Ripassa le \(last.missedWords.count) sbagliate", "arrow.counterclockwise") {
            persist()
            engine.start(words: last.missedWords)
          }
        }
      }

      if !engine.statusMessage.isEmpty {
        Explain(text: engine.statusMessage, a11y: a11y, size: 15)
          .multilineTextAlignment(.center)
      }
    }
  }

  private func secondary(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: symbol)
        Text(title).font(a11y.typeface.font(size: a11y.size(15)))
      }
      .padding(.horizontal, 14)
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.muted)
  }

  // MARK: - Prova iniziale

  private var calibrated: Bool { store.current.calibratedExposureMs != nil }

  private var calibrationInvite: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Prima volta? Facciamo una prova veloce", systemImage: "wand.and.stars")
        .font(a11y.typeface.font(size: a11y.size(19), weight: .semibold))
        .foregroundStyle(palette.foreground)
      Explain(text: "Otto parole, meno di un minuto. Serve al Mac per capire da che velocità partire con te: né troppo facile da annoiarti, né troppo difficile da scoraggiarti.", a11y: a11y, size: 15)
      BigButton(title: "Fai la prova", symbol: "checkmark.seal.fill", a11y: a11y, prominent: false) {
        persist()
        engine.startCalibration()
      }
    }
    .padding(18)
    .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
  }

  private var warning: some View {
    Explain(text: engine.config.mode == .lettura
            ? "Le parole lampeggiano sullo schermo: non usare con epilessia fotosensibile senza parere medico."
            : "Alza il volume: il Mac dice le parole ad alta voce.",
            a11y: a11y, size: 13)
    .multilineTextAlignment(.center)
  }

  private func persist() {
    var l = store.current
    l.config = engine.config
    store.current = l
  }
}
