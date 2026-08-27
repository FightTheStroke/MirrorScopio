import Foundation

// MARK: - Che cosa resta salvato

/// Una parola della sessione, con il suo esito. È l'unità del registro.
struct ItemRecord: Codable, Identifiable {
  var id = UUID()
  var stimulus: String
  var response: String
  var correct: Bool
  var exposureMs: Double
  var latencyMs: Double?
  var errorKind: String
  var warmup: Bool = false
}

/// Una sessione conclusa. È quello che alimenta dashboard, progressi e PDF.
struct SessionRecord: Codable, Identifiable {
  var id = UUID()
  var learnerID: UUID?
  var date = Date()
  var mode: SessionMode = .lettura
  var level: Level = .base
  var setLabel: String = ""
  var correct: Int = 0
  var total: Int = 0
  var thresholdMs: Double?
  var meanLatencyMs: Double?
  var items: [ItemRecord] = []

  var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }

  /// Le parole sbagliate, per poterle ripassare subito dopo.
  var missedWords: [String] {
    items.filter { !$0.correct && !$0.warmup }.map(\.stimulus)
  }

  var errorCounts: [String: Int] {
    Dictionary(grouping: items.filter { !$0.correct }, by: \.errorKind)
      .mapValues(\.count)
  }
}

/// Chi usa l'app. Il modello dei dati regge più persone sullo stesso Mac
/// (fratelli, più pazienti di un logopedista), ma **oggi l'interfaccia ne
/// mostra una sola**: `addLearner` esiste e funziona, non è ancora collegata a
/// nessun pulsante. Detto qui perché un commento che promette una funzione
/// inesistente è un piccolo inganno a chi legge il codice.
struct Learner: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String = ""
  var a11y = A11ySettings()
  var config = SessionConfig()
  /// Velocità di partenza misurata dal test iniziale, in millisecondi.
  var calibratedExposureMs: Double?
  var calibratedAt: Date?
  var xp: Int = 0
  var streakCurrent: Int = 0
  var streakLongest: Int = 0
  var lastSessionDay: String?
  /// Quante sessioni sono state portate a termine, in tutto.
  var sessionsCompleted: Int = 0
  var unlockedAchievements: [String] = []
}

// MARK: - Archivio su disco

/// Tutto vive in `~/Library/Application Support/MirrorScopio/`, in chiaro, in JSON:
/// niente rete, niente account, e un adulto può leggere o cancellare i file a mano.
@MainActor
final class Store: ObservableObject {
  @Published var learners: [Learner] = []
  @Published var currentID: UUID?
  @Published private(set) var history: [SessionRecord] = []

  private let folder: URL
  private let learnersURL: URL
  private let historyURL: URL

  init(folder: URL? = nil) {
    let base = folder ?? FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MirrorScopio", isDirectory: true)
    self.folder = base
    self.learnersURL = base.appendingPathComponent("learners.json")
    self.historyURL = base.appendingPathComponent("history.json")
    // 0o700: solo l'utente che ha creato la cartella può entrarci. Qui dentro
    // c'è il nome di un bambino e ogni suo errore di lettura.
    try? FileManager.default.createDirectory(
      at: base,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    load()
  }

  var current: Learner {
    get {
      if let id = currentID, let l = learners.first(where: { $0.id == id }) { return l }
      return learners.first ?? Learner(name: "")
    }
    set {
      if let i = learners.firstIndex(where: { $0.id == newValue.id }) {
        learners[i] = newValue
      } else {
        learners.append(newValue)
      }
      currentID = newValue.id
      save()
    }
  }

  /// Modifica chi sta usando l'app adesso e salva.
  func update(_ change: (inout Learner) -> Void) {
    var l = current
    change(&l)
    current = l
  }

  /// Le sessioni di chi sta usando l'app adesso, dalla più recente.
  var currentHistory: [SessionRecord] {
    history.filter { $0.learnerID == currentID }.sorted { $0.date > $1.date }
  }

  /// Non ancora raggiungibile dall'interfaccia: vedi la nota su `Learner`.
  func addLearner(name: String) {
    var l = Learner(name: name)
    l.a11y = A11ySettings()
    learners.append(l)
    currentID = l.id
    save()
  }

  func record(_ session: SessionRecord) {
    var s = session
    s.learnerID = currentID
    history.append(s)
    var l = current
    Gamification.apply(session: s, to: &l)
    current = l
    save()
  }

  /// Usata quando punti e obiettivi sono già stati calcolati altrove:
  /// evita di assegnarli due volte alla stessa sessione.
  func recordAlreadyScored(_ session: SessionRecord) {
    guard !history.contains(where: { $0.id == session.id }) else { return }
    history.append(session)
    save()
  }

  func deleteHistory() {
    history.removeAll { $0.learnerID == currentID }
    save()
  }

  /// Cancella una persona **e tutto ciò che la riguarda**.
  ///
  /// Il diritto alla cancellazione deve essere un pulsante. Un genitore non
  /// aprirà mai `~/Library` per svuotare un file JSON a mano.
  func deleteLearner(_ id: UUID) {
    history.removeAll { $0.learnerID == id }
    learners.removeAll { $0.id == id }
    if learners.isEmpty { learners = [Learner(name: "")] }
    if currentID == id { currentID = learners.first?.id }
    save()
  }

  // MARK: - Lettura e scrittura

  /// Legge un file dalla cartella dell'app, e nient'altro.
  ///
  /// Passa dal percorso invece che dall'URL di proposito: le funzioni che
  /// leggono un URL accettano anche un indirizzo di rete, e il controllo
  /// automatico che tiene fuori la rete da questo programma non puo
  /// distinguere i due casi guardando il codice. Questa forma non ha quel
  /// doppio uso — la promessa resta dimostrabile senza eccezioni da spiegare.
  private func contenuto(di url: URL) -> Data? {
    FileManager.default.contents(atPath: url.path)
  }

  private func load() {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    if let d = contenuto(di: learnersURL),
       let l = try? dec.decode([Learner].self, from: d) {
      learners = l
    }
    if let d = contenuto(di: historyURL),
       let h = try? dec.decode([SessionRecord].self, from: d) {
      history = h
    }
    if learners.isEmpty {
      learners = [Learner(name: "")]
    }
    currentID = learners.first?.id
  }

  func save() {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601
    try? enc.encode(learners).write(to: learnersURL, options: [.atomic, .completeFileProtection])
    try? enc.encode(history).write(to: historyURL, options: [.atomic, .completeFileProtection])
    // `.atomic` sostituisce il file: i permessi vanno riapplicati ogni volta.
    for url in [learnersURL, historyURL] {
      try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                             ofItemAtPath: url.path)
    }
  }

  var storageFolder: URL { folder }
}
