import SwiftUI

/// I progressi. Prima quello che il ragazzo capisce a colpo d'occhio
/// (livello, serie, obiettivi), poi — chiuso — il dettaglio per l'adulto.
struct DashboardView: View {
  @ObservedObject var store: Store
  var onClose: () -> Void

  @Environment(\.palette) private var pal
  @State private var showAdultDetail = false

  private var a11y: A11ySettings { store.current.a11y }
  private var sessions: [SessionRecord] { store.currentHistory }
  private var recent: [SessionRecord] { Array(sessions.prefix(10).reversed()) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        header

        if sessions.isEmpty {
          empty
        } else {
          if !a11y.hideScore { levelCard }
          tiles
          if !a11y.reducedMotion || true { trend }
          achievements
          adultSection
        }
      }
      .padding(36)
      .frame(maxWidth: 900)
      .frame(maxWidth: .infinity)
    }
    .background(pal.background)
    .foregroundStyle(pal.foreground)
  }

  // MARK: - Pezzi

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("I tuoi progressi")
          .font(a11y.typeface.font(size: a11y.size(38), weight: .bold))
        if !store.current.name.isEmpty {
          Text(store.current.name)
            .font(a11y.typeface.font(size: a11y.size(18)))
            .foregroundStyle(pal.muted)
        }
      }
      Spacer()
      Button(action: onClose) {
        Label("Chiudi", systemImage: "xmark")
          .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
          .padding(.horizontal, 18).padding(.vertical, 12)
      }
      .buttonStyle(.plain)
      .background(pal.surface, in: .rect(cornerRadius: 12))
      .frame(minWidth: 44, minHeight: 44)
    }
  }

  private var empty: some View {
    VStack(spacing: 16) {
      Image(systemName: "sparkles")
        .font(.system(size: a11y.size(54)))
        .foregroundStyle(pal.accent)
      Text("Qui compariranno i tuoi progressi")
        .font(a11y.typeface.font(size: a11y.size(26), weight: .semibold))
      Text("Fai la prima sessione e torna a vedere.")
        .font(a11y.typeface.font(size: a11y.size(18)))
        .foregroundStyle(pal.muted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
  }

  private var levelCard: some View {
    let xp = store.current.xp
    let level = Gamification.level(xp: xp)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("Livello \(level)")
          .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
        Text(Gamification.levelName(level))
          .font(a11y.typeface.font(size: a11y.size(18)))
          .foregroundStyle(pal.accent)
        Spacer()
        Text("\(xp) punti")
          .font(a11y.typeface.font(size: a11y.size(18)))
          .foregroundStyle(pal.muted)
          .monospacedDigit()
      }
      ProgressView(value: Gamification.progressInLevel(xp))
        .tint(pal.accent)
        .scaleEffect(x: 1, y: 2.4, anchor: .center)
        .padding(.vertical, 6)
      Text("Mancano \(Gamification.xpPerLevel - Gamification.xpInLevel(xp)) punti al livello \(level + 1).")
        .font(a11y.typeface.font(size: a11y.size(15)))
        .foregroundStyle(pal.muted)
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(pal.surface, in: .rect(cornerRadius: 18))
  }

  private var tiles: some View {
    let best = sessions.compactMap(\.thresholdMs).min()
    let words = sessions.reduce(0) { $0 + $1.correct }
    return HStack(spacing: 16) {
      tile("Giorni di fila", "\(store.current.streakCurrent)", "flame.fill",
           note: store.current.streakLongest > store.current.streakCurrent
             ? "record: \(store.current.streakLongest)" : nil)
      tile("Sessioni", "\(sessions.count)", "checkmark.circle.fill", note: nil)
      tile("Parole prese", "\(words)", "text.book.closed.fill", note: nil)
      if let best {
        tile("La più veloce", "\(Int(best))", "bolt.fill", note: "millesimi di secondo")
      }
    }
  }

  private func tile(_ title: String, _ value: String, _ symbol: String, note: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: symbol)
        .font(.system(size: a11y.size(22)))
        .foregroundStyle(pal.accent)
      Text(value)
        .font(a11y.typeface.font(size: a11y.size(34), weight: .bold))
        .monospacedDigit()
      Text(title)
        .font(a11y.typeface.font(size: a11y.size(14)))
        .foregroundStyle(pal.muted)
      if let note {
        Text(note)
          .font(a11y.typeface.font(size: a11y.size(12)))
          .foregroundStyle(pal.muted)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(pal.surface, in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }

  /// Un grafico a barre disegnato a mano: niente Swift Charts, così l'app
  /// resta senza dipendenze e il rendering è prevedibile.
  private var trend: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Come è andata, sessione per sessione")
        .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
      HStack(alignment: .bottom, spacing: 10) {
        ForEach(Array(recent.enumerated()), id: \.element.id) { _, s in
          VStack(spacing: 6) {
            Text("\(Int(s.accuracy * 100))")
              .font(a11y.typeface.font(size: a11y.size(12)))
              .foregroundStyle(pal.muted)
              .monospacedDigit()
            RoundedRectangle(cornerRadius: 6)
              .fill(s.accuracy >= Difficulty.comfortableLow ? pal.ok : pal.accent)
              .frame(height: max(6, 150 * s.accuracy))
            Text(shortDate(s.date))
              .font(a11y.typeface.font(size: a11y.size(11)))
              .foregroundStyle(pal.muted)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(shortDate(s.date)): \(Int(s.accuracy * 100)) per cento")
        }
      }
      .frame(height: 200, alignment: .bottom)
      Text("La fascia buona è fra il 60 e il 90 per cento: lì si impara di più.")
        .font(a11y.typeface.font(size: a11y.size(14)))
        .foregroundStyle(pal.muted)
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(pal.surface, in: .rect(cornerRadius: 18))
  }

  private var achievements: some View {
    let unlocked = Set(store.current.unlockedAchievements)
    return VStack(alignment: .leading, spacing: 14) {
      Text("Obiettivi")
        .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
        ForEach(Gamification.all) { a in
          let got = unlocked.contains(a.id)
          HStack(spacing: 12) {
            Image(systemName: got ? a.symbol : "lock.fill")
              .font(.system(size: a11y.size(20)))
              .foregroundStyle(got ? pal.accent : pal.muted)
              .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
              Text(a.title)
                .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
              Text(a.hint)
                .font(a11y.typeface.font(size: a11y.size(12)))
                .foregroundStyle(pal.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }
          .padding(14)
          .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
          .background(pal.background, in: .rect(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(got ? pal.accent.opacity(0.5) : Color.gray.opacity(0.25), lineWidth: 1.5))
          .opacity(got ? 1 : 0.6)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("\(a.title). \(got ? "Ottenuto" : "Ancora da ottenere"). \(a.hint)")
        }
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(pal.surface, in: .rect(cornerRadius: 18))
  }

  private var adultSection: some View {
    DisclosureGroup(isExpanded: $showAdultDetail) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(sessions.prefix(20)) { s in
          HStack(spacing: 14) {
            Text(fullDate(s.date))
              .font(.system(size: a11y.size(13)))
              .frame(width: 170, alignment: .leading)
            Text(s.mode == .lettura ? "Leggi" : "Scrivi")
              .font(.system(size: a11y.size(13)))
              .frame(width: 60, alignment: .leading)
              .foregroundStyle(pal.muted)
            Text(s.level.title)
              .font(.system(size: a11y.size(13)))
              .frame(width: 100, alignment: .leading)
              .foregroundStyle(pal.muted)
            Text("\(s.correct)/\(s.total)")
              .font(.system(size: a11y.size(13))).monospacedDigit()
              .frame(width: 60, alignment: .leading)
            Text(s.thresholdMs.map { "soglia \(Int($0)) ms" } ?? "—")
              .font(.system(size: a11y.size(13))).monospacedDigit()
              .foregroundStyle(pal.muted)
            Spacer(minLength: 0)
          }
        }

        Divider().padding(.vertical, 6)

        HStack(spacing: 12) {
          Button("Esporta lo storico in PDF") {
            Exporter.save(data: Exporter.pdf(sessions: sessions, learner: store.current),
                          suggested: "MirrorScopio-storico.pdf")
          }
          Button("Esporta lo storico in CSV") {
            let text = sessions.map { Exporter.csv($0, learner: store.current) }
              .joined(separator: "\n")
            Exporter.save(text: text, suggested: "MirrorScopio-storico.csv")
          }
          Spacer()
        }

        Text("I dati non lasciano mai questo Mac. Stanno in file leggibili in \(store.storageFolder.path).")
          .font(.system(size: a11y.size(12)))
          .foregroundStyle(pal.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 14)
    } label: {
      Label("Dettaglio per l'adulto", systemImage: "person.fill")
        .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
    }
    .padding(24)
    .background(pal.surface, in: .rect(cornerRadius: 18))
  }

  private func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "it_IT")
    f.dateFormat = "d MMM"
    return f.string(from: d)
  }

  private func fullDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "it_IT")
    f.dateFormat = "d MMMM yyyy, HH:mm"
    return f.string(from: d)
  }
}
