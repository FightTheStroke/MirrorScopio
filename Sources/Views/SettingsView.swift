import SwiftUI

/// Le impostazioni che contano davvero: come si vede e come si sente l'app.
/// Prima i profili (una scelta sola cambia tutto), poi le regolazioni fini.
struct SettingsView: View {
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  @Environment(\.palette) private var palette
  var onClose: () -> Void
  var onCalibrate: () -> Void = {}
  var onReadiness: () -> Void = {}

  @StateObject private var promemoria = Promemoria()
  @State private var pagina: Pagina = .inizio
  @State private var chiedeCancellazione = false
  @State private var aggiornamentiAccesi = Updates.enabled
  @State private var controlloInCorso = false
  @State private var esitoControllo: String?
  /// La versione nuova trovata dall'ultimo controllo, se c'è.
  @State private var novita: Updates.Release?
  @StateObject private var installazione = Installazione()
  /// Un motore dei suoni tutto per le impostazioni: serve solo al pulsante
  /// «Ascolta», e sente le impostazioni correnti così l'anteprima è fedele.
  @StateObject private var suoni = Suoni()

  private var a11y: A11ySettings { store.current.a11y }

  private func controllaAdesso() {
    controlloInCorso = true
    esitoControllo = nil
    Task {
      defer { controlloInCorso = false }
      do {
        if let r = try await Updates.check(force: true) {
          novita = r
          esitoControllo = nil
        } else {
          novita = nil
          esitoControllo = "Sei già aggiornato."
        }
      } catch {
        esitoControllo = error.localizedDescription
      }
    }
  }

  /// Scarica, verifica e sostituisce; poi riapre l'app nuova e chiude questa.
  ///
  /// Il riavvio sta qui e non dentro `Installazione` perché aprire finestre non
  /// è mestiere di `Core`. E succede solo dopo che la sostituzione è riuscita:
  /// se qualcosa va storto, l'app che stai usando resta quella di prima.
  private func aggiornaEriavvia(_ r: Updates.Release) {
    Task {
      guard await installazione.installa(r) else { return }
      let dove = Bundle.main.bundleURL
      let config = NSWorkspace.OpenConfiguration()
      config.createsNewApplicationInstance = true
      do {
        try await NSWorkspace.shared.openApplication(at: dove, configuration: config)
        NSApp.terminate(nil)
      } catch {
        esitoControllo = "La versione nuova è installata. Chiudi e riapri MirrorScopio."
      }
    }
  }

  private var nomeCorrente: String {
    store.current.name.isEmpty ? "questa persona" : store.current.name
  }

  /// Le impostazioni erano una pagina sola, lunghissima, con otto argomenti in
  /// fila: bisognava scorrerla tutta per trovare una cosa, e chi fa fatica a
  /// tenere insieme molte informazioni insieme si perdeva prima di arrivare in
  /// fondo. Ora sono sette pagine corte, una per argomento, con l'elenco
  /// sempre visibile a sinistra: si vede subito che cosa c'è e dove si è.
  var body: some View {
    PaginaConElenco(titolo: "Impostazioni", scelta: $pagina, a11y: a11y,
                    palette: palette, onClose: onClose) {
      paginaCorrente
    }
  }

  // MARK: - L'elenco delle pagine

  private enum Pagina: String, PaginaLaterale {
    case inizio, lettura, colori, ritmo, voce, risposte, dati, clinico, suoni

    var id: String { rawValue }

    var titolo: String {
      switch self {
      case .inizio: "Si comincia da qui"
      case .lettura: "Come si legge"
      case .colori: "Colori e luce"
      case .ritmo: "Ritmo e calma"
      case .voce: "La voce che legge"
      case .risposte: "Dopo ogni parola"
      case .dati: "I dati e l'app"
      case .clinico: "Parametri clinici"
      case .suoni: "I suoni"
      }
    }

