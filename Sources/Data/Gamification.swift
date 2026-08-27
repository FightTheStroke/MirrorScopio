import Foundation

// MARK: - Obiettivi e progressi

/// Un obiettivo da sbloccare. Sono pochi e tutti raggiungibili: servono a dare
/// una ragione per tornare domani, non a creare ansia da prestazione.
struct Achievement: Identifiable, Hashable {
  let id: String
  let title: String
  let hint: String
  let symbol: String
  /// Restituisce vero quando l'obiettivo è stato raggiunto.
  let check: (SessionRecord, Learner) -> Bool

  static func == (a: Achievement, b: Achievement) -> Bool { a.id == b.id }
  func hash(into h: inout Hasher) { h.combine(id) }
}

enum Gamification {
  /// Punti di una sessione: una parola giusta vale 10, il completamento 20,
  /// e la serie di giorni moltiplica il totale.
  static func xp(for s: SessionRecord, streak: Int) -> Int {
    let base = s.correct * 10 + (s.total > 0 ? 20 : 0)
    return Int(Double(base) * streakMultiplier(streak))
  }

  /// Ereditato da MirrorBuddy (`docs/claude/gamification.md`): la serie premia
  /// la costanza, non la performance.
  static func streakMultiplier(_ days: Int) -> Double {
    switch days {
    case 0: 1.0
    case 1...2: 1.1
    case 3...6: 1.25
    default: 1.5
    }
  }

  static let xpPerLevel = 500

  static func level(xp: Int) -> Int { max(1, xp / xpPerLevel + 1) }
  static func xpInLevel(_ xp: Int) -> Int { xp % xpPerLevel }
  static func progressInLevel(_ xp: Int) -> Double { Double(xpInLevel(xp)) / Double(xpPerLevel) }

  /// Nomi dei livelli: incoraggianti, mai giudicanti.
  static func levelName(_ level: Int) -> String {
    switch level {
    case 1...2: "Esploratore"
    case 3...5: "Lettore curioso"
    case 6...9: "Occhio veloce"
    case 10...14: "Lampo"
    case 15...20: "Maestro dei lampi"
    default: "Leggenda"
    }
  }

  /// Quante fasce di livello esistono in tutto. Serve ai distintivi per
  /// disegnare la progressione: quanta parte dell'anello è già stata conquistata.
  static let numeroFasce = 6

  /// A quale fascia appartiene un livello, da 0 (Esploratore) a 5 (Leggenda).
  /// I distintivi lo usano per far vedere a colpo d'occhio — e in bianco e nero —
  /// che Leggenda viene dopo Esploratore, senza affidarsi al colore.
  /// Deve restare allineato agli intervalli di `levelName`.
  static func levelRank(_ level: Int) -> Int {
    switch level {
    case 1...2: 0
    case 3...5: 1
    case 6...9: 2
    case 10...14: 3
    case 15...20: 4
    default: 5
    }
  }

  /// Il simbolo della fascia di livello. Cambia di grado insieme al nome, così
  /// ogni fascia ha una sua faccia riconoscibile e non solo un numero più grosso.
  static func levelSymbol(_ level: Int) -> String {
    switch levelRank(level) {
    case 0: "binoculars.fill"   // Esploratore: si guarda intorno, si comincia
    case 1: "book.fill"         // Lettore curioso: legge per il gusto di leggere
    case 2: "eye.fill"          // Occhio veloce: coglie la parola in un lampo
    case 3: "bolt.fill"         // Lampo: veloce davvero
    case 4: "flame.fill"        // Maestro dei lampi: costante, non solo veloce
    default: "crown.fill"       // Leggenda
    }
  }

