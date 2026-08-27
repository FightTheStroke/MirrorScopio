import SwiftUI

/// Le impostazioni che contano davvero: come si vede e come si sente l'app.
/// Prima i profili (una scelta sola cambia tutto), poi le regolazioni fini.
struct SettingsView: View {
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  @Environment(\.palette) private var palette
  var onClose: () -> Void

  @State private var chiedeCancellazione = false

  private var a11y: A11ySettings { store.current.a11y }

  private var nomeCorrente: String {
    store.current.name.isEmpty ? "questa persona" : store.current.name
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          who
          profiles
          fonts
          colors
          rhythm
          voce
          feedback
          privacy
        }
        .padding(32)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: - Voce

  private var voce: some View {
    VStack(alignment: .leading, spacing: 10) {
      VoiceChooser(store: store)
      Button("Altre voci (Impostazioni di Sistema)") {
        if let u = URL(string: Readiness.urlImpostazioniVoci) { NSWorkspace.shared.open(u) }
      }
      .font(a11y.typeface.font(size: a11y.size(15)))
      .buttonStyle(.plain)
      .foregroundStyle(palette.muted)
      Explain(text: "macOS non permette a nessuna app di scaricare le voci: quelle in elenco sono tutte quelle installate.", a11y: a11y, size: 14)
    }
  }

  private var header: some View {
    HStack {
      Text("Impostazioni")
        .font(a11y.typeface.font(size: a11y.size(28), weight: .bold))
        .foregroundStyle(palette.foreground)
      Spacer()
      Button("Fine", action: onClose)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.escape, modifiers: [])
    }
    .padding(.horizontal, 26)
    .padding(.vertical, 16)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.surface))
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
      Explain(text: "Giusto e sbagliato non si distinguono mai solo dal colore: c'è sempre anche un simbolo e una parola. Qui scegli i colori che distingui meglio.", a11y: a11y, size: 15)
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
             "Utile a chi vede poco e a chi ha sbagliato.")
    }
  }

  // MARK: - Dati

  private var privacy: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(text: "I dati", a11y: a11y)
      Explain(text: "Voce, risposte e progressi non escono mai da questo Mac: niente account, niente rete, niente servizi esterni. I file stanno in una cartella che puoi aprire, leggere o cancellare a mano.", a11y: a11y, size: 15)
      Button("Apri la cartella dei dati") {
        NSWorkspace.shared.open(store.storageFolder)
      }
      .font(a11y.typeface.font(size: a11y.size(15)))

      Button("Cancella tutti i dati di \(nomeCorrente)", role: .destructive) {
        chiedeCancellazione = true
      }
      .font(a11y.typeface.font(size: a11y.size(15)))
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
        .font(.system(size: a11y.size(12)))
        .foregroundStyle(palette.muted)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
      Text("Fight The Stroke Foundation")
        .font(.system(size: a11y.size(12)))
        .foregroundStyle(palette.muted)
    }
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
    }
  }
}