    var simbolo: String {
      switch self {
      case .inizio: "sparkles"
      case .lettura: "textformat.size"
      case .colori: "paintpalette.fill"
      case .ritmo: "tortoise.fill"
      case .voce: "speaker.wave.2.fill"
      case .risposte: "hand.thumbsup.fill"
      case .dati: "lock.fill"
      case .clinico: "slider.horizontal.3"
      case .suoni: "bell.fill"
      }
    }
  }

    @ViewBuilder
  private var paginaCorrente: some View {
    VStack(alignment: .leading, spacing: 28) {
      switch pagina {
      case .inizio:
        who
        profiles
        prova
      case .lettura:
        fonts
      case .colori:
        colors
      case .ritmo:
        rhythm
      case .voce:
        voce
      case .risposte:
        feedback
      case .dati:
        privacy
      case .suoni:
        suoniPagina
      case .clinico:
        VStack(alignment: .leading, spacing: 10) {
          Text("Millesimi di secondo, maschera, scala adattiva. Servono a chi\nimposta la riabilitazione; per leggere non serve toccare niente.")
            .font(a11y.typeface.font(size: a11y.size(15)))
            .foregroundStyle(palette.muted)
            .fixedSize(horizontal: false, vertical: true)
          AdvancedControls(store: store, engine: engine, a11y: a11y)
        }
      }
    }
  }

  // MARK: - La prova di velocità e lo stato del Mac