  static let all: [Achievement] = [
    Achievement(id: "prima-sessione", title: "Si comincia",
                hint: "Hai finito la tua prima sessione.", symbol: "flag.fill") { _, _ in true },
    Achievement(id: "tutte-giuste", title: "En plein",
                hint: "Hai letto giuste tutte le parole di una sessione.",
                symbol: "star.circle.fill") { s, _ in s.total > 0 && s.correct == s.total },
    Achievement(id: "dieci-giuste", title: "Dieci in fila",
                hint: "Dieci parole giuste nella stessa sessione.",
                symbol: "10.circle.fill") { s, _ in s.correct >= 10 },
    Achievement(id: "serie-3", title: "Tre giorni di fila",
                hint: "Sei tornato tre giorni di seguito.",
                symbol: "calendar") { _, l in l.streakCurrent >= 3 },
    Achievement(id: "serie-7", title: "Una settimana intera",
                hint: "Sette giorni di seguito. Notevole.",
                symbol: "calendar.badge.checkmark") { _, l in l.streakCurrent >= 7 },
    Achievement(id: "sotto-200", title: "Occhio da falco",
                hint: "Hai letto parole comparse per meno di 200 millesimi di secondo.",
                symbol: "eye.fill") { s, _ in (s.thresholdMs ?? 9999) < 200 },
    Achievement(id: "sotto-100", title: "Più veloce del lampo",
                hint: "Sotto i 100 millesimi di secondo.",
                symbol: "bolt.fill") { s, _ in (s.thresholdMs ?? 9999) < 100 },
    Achievement(id: "scrittura", title: "So anche scriverle",
                hint: "Hai completato una sessione in modalità Scrivi.",
                symbol: "keyboard.fill") { s, _ in s.mode == .scrittura && s.total > 0 },
    Achievement(id: "dieci-sessioni", title: "Dieci sessioni",
                hint: "Hai completato dieci sessioni in tutto.",
                symbol: "square.stack.3d.up.fill") { _, l in l.sessionsCompleted >= 10 },
  ]

  /// Aggiorna serie, punti e obiettivi dopo una sessione. Restituisce gli
  /// obiettivi appena sbloccati, per poterli mostrare una volta sola.
  @discardableResult
  static func apply(session: SessionRecord, to learner: inout Learner) -> [Achievement] {
    let today = dayKey(session.date)
    if let last = learner.lastSessionDay, last != today {
      let yesterday = dayKey(Calendar.current.date(byAdding: .day, value: -1, to: session.date) ?? session.date)
      learner.streakCurrent = (last == yesterday) ? learner.streakCurrent + 1 : 1
    } else if learner.lastSessionDay == nil {
      learner.streakCurrent = 1
    }
    learner.streakLongest = max(learner.streakLongest, learner.streakCurrent)
    learner.lastSessionDay = today
    learner.sessionsCompleted += 1
    learner.xp += xp(for: session, streak: learner.streakCurrent)

    var unlocked: [Achievement] = []
    for a in all where !learner.unlockedAchievements.contains(a.id) {
      if a.check(session, learner) {
        learner.unlockedAchievements.append(a.id)
        unlocked.append(a)
      }
    }
    return unlocked
  }

  static func dayKey(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }
}

// MARK: - Difficoltà: sfidante ma raggiungibile

/// Decide se proporre di salire o scendere di livello. La regola è quella
/// classica dell'apprendimento: si impara meglio intorno al 70-85% di successi.
/// Sotto il 60% si sta solo sbagliando; sopra il 90% non si sta imparando niente.
enum Difficulty {
  enum Suggestion: Equatable {
    case sali(Level)
    case scendi(Level)
    case resta

    var isChange: Bool { self != .resta }
  }

  static let comfortableLow = 0.60
  static let comfortableHigh = 0.90

  static func suggestion(for s: SessionRecord, current: Level) -> Suggestion {
    guard s.total >= 5 else { return .resta }
    let acc = s.accuracy
    let ladder: [Level] = [.inizio, .base, .intermedio, .avanzato]
    guard let i = ladder.firstIndex(of: current) else { return .resta }

    if acc > comfortableHigh, i < ladder.count - 1 { return .sali(ladder[i + 1]) }
    if acc < comfortableLow, i > 0 { return .scendi(ladder[i - 1]) }
    return .resta
  }

  /// Il messaggio da mostrare al ragazzo. Mai colpevolizzante.
  static func message(_ s: Suggestion) -> String? {
    switch s {
    case .sali(let l): "Questo livello ti sta stretto. Proviamo **\(l.title)**?"
    case .scendi(let l): "Andiamo un po' più piano con **\(l.title)**, così ti diverti di più."
    case .resta: nil
    }
  }
}
