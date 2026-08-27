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

  private var a11y: A11ySettings { store.current.a11y }
  private var record: SessionRecord { engine.finishedRecord ?? SessionRecord() }

  var body: some View {
    ScrollView {
      VStack(spacing: a11y.size(26)) {
        if engine.isCalibration {
          calibrationResult
        } else {
          childResult
          unlockedBadges
          difficultyProposal
        }
        actions
        if !engine.isCalibration { adultDetail }
      }
      .padding(32)
      .frame(maxWidth: 820)
      .frame(maxWidth: .infinity)
    }
    .onAppear(perform: saveOnce)
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
    VStack(spacing: a11y.size(14)) {
      Text(headline)
        .font(a11y.typeface.font(size: a11y.size(44), weight: .bold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      if a11y.hideScore {
        Explain(text: "Sessione finita. Hai letto tutte le parole fino in fondo.", a11y: a11y, size: 21)
          .multilineTextAlignment(.center)
      } else {
        Text("Hai preso **\(record.correct)** parole su **\(record.total)**.")
          .font(a11y.typeface.font(size: a11y.size(24)))
          .foregroundStyle(palette.muted)

        HStack(spacing: 8) {
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
        VStack(spacing: 6) {
          Explain(text: "Queste ti sono scappate:", a11y: a11y, size: 16)
            .multilineTextAlignment(.center)
          Text(record.missedWords.prefix(10).joined(separator: "   "))
            .font(a11y.typeface.font(size: a11y.size(22), weight: .medium))
            .foregroundStyle(palette.foreground)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
      }
    }
    .padding(.top, 16)
  }

  private var stars: Int {
    guard record.total > 0 else { return 0 }
    return max(1, Int((record.accuracy * 5).rounded(.down)))
  }

  private var headline: String {
    if a11y.calmMode { return "Sessione finita" }
    return switch record.accuracy {
    case 0.9...: "Bravissimo!"
    case 0.7..<0.9: "Bravo!"
    case 0.5..<0.7: "Bene!"
    default: "Ci hai provato!"
    }
  }

  // MARK: - Obiettivi appena sbloccati

  @ViewBuilder
  private var unlockedBadges: some View {
    if !unlocked.isEmpty {
      VStack(spacing: 10) {
        Explain(text: unlocked.count == 1 ? "Hai sbloccato un obiettivo" : "Hai sbloccato \(unlocked.count) obiettivi", a11y: a11y, size: 17)
        HStack(spacing: 12) {
          ForEach(unlocked) { a in
            VStack(spacing: 6) {
              Image(systemName: a.symbol).font(.system(size: a11y.size(30)))
                .foregroundStyle(palette.accent)
              Text(a.title).font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
                .foregroundStyle(palette.foreground)
              Text(a.hint).font(a11y.typeface.font(size: a11y.size(13)))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.surface))
          }
        }
      }
    }
  }

  // MARK: - Sfidante ma raggiungibile

  @ViewBuilder
  private var difficultyProposal: some View {
    if let message = Difficulty.message(engine.difficultySuggestion) {
      VStack(spacing: 12) {
        Text(.init(message))
          .font(a11y.typeface.font(size: a11y.size(21)))
          .foregroundStyle(palette.foreground)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 12) {
          BigButton(title: "Sì, proviamo", symbol: "arrow.right", a11y: a11y) {
            applySuggestion()
          }
          BigButton(title: "No, resto qui", a11y: a11y, prominent: false) {
            engine.difficultySuggestion = .resta
          }
        }
      }
      .padding(18)
      .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
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
    VStack(spacing: a11y.size(16)) {
      Image(systemName: "wand.and.stars")
        .font(.system(size: a11y.size(52)))
        .foregroundStyle(palette.accent)
      Text("Prova finita")
        .font(a11y.typeface.font(size: a11y.size(40), weight: .bold))
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
    .padding(.top, 20)
  }

  // MARK: - Pulsanti

  private var actions: some View {
    HStack(spacing: 14) {
      if !engine.isCalibration {
        BigButton(title: "Ancora", symbol: "arrow.clockwise", a11y: a11y) {
          engine.reset()
          engine.start()
        }
        .keyboardShortcut(.return, modifiers: [])

        if !record.missedWords.isEmpty {
          BigButton(title: "Solo le sbagliate", symbol: "target", a11y: a11y, prominent: false) {
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

  private var adultDetail: some View {
    DisclosureGroup(isExpanded: $showDetail) {
      VStack(alignment: .leading, spacing: 16) {
        Explain(text: plainLanguage, a11y: a11y, size: 16)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
          stat("\(record.total)", "parole mostrate")
          stat("\(Int(record.accuracy * 100))%", "lette giuste (\(record.correct) su \(record.total))")
          stat(record.thresholdMs.map { "\(Int($0)) ms" } ?? "—", "tempo minimo per leggere")
          stat(record.meanLatencyMs.map { "\(Int($0)) ms" } ?? "—", "ritardo prima di parlare")
        }

        if !record.errorCounts.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Che tipo di errori")
              .font(a11y.typeface.font(size: a11y.size(18), weight: .semibold))
              .foregroundStyle(palette.foreground)
            ForEach(record.errorCounts.sorted { $0.value > $1.value }, id: \.key) { kind, count in
              Text("· \(kind) — \(count)")
                .font(a11y.typeface.font(size: a11y.size(16)))
                .foregroundStyle(palette.muted)
            }
          }
        }

        if engine.summarizing {
          HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Explain(text: "Analisi in corso sul Mac…", a11y: a11y, size: 15)
          }
        } else if let s = engine.summary {
          GroupBox {
            VStack(alignment: .leading, spacing: 10) {
              Text(s.profilo).font(a11y.typeface.font(size: a11y.size(16)))
              Text("Pattern prevalente: \(s.patternPrevalente)")
                .font(a11y.typeface.font(size: a11y.size(15)))
                .foregroundStyle(palette.muted)
              ForEach(Array(s.proposte.enumerated()), id: \.offset) { _, p in
                Label(p, systemImage: "arrow.right.circle")
                  .font(a11y.typeface.font(size: a11y.size(15)))
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
          } label: {
            Label("Sintesi clinica — modello Apple sul dispositivo", systemImage: "sparkles")
              .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
          }
        }

        trialTable

        HStack(spacing: 10) {
          Button("Esporta PDF") {
            Exporter.save(data: Exporter.pdf(record, learner: store.current),
                          suggested: "mirrorscopio-\(Gamification.dayKey(record.date)).pdf")
          }
          Button("Esporta CSV") {
            Exporter.save(text: Exporter.csv(record, learner: store.current),
                          suggested: "mirrorscopio-\(Gamification.dayKey(record.date)).csv")
          }
        }
        .font(a11y.typeface.font(size: a11y.size(15)))
      }
      .padding(.top, 14)
    } label: {
      Label("Dettaglio per l'adulto", systemImage: "gearshape")
        .font(a11y.typeface.font(size: a11y.size(18), weight: .semibold))
        .foregroundStyle(palette.foreground)
    }
    .padding(.top, 10)
  }

  private var trialTable: some View {
    VStack(spacing: 0) {
      ForEach(record.items) { item in
        HStack(spacing: 12) {
          Text(item.stimulus)
            .font(a11y.typeface.font(size: a11y.size(16), weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(item.response.isEmpty ? "—" : item.response)
            .font(a11y.typeface.font(size: a11y.size(16)))
            .foregroundStyle(palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
          Verdict(correct: item.correct, a11y: a11y, size: 15)
            .frame(width: 130, alignment: .leading)
          Text(item.errorKind)
            .font(a11y.typeface.font(size: a11y.size(14)))
            .foregroundStyle(palette.muted)
            .frame(width: 120, alignment: .leading)
          Text("\(Int(item.exposureMs)) ms")
            .font(a11y.typeface.font(size: a11y.size(14)))
            .foregroundStyle(palette.muted)
            .monospacedDigit()
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(item.warmup ? palette.surface.opacity(0.5) : Color.clear)
      }
    }
    .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface.opacity(0.35)))
  }

  /// I numeri qui sopra, detti in italiano.
  private var plainLanguage: String {
    guard record.total > 0 else { return "Nessuna parola completata." }
    var out = "Ha letto giuste \(record.correct) parole su \(record.total). Le prime \(engine.config.warmupTrials) erano di riscaldamento e non contano per la soglia."
    if let t = record.thresholdMs {
      out += " Riesce a leggere parole mostrate per circa \(Int(t)) millesimi di secondo: sotto questo tempo comincia a sbagliare."
    }
    if let l = record.meanLatencyMs {
      out += " Ci ha messo in media \(Int(l)) millesimi di secondo a cominciare a parlare."
    }
    if let k = record.errorCounts.sorted(by: { $0.value > $1.value }).first, record.correct < record.total {
      out += " L'errore più frequente: \(k.key)."
    }
    return out
  }

  private func stat(_ value: String, _ key: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(a11y.typeface.font(size: a11y.size(26), weight: .bold))
        .foregroundStyle(palette.foreground)
        .monospacedDigit()
      Text(key)
        .font(a11y.typeface.font(size: a11y.size(13)))
        .foregroundStyle(palette.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface))
  }
}
