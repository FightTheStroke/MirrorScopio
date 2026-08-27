import SwiftUI
import AppKit

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

  @State private var showCalibrationIntro = false
  @State private var aggiornamento: Updates.Release?

  private var a11y: A11ySettings { store.current.a11y }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      ScrollView {
        VStack(spacing: a11y.size(28)) {
          title
          bannerAggiornamento
          strisciaProgressi
          modePicker
          levels
          startArea
          warning
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
      }
    }
    .task {
      // In silenzio e senza fretta: se non c'è niente di nuovo, o il controllo
      // è spento, non se ne accorge nessuno.
      aggiornamento = try? await Updates.check()
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
      AudioMenu(a11y: a11y, palette: palette, openAudioCheck: openAudioCheck)
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

  // MARK: - Aggiornamenti

  /// Compare solo quando c'è davvero una versione nuova, e non fa niente da
  /// solo: dice che c'è e apre la pagina. Un programma che si sostituisce da
  /// sé mentre un ragazzo lo sta usando non è un servizio, è un'interruzione.
  @ViewBuilder
  private var bannerAggiornamento: some View {
    if let r = aggiornamento {
      HStack(spacing: a11y.size(14)) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: a11y.size(30)))
          .foregroundStyle(palette.accent)
        VStack(alignment: .leading, spacing: 3) {
          Text("C'è MirrorScopio \(r.version)")
            .font(a11y.typeface.font(size: a11y.size(19), weight: .semibold))
            .foregroundStyle(palette.foreground)
          Text("Tu hai la \(AppVersion.short). Si scarica dalla pagina delle release.")
            .font(a11y.typeface.font(size: a11y.size(15)))
            .foregroundStyle(palette.muted)
        }
        Spacer(minLength: 0)
        Button("Vai a prenderla") { NSWorkspace.shared.open(r.pageURL) }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        Button {
          aggiornamento = nil
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: a11y.size(15), weight: .semibold))
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.muted)
        .accessibilityLabel("nascondi l'avviso")
      }
      .padding(a11y.size(16))
      .background(RoundedRectangle(cornerRadius: 16).fill(palette.accent.opacity(0.12)))
    }
  }

  // MARK: - I progressi, subito

  /// Quanto si è arrivati, senza doverlo andare a cercare.
  ///
  /// Prima i progressi stavano dietro un'icona in alto: per vederli bisognava
  /// sapere che esistevano. Chi fa fatica ha bisogno di vedere **prima di
  /// cominciare** che sta andando da qualche parte — è quello che fa tornare
  /// domani. Compare solo quando c'è qualcosa da mostrare: una striscia vuota
  /// al primo avvio direbbe soltanto "sei a zero".
  @ViewBuilder
  private var strisciaProgressi: some View {
    let l = store.current
    if l.xp > 0 {
      Button(action: openProgress) {
        HStack(spacing: a11y.size(18)) {
          medaglia(livello: Gamification.level(xp: l.xp))

          VStack(alignment: .leading, spacing: 6) {
            Text(Gamification.levelName(Gamification.level(xp: l.xp)))
              .font(a11y.typeface.font(size: a11y.size(22), weight: .bold))
              .foregroundStyle(palette.foreground)

            ProgressView(value: Gamification.progressInLevel(l.xp))
              .progressViewStyle(.linear)
              .tint(palette.accent)
              .frame(maxWidth: 260)

            Text("\(Gamification.xpInLevel(l.xp)) punti verso il prossimo livello")
              .font(a11y.typeface.font(size: a11y.size(14)))
              .foregroundStyle(palette.muted)
          }

          Spacer(minLength: 0)

          if l.streakCurrent > 0 {
            datoBreve(numero: "\(l.streakCurrent)",
                      etichetta: l.streakCurrent == 1 ? "giorno di fila" : "giorni di fila",
                      simbolo: "flame.fill")
          }
          if !l.unlockedAchievements.isEmpty {
            datoBreve(numero: "\(l.unlockedAchievements.count)",
                      etichetta: l.unlockedAchievements.count == 1 ? "obiettivo" : "obiettivi",
                      simbolo: "star.fill")
          }
        }
        .padding(a11y.size(18))
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.surface))
        .contentShape(RoundedRectangle(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("i tuoi progressi: \(Gamification.levelName(Gamification.level(xp: l.xp))), \(l.xp) punti in tutto")
    }
  }

  private func medaglia(livello: Int) -> some View {
    ZStack {
      Circle().fill(palette.accent.opacity(0.18))
      Text("\(livello)")
        .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
        .foregroundStyle(palette.accent)
    }
    .frame(width: a11y.size(66), height: a11y.size(66))
    .accessibilityHidden(true)
  }

  private func datoBreve(numero: String, etichetta: String, simbolo: String) -> some View {
    VStack(spacing: 2) {
      HStack(spacing: 5) {
        Image(systemName: simbolo)
          .font(.system(size: a11y.size(17)))
        Text(numero)
          .font(a11y.typeface.font(size: a11y.size(26), weight: .bold))
      }
      .foregroundStyle(palette.accent)
      Text(etichetta)
        .font(a11y.typeface.font(size: a11y.size(13)))
        .foregroundStyle(palette.muted)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Velocità

  private var levels: some View {
    VStack(spacing: 10) {
      SectionTitle(text: engine.config.mode == .lettura ? "Quanto veloce?" : "Quanto difficile?", a11y: a11y)
      HStack(spacing: 10) {
        // Leggendo cresce la fretta, scrivendo cresce la complessità: sono due
        // scale diverse perché sono due fatiche diverse.
        if engine.config.mode == .lettura {
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
        } else {
          ForEach(WritingLevel.allCases) { level in
            ChoiceCard(title: level.title, subtitle: level.subtitle, symbol: level.symbol,
                       selected: engine.config.writingLevel == level, a11y: a11y) {
              engine.config.writingLevel = level
              level.apply(to: &engine.config)
              persist()
            }
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
      if c.writingLevel.isSentences {
        return "\(c.trials) frasi. Il Mac le dice, tu le scrivi. Puoi farle ripetere quante volte vuoi, e prima di consegnare puoi riascoltare parola per parola quello che hai scritto."
      }
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
        if let last = store.currentHistory.first, !last.missedWords.isEmpty {
          secondary("Riprendi le \(last.missedWords.count) rimaste", "arrow.counterclockwise") {
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
