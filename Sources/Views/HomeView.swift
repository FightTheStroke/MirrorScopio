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
  /// Dove arriva la tastiera appena si apre la schermata.
  ///
  /// Prima non arrivava da nessuna parte: si apriva l'app, si premeva Tab e il
  /// primo salto finiva su un'icona di servizio in alto a destra. Chi usa solo
  /// la tastiera doveva attraversare mezza pagina per trovare «Via!», che è
  /// l'unica cosa che quella schermata serve a fare.
  @FocusState private var fuoco: Fuoco?
  private enum Fuoco: Hashable { case via }

  @Environment(\.impostazioni) private var a11y

  var body: some View {
    VStack(spacing: 0) {
      topBar
      ScrollView {
        VStack(spacing: a11y.size(Metrica.spazioLargo)) {
          title
          bannerAggiornamento
          strisciaProgressi
          modePicker
          levels
          startArea
          warning
        }
        .padding(.horizontal, Metrica.spazioEnorme)
        .padding(.bottom, Metrica.spazioEnorme)
        .frame(maxWidth: a11y.size(860))
        .frame(maxWidth: .infinity)
      }
    }
    .defaultFocus($fuoco, .via)
    .task {
      // In silenzio e senza fretta: se non c'è niente di nuovo, o il controllo
      // è spento, non se ne accorge nessuno.
      aggiornamento = try? await Updates.check()
    }
  }

  // MARK: - Barra in alto

  private var topBar: some View {
    HStack(spacing: Metrica.spazioPiccolo) {
      if !store.current.name.isEmpty {
        Text("Ciao, \(store.current.name)")
          .font(a11y.font(.corpo, .semibold))
          .foregroundStyle(palette.foreground)
      }
      Spacer()
      AudioMenu(a11y: a11y, palette: palette, openAudioCheck: openAudioCheck)
      iconButton("chart.line.uptrend.xyaxis", "I tuoi progressi", action: openProgress)
      iconButton("gearshape.fill", "Impostazioni", action: openSettings)
    }
    .padding(.horizontal, Metrica.spazio)
    .padding(.vertical, Metrica.spazioPiccolo)
  }

  private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioMinimo) {
        Image(systemName: symbol)
        Text(label).font(a11y.font(.etichetta))
      }
      .padding(.horizontal, Metrica.spazioPiccolo)
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(palette.muted)
    .accessibilityLabel(label)
  }

  // MARK: - Che cos'è

  private var title: some View {
    VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
      Text("MirrorScopio")
        .font(a11y.font(.titoloGrande, .bold))
        .foregroundStyle(palette.foreground)

      Text(engine.config.mode.childHint)
        .font(a11y.font(.guida))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, Metrica.spazioMinimo)
  }

  // MARK: - Leggi o scrivi

  private var modePicker: some View {
    VStack(spacing: Metrica.spazioStretto) {
      SectionTitle(text: "Che cosa vuoi allenare?", a11y: a11y)
      HStack(spacing: Metrica.spazioPiccolo) {
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
  /// solo. Non installa neanche da qui: questa è la schermata del ragazzo, e
  /// scegliere di sostituire l'app non è una cosa che tocca a lui. Il pulsante
  /// porta dove quella decisione ha senso, cioè nelle impostazioni dell'adulto.
  @ViewBuilder
  private var bannerAggiornamento: some View {
    if let r = aggiornamento {
      HStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: a11y.size(30)))
          .foregroundStyle(palette.accent)
        VStack(alignment: .leading, spacing: Metrica.filo) {
          Text("C'è MirrorScopio \(r.version)")
            .font(a11y.font(.guida, .semibold))
            .foregroundStyle(palette.foreground)
          Text("Tu hai la \(AppVersion.short). La installa un adulto dalle impostazioni.")
            .font(a11y.font(.etichetta))
            .foregroundStyle(palette.muted)
        }
        Spacer(minLength: 0)
        SmallButton(title: "Apri le impostazioni", a11y: a11y, prominente: true) {
          openSettings()
        }
        Button {
          aggiornamento = nil
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: a11y.size(15), weight: .semibold))
            .frame(width: Metrica.bersaglio, height: Metrica.bersaglio)
            .contentShape(Rectangle())
        }
        .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
        .foregroundStyle(palette.muted)
        .accessibilityLabel("nascondi l'avviso")
      }
      .padding(a11y.size(Metrica.spazioMedio))
      .background(RoundedRectangle(cornerRadius: Metrica.raggio).fill(palette.accent.opacity(0.12)))
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
  /// I progressi stanno in home, sempre — anche quando non c'e ancora niente
  /// da mostrare.
  ///
  /// Prima comparivano solo dopo la prima sessione: chi apriva l'app per la
  /// prima volta non sapeva nemmeno che esistessero, e proprio a lui serve
  /// sapere che quello che fa lascia un segno da qualche parte. A zero punti
  /// la striscia dice come si comincia, invece di sparire.
  private var strisciaProgressi: some View {
    let l = store.current
    let iniziato = l.xp > 0
    Button(action: openProgress) {
        HStack(spacing: a11y.size(Metrica.spazioMedio)) {
          medaglia(livello: Gamification.level(xp: l.xp))

          VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
            Text(iniziato ? Gamification.levelName(Gamification.level(xp: l.xp))
                          : "Si comincia da qui")
              .font(a11y.font(.guida, .bold))
              .foregroundStyle(palette.foreground)

            ProgressView(value: iniziato ? Gamification.progressInLevel(l.xp) : 0)
              .progressViewStyle(.linear)
              .tint(palette.accent)
              .frame(maxWidth: a11y.size(260))

            Text(iniziato
                 ? "\(Gamification.xpInLevel(l.xp)) punti verso il prossimo livello"
                 : "I primi punti arrivano con la prima sessione. Non serve indovinare tutto: basta arrivare in fondo.")
              .font(a11y.font(.nota))
              .foregroundStyle(palette.muted)
              .fixedSize(horizontal: false, vertical: true)
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
        .padding(a11y.size(Metrica.spazioMedio))
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrica.raggioGrande).fill(palette.surface))
        .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioGrande))
      }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioGrande), a11y: a11y))
    .accessibilityLabel(iniziato
      ? "i tuoi progressi: \(Gamification.levelName(Gamification.level(xp: l.xp))), \(l.xp) punti in tutto"
      : "i tuoi progressi: non hai ancora cominciato")
  }

  private func medaglia(livello: Int) -> some View {
    // Lo stesso distintivo di fascia della pagina dei progressi, così la home
    // e la dashboard raccontano la stessa salita. Il numero resta nel gettone
    // perché in home non è scritto da nessun'altra parte.
    DistintivoLivello(livello: livello, diametro: 66, numero: livello, a11y: a11y, palette: palette)
      .accessibilityHidden(true)
  }

  private func datoBreve(numero: String, etichetta: String, simbolo: String) -> some View {
    VStack(spacing: Metrica.filo) {
      HStack(spacing: Metrica.briciola) {
        Image(systemName: simbolo)
          .font(.system(size: a11y.size(17)))
        Text(numero)
          .font(a11y.font(.sezione, .bold))
      }
      .foregroundStyle(palette.accent)
      Text(etichetta)
        .font(a11y.font(.nota))
        .foregroundStyle(palette.muted)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Velocità

  private var levels: some View {
    VStack(spacing: Metrica.spazioStretto) {
      SectionTitle(text: engine.config.mode == .lettura ? "Quanto veloce?" : "Quanto difficile?", a11y: a11y)
      HStack(spacing: Metrica.spazioStretto) {
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
    VStack(spacing: Metrica.spazioPiccolo) {
      BigButton(title: "Via!", symbol: "play.fill", a11y: a11y) {
        persist()
        engine.start()
      }
      .focused($fuoco, equals: .via)
      .keyboardShortcut(.return, modifiers: [])

      HStack(spacing: Metrica.spazioPiccolo) {
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
      HStack(spacing: Metrica.spazioMinimo) {
        Image(systemName: symbol)
        Text(title).font(a11y.font(.etichetta))
      }
      .padding(.horizontal, Metrica.spazioPiccolo)
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
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
