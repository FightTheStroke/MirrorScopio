import SwiftUI

/// Fine sessione. Prima quello che interessa al ragazzo, poi — chiuso — quello
/// che interessa al logopedista. Mai il contrario.
struct ReportView: View {
  @ObservedObject var engine: SessionEngine
  @ObservedObject var store: Store
  @Environment(\.palette) private var palette

  @State private var saved = false
  @State private var unlocked: [Achievement] = []
  @State private var showDetail = false
  /// Con «Nascondi punteggi» acceso il dettaglio numerico resta chiuso finché
  /// non lo chiede qualcuno, adesso, in modo esplicito.
  @State private var numeriChiesti = false
  @State private var chiedeINumeri = false
  /// Il premio è opzionale: chi non lo vuole non lo vede aprirsi da solo.
  @State private var showStaffetta = false
  /// La tastiera arriva sul pulsante che quasi tutti premono: «Ancora».
  @FocusState private var fuoco: Fuoco?
  private enum Fuoco: Hashable { case ancora }

  @Environment(\.impostazioni) private var a11y
  private var record: SessionRecord { engine.finishedRecord ?? SessionRecord() }

  var body: some View {
    ScrollView {
      VStack(spacing: a11y.size(Metrica.margine)) {
        if engine.isCalibration {
          calibrationResult
        } else {
          childResult
          unlockedBadges
          difficultyProposal
        }
        actions
        if !engine.isCalibration, record.total > 0 { premioStaffetta }
        if !engine.isCalibration { adultDetail }
        // In fondo a tutto, e l'ultima cosa: qui c'è un ragazzo che ha appena
        // finito un esercizio, non un donatore. In modalità calma sparisce del
        // tutto — non è il momento di chiedere niente a nessuno.
        if !engine.isCalibration, record.total > 0, !a11y.calmMode { sostieni }
      }
      .padding(Metrica.spazioGrande)
      .frame(maxWidth: 820)
      .frame(maxWidth: .infinity)
    }
    .defaultFocus($fuoco, .ancora)
    // I coriandoli stanno sopra a tutto ma non intercettano niente: si vede la
    // festa e si può continuare a usare la schermata mentre cade.
    .overlay(alignment: .top) {
      if !engine.isCalibration, record.total > 0 {
        Celebrazione(a11y: a11y, intensita: intensitaFesta)
          .allowsHitTesting(false)
      }
    }
    .onAppear(perform: saveOnce)
    // Esc chiude il riepilogo e torna a casa, come chiude tutto il resto
    // dell'app: non si impara una scorciatoia diversa per ogni schermata.
    .background {
      Button("", action: { engine.reset() })
        .keyboardShortcut(.escape, modifiers: [])
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
    // Il premio si apre a schermo intero e si chiude quando si vuole: non
    // trattiene, non tiene il punteggio, non ha nulla da vincere.
    .sheet(isPresented: $showStaffetta) {
      StaffettaView(a11y: a11y, onClose: { showStaffetta = false })
        .frame(minWidth: 860, minHeight: 660)
        .environment(\.palette, palette)
    }
  }

  // MARK: - Il premio opzionale

  /// Un pulsante discreto, non il protagonista della schermata: chi vuole il
  /// premio lo trova, chi ha già avuto abbastanza per oggi lo ignora e chiude.
  private var premioStaffetta: some View {
    VStack(spacing: Metrica.spazioStretto) {
      SmallButton(title: "Il premio: la staffetta del Fight Camp",
                  symbol: "figure.run", a11y: a11y) {
        showStaffetta = true
      }
      Explain(text: "Un piccolo gioco con un tasto solo. Non c'è fretta e non si può perdere.",
              a11y: a11y, size: 14)
      .multilineTextAlignment(.center)
    }
  }

  // MARK: - Sostieni, senza chiedere

  /// Discreto, mai il pulsante più grosso della pagina: chi vuole sostenere
  /// Fight The Stroke lo trova, chi ha già dato abbastanza oggi lo ignora. E si
  /// dice che apre il browser, perché fin qui l'app non è mai uscita dal Mac.
  private var sostieni: some View {
    VStack(spacing: Metrica.spazioStretto) {
      SmallButton(title: "Sostieni Fight The Stroke", symbol: "heart", a11y: a11y) {
        if let u = URL(string: "https://www.fightthestroke.org/donorbox") {
          NSWorkspace.shared.open(u)
        }
      }
      .accessibilityLabel("Sostieni Fight The Stroke: apre un sito web esterno nel browser")
      Explain(text: "MirrorScopio è gratuito e senza pubblicità. Se vuoi, puoi sostenere Fight The Stroke: il pulsante apre il loro sito nel browser.",
              a11y: a11y, size: 13)
      .multilineTextAlignment(.center)
    }
    .padding(.top, Metrica.spazioStretto)
  }

  // MARK: - Salvataggio

  private func saveOnce() {
    guard !saved, record.total > 0 else { return }
    saved = true
    guard !engine.isCalibration else { return }
    var learner = store.current
    unlocked = Gamification.apply(session: record, to: &learner)
    store.current = learner
    var r = record
    r.learnerID = store.currentID
    store.recordAlreadyScored(r)
  }

  // MARK: - Per il ragazzo

  private var childResult: some View {
    VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
      Text(headline)
        .font(a11y.font(.titoloGrande, .bold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      if a11y.hideScore {
        Explain(text: "Sessione finita. Hai letto tutte le parole fino in fondo.", a11y: a11y, size: 21)
          .multilineTextAlignment(.center)
      } else if record.total == 0 {
        // Ci si è fermati durante il riscaldamento, che di proposito non conta.
        // «Hai preso 0 parole su 0» è vero e non vuol dire niente: se l'app sa
        // che non c'è ancora niente da contare, lo dice con parole sue.
        Explain(text: "Ti sei fermato durante il riscaldamento, quindi non c'è ancora niente da contare. Va benissimo: il riscaldamento serve proprio a capire se è il momento giusto.",
                a11y: a11y, size: 21)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 560)
      } else {
        Text("Hai preso **\(record.correct)** parole su **\(record.total)**.")
          .font(a11y.font(.sezione))
          .foregroundStyle(palette.muted)

        if record.correct < record.total {
          Text(frasePerLeRimaste)
            .font(a11y.font(.guida, .medium))
            .foregroundStyle(palette.accent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
        }

        HStack(spacing: Metrica.spazioStretto) {
          ForEach(0..<5, id: \.self) { i in
            Image(systemName: i < stars ? "star.fill" : "star")
              .font(.system(size: a11y.size(34)))
              .foregroundStyle(i < stars ? Color.yellow : palette.muted.opacity(0.4))
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) stelle su 5")
      }

      if !record.missedWords.isEmpty {
        VStack(spacing: Metrica.spazioMinimo) {
          Explain(text: "Queste ti sono scappate:", a11y: a11y, size: 16)
            .multilineTextAlignment(.center)
          Text(record.missedWords.prefix(10).joined(separator: "   "))
            .font(a11y.font(.guida, .medium))
            .foregroundStyle(palette.foreground)
            .multilineTextAlignment(.center)
        }
        .padding(.top, Metrica.spazioMinimo)
      }
    }
    .padding(.top, Metrica.spazioMedio)
  }

  private var stars: Int {
    guard record.total > 0 else { return 0 }
    return max(1, Int((record.accuracy * 5).rounded(.down)))
  }

  /// Quanta festa. Mai zero: arrivare in fondo è già un risultato, e chi ha
  /// preso poche parole è quello che ha faticato di più per arrivarci.
  private var intensitaFesta: Double {
    let base = 0.45 + record.accuracy * 0.55
    return unlocked.isEmpty ? base : min(1, base + 0.25)
  }

  private var headline: String {
    // Chi si è fermato al riscaldamento non è «arrivato in fondo»: dirglielo
    // sarebbe una pacca sulla spalla per una cosa che non è successa.
    if record.total == 0 { return a11y.calmMode ? "Sessione finita" : "Ci hai provato" }
    if a11y.calmMode { return "Sessione finita" }
    return switch record.accuracy {
    case 0.9...: "Che sessione!"
    case 0.7..<0.9: "Bravissimo!"
    case 0.5..<0.7: "Bravo, si vede!"
    case 0.25..<0.5: "Ci sei quasi!"
    // Mai "male", mai "poche": sei arrivato in fondo, ed è la cosa che conta.
    default: "Sei arrivato in fondo!"
    }
  }

  /// Le parole che non sono venute non si chiamano errori.
  ///
  /// Si chiamano "ancora": non sono venute *ancora*. È l'unica differenza che
  /// conta fra un ragazzo che smette e uno che torna domani.
  private var frasePerLeRimaste: String {
    let mancanti = record.total - record.correct
    if mancanti == 1 { return "Una non è venuta ancora. Verrà." }
    if record.accuracy >= 0.5 { return "\(mancanti) non sono venute ancora. Vengono con la pratica." }
    return "\(mancanti) non sono venute ancora — e va benissimo così: si imparano proprio riprovandole."
  }

  // MARK: - Obiettivi appena sbloccati

  @ViewBuilder
  private var unlockedBadges: some View {
    if !unlocked.isEmpty {
      VStack(spacing: Metrica.spazioStretto) {
        Explain(text: unlocked.count == 1 ? "Hai sbloccato un obiettivo" : "Hai sbloccato \(unlocked.count) obiettivi", a11y: a11y, size: 17)
        HStack(spacing: Metrica.spazioPiccolo) {
          ForEach(unlocked) { a in
            VStack(spacing: Metrica.spazioMinimo) {
              Image(systemName: a.symbol).font(.system(size: a11y.size(30)))
                .foregroundStyle(palette.accent)
              Text(a.title).font(a11y.font(.etichetta, .semibold))
                .foregroundStyle(palette.foreground)
              Text(a.hint).font(a11y.font(.nota))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(Metrica.spazioPiccolo)
            .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
          }
        }
      }
    }
  }

  // MARK: - Sfidante ma raggiungibile

  @ViewBuilder
  private var difficultyProposal: some View {
    if let message = Difficulty.message(engine.difficultySuggestion) {
      VStack(spacing: Metrica.spazioPiccolo) {
        Text(.init(message))
          .font(a11y.font(.guida))
          .foregroundStyle(palette.foreground)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: Metrica.spazioPiccolo) {
          BigButton(title: "Sì, proviamo", symbol: "arrow.right", a11y: a11y) {
            applySuggestion()
          }
          BigButton(title: "No, resto qui", a11y: a11y, prominent: false) {
            engine.difficultySuggestion = .resta
          }
        }
      }
      .padding(Metrica.spazioMedio)
      .background(RoundedRectangle(cornerRadius: Metrica.raggio).fill(palette.surface))
    }
  }

  private func applySuggestion() {
    let newLevel: Level?
    switch engine.difficultySuggestion {
    case .sali(let l): newLevel = l
    case .scendi(let l): newLevel = l
    case .resta: newLevel = nil
    }
    guard let newLevel else { return }
    engine.config.level = newLevel
    newLevel.apply(to: &engine.config)
    var l = store.current
    l.config = engine.config
    store.current = l
    engine.difficultySuggestion = .resta
  }

  // MARK: - Prova iniziale

  private var calibrationResult: some View {
    VStack(spacing: a11y.size(Metrica.spazioMedio)) {
      Image(systemName: "wand.and.stars")
        .font(.system(size: a11y.size(52)))
        .foregroundStyle(palette.accent)
      Text("Prova finita")
        .font(a11y.font(.titoloGrande, .bold))
        .foregroundStyle(palette.foreground)

      if let r = engine.calibrationResult {
        Explain(text: "Riesci a leggere parole che restano circa **\(Int(r.exposureMs))** millesimi di secondo. Comincio a questa velocità: si chiama **\(r.level.title)**. Cambierà da sola man mano che migliori.",
                a11y: a11y, size: 20)
        .multilineTextAlignment(.center)

        BigButton(title: "Va bene, cominciamo", symbol: "play.fill", a11y: a11y) {
          var l = store.current
          l.calibratedExposureMs = r.exposureMs
          l.calibratedAt = Date()
          engine.config.level = r.level
          r.level.apply(to: &engine.config)
          engine.config.exposureMs = r.exposureMs
          l.config = engine.config
          store.current = l
          engine.reset()
        }
        .frame(maxWidth: 420)
      } else {
        Explain(text: "Non sono riuscito a misurare la velocità: troppe poche risposte. Riproviamo con calma, oppure scegli tu il livello.",
                a11y: a11y, size: 19)
        .multilineTextAlignment(.center)
        BigButton(title: "Torna alla schermata iniziale", a11y: a11y, prominent: false) { engine.reset() }
          .frame(maxWidth: 420)
      }
    }
    .padding(.top, Metrica.spazio)
  }

  // MARK: - Pulsanti

  private var actions: some View {
    HStack(spacing: Metrica.spazioPiccolo) {
      if !engine.isCalibration {
        BigButton(title: "Ancora", symbol: "arrow.clockwise", a11y: a11y) {
          engine.reset()
          engine.start()
        }
        .focused($fuoco, equals: .ancora)
        .keyboardShortcut(.return, modifiers: [])

        if !record.missedWords.isEmpty {
          BigButton(title: "Solo quelle da riprendere", symbol: "target", a11y: a11y, prominent: false) {
            let words = record.missedWords
            engine.reset()
            engine.start(words: words)
          }
        }

        BigButton(title: "Ho finito", a11y: a11y, prominent: false) { engine.reset() }
      }
    }
  }

  // MARK: - Per l'adulto

  /// Chi ha chiesto di non vedere i numeri non li vedeva da nessuna parte —
  /// tranne qui, in fondo al riepilogo, dove comparivano tutti insieme:
  /// percentuali, millesimi di secondo, la tabella parola per parola. Era la
  /// schermata in cui quella richiesta contava di più, ed era l'unica in cui
  /// non veniva rispettata.
  ///
  /// Adesso la porta è chiusa come le altre porte «per l'adulto» dell'app: si
  /// apre chiedendolo, e la domanda dice che cosa si sta per far comparire.
  @ViewBuilder
  private var adultDetail: some View {
    if a11y.hideScore && !numeriChiesti {
      portaDeiNumeri
    } else {
      dettaglioPerLAdulto
    }
  }

  private var portaDeiNumeri: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
      SmallButton(title: "Dettaglio per l'adulto", symbol: "gearshape", a11y: a11y) {
        chiedeINumeri = true
      }
      Explain(text: "Hai chiesto di non vedere punteggi e percentuali, e qui dentro ci sono. Si aprono solo se lo chiedi adesso.", a11y: a11y, size: 14)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, Metrica.spazioStretto)
    .confirmationDialog("Far comparire punteggi e percentuali?",
                        isPresented: $chiedeINumeri, titleVisibility: .visible) {
      Button("Sì, mostrali") { numeriChiesti = true; showDetail = true }
      Button("Lascia stare", role: .cancel) {}
    } message: {
      Text("Compaiono le parole prese su quelle mostrate, i millesimi di secondo e la tabella parola per parola. Restano visibili fino alla fine di questa schermata.")
    }
  }

  private var dettaglioPerLAdulto: some View {
    DisclosureGroup(isExpanded: $showDetail) {
      VStack(alignment: .leading, spacing: Metrica.spazioMedio) {
        Explain(text: plainLanguage, a11y: a11y, size: 16)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Metrica.spazioPiccolo)], spacing: Metrica.spazioPiccolo) {
          stat("\(record.total)", "parole mostrate")
          stat("\(Int(record.accuracy * 100))%", "lette giuste (\(record.correct) su \(record.total))")
          stat(record.thresholdMs.map { "\(Int($0)) ms" } ?? "—", "tempo minimo per leggere")
          stat(record.meanLatencyMs.map { "\(Int($0)) ms" } ?? "—", "ritardo prima di parlare")
        }

        if !record.errorCounts.isEmpty {
          VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
            Text("Che cosa succede alle parole che non vengono")
              .font(a11y.font(.corpo, .semibold))
              .foregroundStyle(palette.foreground)
            ForEach(record.errorCounts.sorted { $0.value > $1.value }, id: \.key) { kind, count in
              Text("· \(kind) — \(count)")
                .font(a11y.font(.etichetta))
                .foregroundStyle(palette.muted)
            }
          }
        }