  /// La prova sta nell'onboarding, dove capita a tutti la prima volta. Ma un
  /// ragazzo cambia nel giro di mesi, e la velocita di partenza va rifatta:
  /// qui, insieme al nome, e dove si torna quando si vuole ricominciare.
  private var prova: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "La prova di velocità", a11y: a11y)
      Explain(text: store.current.calibratedExposureMs == nil
              ? "Non l'hai ancora fatta. Otto parole, meno di un minuto: servono al Mac per capire da che velocità partire."
              : "Fatta: si parte da \(Int(store.current.calibratedExposureMs ?? 0)) millesimi di secondo. Rifalla ogni tanto — quello che era difficile a settembre può non esserlo più a marzo.",
              a11y: a11y, size: 15)
      HStack(spacing: 12) {
        SmallButton(title: store.current.calibratedExposureMs == nil ? "Fai la prova" : "Rifai la prova",
                    symbol: "wand.and.stars", a11y: a11y) {
          onClose()
          onCalibrate()
        }
        SmallButton(title: "Controlla che il Mac abbia tutto",
                    symbol: "checklist", a11y: a11y) {
          onClose()
          onReadiness()
        }
      }
    }
  }

  // MARK: - Voce

  private var voce: some View {
    VStack(alignment: .leading, spacing: 10) {
      VoiceChooser(store: store)
      SmallButton(title: "Altre voci (Impostazioni di Sistema)",
                  symbol: "arrow.up.forward.app", a11y: a11y) {
        if let u = URL(string: Readiness.urlImpostazioniVoci) { NSWorkspace.shared.open(u) }
      }
      Explain(text: "macOS non permette a nessuna app di scaricare le voci: quelle in elenco sono tutte quelle installate.", a11y: a11y, size: 14)
    }
  }

  // MARK: - Chi usa l'app

  private var who: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "Chi usa l'app", a11y: a11y)
      Explain(text: "Il nome serve solo a intestare i progressi e i referti. Resta su questo Mac.", a11y: a11y, size: 15)
      TextField("Nome", text: Binding(
        get: { store.current.name },
        set: { var l = store.current; l.name = $0; store.current = l }
      ))
      .textFieldStyle(.roundedBorder)
      .font(a11y.typeface.font(size: a11y.size(18)))
      .frame(maxWidth: 360)
    }
  }

  // MARK: - Profili

  private var profiles: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "Un profilo imposta tutto in un colpo", a11y: a11y)
      Explain(text: "Scegline uno e carattere, colori, tempi e pause si sistemano da soli. Poi puoi ritoccare quello che vuoi qui sotto.", a11y: a11y, size: 15)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
        ForEach(A11yProfile.allCases) { p in
          ChoiceCard(title: p.label, subtitle: p.hint, symbol: p.symbol,
                     selected: a11y.profile == p, a11y: a11y) {
            var l = store.current
            p.apply(to: &l.a11y)
            store.current = l
            engine.a11y = l.a11y
          }
        }
      }
    }
  }

  // MARK: - Carattere

  private var fonts: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionTitle(text: "Carattere", a11y: a11y)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
        ForEach(TypefaceChoice.allCases.filter(\.isAvailable)) { t in
          ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.typeface == t, a11y: a11y) {
            update { $0.typeface = t }
          }
        }
      }
      preview
      slider("Dimensione di tutto", value: bind(\.textScale), range: 0.8...2.0, format: { String(format: "×%.1f", $0) })
      slider("Grandezza della parola che lampeggia", value: bind(\.stimulusSize), range: 40...320, format: { "\(Int($0)) punti" })
      slider("Spazio fra le lettere", value: bind(\.letterSpacing), range: 0...24, format: { "\(Int($0)) punti" })
    }
  }

  private var preview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Explain(text: "Come si vedrà la parola:", a11y: a11y, size: 14)
      Text("farfalla")
        .font(a11y.typeface.font(size: min(CGFloat(a11y.stimulusSize), 90), weight: .semibold))
        .tracking(CGFloat(a11y.letterSpacing))
        .foregroundStyle(palette.foreground)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
    }
  }

  // MARK: - Colori

  private var colors: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionTitle(text: "Colori", a11y: a11y)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
        ForEach(ThemeChoice.allCases) { t in
          ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.theme == t, a11y: a11y) {
            update { $0.theme = t }
          }
        }
      }

      SectionTitle(text: "Come vedi i colori", a11y: a11y)
      Explain(text: "«Giusta» e «ancora» non si distinguono mai solo dal colore: c'è sempre anche un simbolo e una parola. Qui scegli i colori che si distinguono meglio per te.", a11y: a11y, size: 15)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
        ForEach(ColorVision.allCases) { v in
          ChoiceCard(title: v.label, selected: a11y.colorVision == v, a11y: a11y) {
            update { $0.colorVision = v }
          }
        }
      }
      HStack(spacing: 20) {
        Verdict(correct: true, a11y: a11y)
        Verdict(correct: false, a11y: a11y)
      }
      .padding(.top, 4)
    }
  }

  // MARK: - Ritmo

  private var rhythm: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionTitle(text: "Ritmo e calma", a11y: a11y)
      toggle("Niente animazioni", bindBool(\.reducedMotion),
             "Tutto compare e sparisce senza movimento.")
      toggle("Modalità calma", bindBool(\.calmMode),
             "Niente esclamazioni, niente festeggiamenti, tono sempre uguale.")
      toggle("Schermo pulito durante la prova", bindBool(\.distractionFree),
             "Toglie contatori e pulsanti dai bordi mentre lampeggiano le parole.")
      toggle("Mostra il tempo", bindBool(\.showTimer),
             "Un orologio in alto dice da quanto stai andando. Conta il tempo passato: "
             + "non è un conto alla rovescia e non scade mai.")
      slider("Più tempo per rispondere", value: bind(\.extraResponseTime), range: 1.0...3.0,
             format: { String(format: "×%.1f", $0) })
      Stepper(value: Binding(
        get: { Double(a11y.pauseEveryNWords) },
        set: { v in update { $0.pauseEveryNWords = Int(v) } }
      ), in: 0...20, step: 1) {
        Text(a11y.pauseEveryNWords == 0
             ? "Pausa automatica: mai"
             : "Pausa automatica ogni \(a11y.pauseEveryNWords) parole")
          .font(a11y.typeface.font(size: a11y.size(17)))
          .foregroundStyle(palette.foreground)
      }
    }
  }

  // MARK: - Riscontro

  private var feedback: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionTitle(text: "Che cosa mostrare dopo ogni parola", a11y: a11y)
      toggle("Dire subito se è giusta", bindBool(\.showFeedbackPerWord),
             "Un simbolo grande dopo ogni parola.")
      toggle("Nascondere punteggi e percentuali", bindBool(\.hideScore),
             "Per chi si mette in ansia con i numeri: resta solo il senso di aver finito.")
      toggle("Rileggere ad alta voce la parola giusta", bindBool(\.speakCorrectWord),
             "Comoda quando lo schermo si legge a fatica, e per riguardare con calma le parole che non sono venute.")
    }
  }

  // MARK: - Dati

  // MARK: - Suoni

  /// I suoni di conferma: l'app finora era muta, e chi non guarda lo schermo
  /// non sapeva se il Mac aveva registrato la sua risposta. Qui si accendono, si
  /// regola il volume e — soprattutto — si provano prima di lasciarli a un
  /// ragazzo: chi imposta l'app deve sentire esattamente ciò che sentirà lui.
  private var suoniPagina: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "I suoni di conferma", a11y: a11y)
      Explain(text: "Un tocco quando la parola compare, due note che salgono quando è giusta, "
              + "un tocco piatto e neutro quando è «ancora» — mai un suono da errore — e una "
              + "piccola cadenza alla fine. Servono a chi fa fatica a guardare lo schermo.",
              a11y: a11y, size: 15)

      toggle("Accendi i suoni", bindBool(\.soundsEnabled),
             "Da spenti l'app resta muta. Il profilo Autismo li lascia spenti di proposito.")

      slider("Volume", value: bind(\.volumeSuoni), range: 0...1,
             format: { "\(Int($0 * 100))%" })

      VStack(alignment: .leading, spacing: 8) {
        SectionTitle(text: "Ascolta ciascun suono", a11y: a11y)
        Explain(text: "Si sentono anche a suoni spenti, così puoi decidere. Suonano come li "
                + "sentirà chi usa l'app: volume e profilo di accessibilità inclusi.",
                a11y: a11y, size: 14)
        ForEach(Suoni.Momento.allCases) { momento in
          HStack(alignment: .top, spacing: 12) {
            SmallButton(title: "Ascolta", symbol: "play.circle.fill", a11y: a11y) {
              // Alla fine passo una quota alta: in anteprima si sente la
              // cadenza piena, quella di una sessione andata bene.
              suoni.anteprima(momento, quota: momento == .fine ? 0.85 : 1, a11y: a11y)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text(momento.titolo)
                .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
                .foregroundStyle(palette.foreground)
              Explain(text: momento.spiega, a11y: a11y, size: 14)
            }
            Spacer(minLength: 0)
          }
          .padding(.vertical, 2)
        }
      }

      Explain(text: "I suoni si adattano da soli: in modalità calma sono più bassi, corti e "
              + "morbidi; con VoiceOver acceso si accorciano per non parlare sopra la voce; se hai "
              + "detto che certi colori si somigliano, diventano più netti, perché lì il suono fa "
              + "il lavoro che il colore non riesce a fare.", a11y: a11y, size: 14)
    }
  }

  @ViewBuilder
  private var aggiornamentoDisponibile: some View {
    if let r = novita {
      RiquadroAggiornamento(release: r, fase: installazione.fase,
                            sessioneInCorso: engine.isRunning,
                            puòInstallare: Installazione.puòInstallare,
                            a11y: a11y,
                            onAggiorna: { aggiornaEriavvia(r) },
                            onPagina: { NSWorkspace.shared.open(r.pageURL) })
    }
  }

  private var privacy: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "I dati", a11y: a11y)
      Explain(text: "Voce, risposte e progressi non escono mai da questo Mac: niente account, niente rete, niente servizi esterni. I file stanno in una cartella che puoi aprire, leggere o cancellare a mano.", a11y: a11y, size: 15)
      SmallButton(title: "Apri la cartella dei dati", symbol: "folder", a11y: a11y) {
        NSWorkspace.shared.open(store.storageFolder)
      }

      Divider().padding(.vertical, 4)

      Toggle(isOn: Binding(get: { Updates.enabled },
                           set: { Updates.enabled = $0; aggiornamentiAccesi = $0 })) {
        Text("Avvisami quando esce una versione nuova")
          .font(a11y.typeface.font(size: a11y.size(17)))
      }
      .toggleStyle(.switch)
      Explain(text: "È l'unica cosa che esce da questo Mac: una domanda al giorno a GitHub su qual è l'ultima versione. Non parte nessun nome, nessuna parola, nessun punteggio. Se esce una versione nuova puoi installarla da qui, con un pulsante: non si scarica niente da solo.", a11y: a11y, size: 14)

      if aggiornamentiAccesi {
        HStack(spacing: 12) {
          SmallButton(title: "Controlla adesso", symbol: "arrow.clockwise",
                      a11y: a11y) { controllaAdesso() }
            .disabled(controlloInCorso || installazione.inCorso)
          if controlloInCorso { ProgressView().controlSize(.small) }
          if let esito = esitoControllo {
            Text(esito)
              .font(a11y.typeface.font(size: a11y.size(15)))
              .foregroundStyle(palette.muted)
          }
        }
        aggiornamentoDisponibile
      }

      Divider().padding(.vertical, 4)

      promemoriaSezione

      Divider().padding(.vertical, 4)

      SmallButton(title: "Cancella tutti i dati di \(nomeCorrente)", symbol: "trash",
                  a11y: a11y, distruttivo: true) {
        chiedeCancellazione = true
      }
      .confirmationDialog(
        "Cancellare tutti i dati di \(nomeCorrente)?",
        isPresented: $chiedeCancellazione,
        titleVisibility: .visible
      ) {
        Button("Cancella tutto", role: .destructive) {
          store.deleteLearner(store.current.id)
        }
        Button("Lascia stare", role: .cancel) {}
      } message: {
        Text("Spariscono il nome, i progressi, gli obiettivi e ogni sessione registrata. Non si torna indietro.")
      }
      Explain(text: "Serve a esercitare il diritto alla cancellazione senza dover frugare nelle cartelle di sistema.", a11y: a11y, size: 14)

      Divider().padding(.vertical, 4)

      Text(AppVersion.display)
        .font(a11y.typeface.font(size: a11y.size(14), weight: .semibold))
      Text(AppVersion.detail)
        .font(a11y.typeface.font(size: a11y.size(12)))
        .foregroundStyle(palette.muted)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
      Text("Fight The Stroke Foundation")
        .font(a11y.typeface.font(size: a11y.size(12)))
        .foregroundStyle(palette.muted)
    }
  }

  // MARK: - Promemoria

  private var giaFattoOggi: Bool {
    store.current.lastSessionDay == Gamification.dayKey(Date())
  }

  private func ripianificaPromemoria() {
    Task { await promemoria.ripianifica(giaFattoOggi: giaFattoOggi,
                                        serieGiorni: store.current.streakCurrent) }
  }

  private var promemoriaSezione: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "Un promemoria ogni giorno", a11y: a11y)
      Explain(text: "L'esercizio rende se si fa un pochino ogni giorno, e la cosa più difficile è ricordarsene. Se vuoi, il Mac manda un invito gentile all'ora che scegli. **È tutto qui sul Mac**: non esce niente, è solo un avviso che compare sullo schermo.", a11y: a11y, size: 15)

      Toggle(isOn: Binding(
        get: { promemoria.acceso },
        set: { acceso in
          if acceso {
            Task { await promemoria.accendi(giaFattoOggi: giaFattoOggi,
                                            serieGiorni: store.current.streakCurrent) }
          } else {
            promemoria.spegni()
          }
        })) {
        Text("Ricordami di allenarmi")
          .font(a11y.typeface.font(size: a11y.size(17)))
      }
      .toggleStyle(.switch)

      if promemoria.acceso {
        if promemoria.permessoNegato {
          promemoriaAvvisoNegato
        } else {
          DatePicker(selection: Binding(
            get: { promemoria.orario },
            set: { data in promemoria.impostaOrario(da: data); ripianificaPromemoria() }
          ), displayedComponents: .hourAndMinute) {
            Text("A che ora")
              .font(a11y.typeface.font(size: a11y.size(17)))
          }
          .datePickerStyle(.field)

          Picker(selection: Binding(
            get: { promemoria.giorni },
            set: { g in promemoria.impostaGiorni(g); ripianificaPromemoria() }
          )) {
            ForEach(Promemoria.Giorni.allCases) { g in Text(g.label).tag(g) }
          } label: {
            Text("Quali giorni")
              .font(a11y.typeface.font(size: a11y.size(17)))
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 420, alignment: .leading)

          Explain(text: "Ti mando un invito alle \(promemoria.orarioTesto), "
                  + (promemoria.giorni == .tutti ? "tutti i giorni" : "dal lunedì al venerdì")
                  + ". Mai se hai già letto le tue parole quel giorno, e mai un rimprovero: lo puoi ignorare senza problemi.",
                  a11y: a11y, size: 14)
        }
      }
    }
    .task { await promemoria.aggiornaPermesso() }
  }

  /// Un interruttore acceso che non fa arrivare niente sarebbe una bugia: se il
  /// permesso è negato lo diciamo, e mostriamo dove si rimedia.
  private var promemoriaAvvisoNegato: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "bell.slash.fill")
          .foregroundStyle(palette.wrong)
          .accessibilityHidden(true)
        Text("Le notifiche sono spente per MirrorScopio")
          .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
          .foregroundStyle(palette.foreground)
      }
      Explain(text: "L'interruttore è acceso, ma il Mac non mi lascia mostrare l'avviso, quindi non arriverà niente. Si riattiva in Impostazioni di Sistema › Notifiche › MirrorScopio.", a11y: a11y, size: 14)
      SmallButton(title: "Apri le Impostazioni di Sistema", symbol: "arrow.up.forward.app",
                  a11y: a11y) {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
          NSWorkspace.shared.open(u)
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.wrong.opacity(0.10)))
    .overlay(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).stroke(palette.wrong.opacity(0.4), lineWidth: 1.5))
  }

  // MARK: - Utilità

  private func update(_ change: (inout A11ySettings) -> Void) {
    var l = store.current
    change(&l.a11y)
    // Toccare una manopola a mano significa che il profilo non descrive più esattamente
    // questa persona: si passa a "su misura" senza perdere niente di quello che era impostato.
    if l.a11y.profile != .nessuno { l.a11y.profile = .nessuno }
    store.current = l
    engine.a11y = l.a11y
  }

  private func bind(_ key: WritableKeyPath<A11ySettings, Double>) -> Binding<Double> {
    Binding(get: { store.current.a11y[keyPath: key] },
            set: { v in update { $0[keyPath: key] = v } })
  }

  private func bindBool(_ key: WritableKeyPath<A11ySettings, Bool>) -> Binding<Bool> {
    Binding(get: { store.current.a11y[keyPath: key] },
            set: { v in update { $0[keyPath: key] = v } })
  }

  private func toggle(_ title: String, _ value: Binding<Bool>, _ hint: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Toggle(title, isOn: value)
        .font(a11y.typeface.font(size: a11y.size(17)))
        .foregroundStyle(palette.foreground)
      Explain(text: hint, a11y: a11y, size: 14)
    }
  }

  private func slider(_ title: String, value: Binding<Double>,
                      range: ClosedRange<Double>, format: (Double) -> String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
          .font(a11y.typeface.font(size: a11y.size(17)))
          .foregroundStyle(palette.foreground)
        Spacer()
        Text(format(value.wrappedValue))
          .font(a11y.typeface.font(size: a11y.size(15)))
          .foregroundStyle(palette.muted)
          .monospacedDigit()
      }
      Slider(value: value, in: range)
        .frame(maxWidth: 460)
        .accessibilityLabel(title)
        .accessibilityValue(format(value.wrappedValue))
    }
  }
}