        if engine.summarizing {
          HStack(spacing: Metrica.spazioStretto) {
            ProgressView().controlSize(.small)
            Explain(text: "Analisi in corso sul Mac…", a11y: a11y, size: 15)
          }
        } else if let s = engine.summary {
          GroupBox {
            VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
              Text(s.profilo).font(a11y.font(.etichetta))
              Text("Pattern prevalente: \(s.patternPrevalente)")
                .font(a11y.font(.etichetta))
                .foregroundStyle(palette.muted)
              ForEach(Array(s.proposte.enumerated()), id: \.offset) { _, p in
                Label(p, systemImage: "arrow.right.circle")
                  .font(a11y.font(.etichetta))
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrica.spazioMinimo)
          } label: {
            Label("Sintesi clinica — modello Apple sul dispositivo", systemImage: "sparkles")
              .font(a11y.font(.etichetta, .semibold))
          }
        }

        trialTable

        HStack(spacing: Metrica.spazioPiccolo) {
          SmallButton(title: "Esporta PDF", symbol: "doc.fill", a11y: a11y) {
            Exporter.save(data: Exporter.pdf(record, learner: store.current),
                          suggested: "mirrorscopio-\(Gamification.dayKey(record.date)).pdf")
          }
          SmallButton(title: "Esporta CSV", symbol: "tablecells", a11y: a11y) {
            Exporter.save(text: Exporter.csv(record, learner: store.current),
                          suggested: "mirrorscopio-\(Gamification.dayKey(record.date)).csv")
          }
        }
        Explain(text: "Il file contiene il nome e le parole che non sono venute: trattalo come un documento clinico.", a11y: a11y, size: 14)
      }
      .padding(.top, Metrica.spazioPiccolo)
    } label: {
      Label("Dettaglio per l'adulto", systemImage: "gearshape")
        .font(a11y.font(.corpo, .semibold))
        .foregroundStyle(palette.foreground)
    }
    .padding(.top, Metrica.spazioStretto)
  }

  private var trialTable: some View {
    VStack(spacing: 0) {
      ForEach(record.items) { item in
        HStack(spacing: Metrica.spazioPiccolo) {
          Text(item.stimulus)
            .font(a11y.font(.etichetta, .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(item.response.isEmpty ? "—" : item.response)
            .font(a11y.font(.etichetta))
            .foregroundStyle(palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
          Verdict(correct: item.correct, a11y: a11y, size: 15)
            .frame(width: 130, alignment: .leading)
          Text(item.errorKind)
            .font(a11y.font(.nota))
            .foregroundStyle(palette.muted)
            .frame(width: 120, alignment: .leading)
          Text("\(Int(item.exposureMs)) ms")
            .font(a11y.font(.nota))
            .foregroundStyle(palette.muted)
            .monospacedDigit()
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, Metrica.spazioMinimo)
        .padding(.horizontal, Metrica.spazioStretto)
        .background(item.warmup ? palette.surface.opacity(0.5) : Color.clear)
      }
    }
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface.opacity(0.35)))
  }

  /// I numeri qui sopra, detti in italiano.
  private var plainLanguage: String {
    guard record.total > 0 else { return "Nessuna parola completata." }
    var out = "Ha letto giuste \(record.correct) parole su \(record.total). Le prime \(engine.config.warmupTrials) erano di riscaldamento e non contano per la soglia."
    if let t = record.thresholdMs {
      out += " Riesce a leggere parole mostrate per circa \(Int(t)) millesimi di secondo: sotto questo tempo le parole cominciano a non venire."
    }
    if let l = record.meanLatencyMs {
      out += " Ci ha messo in media \(Int(l)) millesimi di secondo a cominciare a parlare."
    }
    if let k = record.errorCounts.sorted(by: { $0.value > $1.value }).first, record.correct < record.total {
      out += " La difficoltà più frequente: \(k.key)."
    }
    return out
  }

  private func stat(_ value: String, _ key: String) -> some View {
    VStack(alignment: .leading, spacing: Metrica.filo) {
      Text(value)
        .font(a11y.font(.sezione, .bold))
        .foregroundStyle(palette.foreground)
        .monospacedDigit()
      Text(key)
        .font(a11y.font(.nota))
        .foregroundStyle(palette.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Metrica.spazioPiccolo)
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
  }
}
