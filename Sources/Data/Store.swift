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

  /// Che cosa è andato storto leggendo i dati salvati, con parole che si
  /// possono leggere. Vuoto quando non c'è niente da dire.
  ///
  /// Esiste per un difetto che perdeva tutto in silenzio: se il file dei dati
  /// non si riusciva a leggere — un salvataggio interrotto, un disco pieno, un
  /// aggiornamento andato male — l'app ripartiva vuota come se fosse il primo
  /// giorno, e al primo salvataggio ci scriveva sopra. Mesi di lavoro di un
  /// bambino sparivano senza che comparisse niente sullo schermo.
  @Published private(set) var guastoNeiDati: String?

  /// Vero finché non si sa che fare del file illeggibile. Finché è vero **non
  /// si scrive niente su disco**: sovrascrivere è irreversibile, e la scelta
  /// non spetta al programma.
  @Published private(set) var scritturaSospesa = false

  private let folder: URL
  private let learnersURL: URL
  private let historyURL: URL
  private let formatoURL: URL

  /// Come sono fatti i file salvati oggi. Si alza di uno solo quando la forma
  /// dei dati cambia in un modo che una versione più vecchia non capirebbe.
  ///
  /// Serve a riconoscere il caso contrario di quello che si teme di solito: non
  /// un file vecchio letto da un'app nuova, ma un file **nuovo** letto da
  /// un'app vecchia — succede a chi torna indietro di versione, o a chi tiene
  /// due Mac. Senza questo numero l'app vecchia leggerebbe a metà e
  /// sovrascriverebbe il resto.
  static let versioneFormato = 1

  private struct Formato: Codable {
    var versione: Int
  }

  /// Dove finiscono i dati quando nessuno dice il contrario.
  ///
  /// Le prove che aprono l'applicazione vera hanno bisogno di scrivere da
  /// un'altra parte, e non è un dettaglio tecnico: qui dentro c'è il nome di un
  /// bambino e ogni suo errore di lettura. Una prova automatica che gira mille
  /// volte non deve poter sfiorare quel file — nemmeno per sbaglio, nemmeno una
  /// volta. La variabile d'ambiente la imposta il fascio di prove; nell'uso
  /// normale non esiste, e la cartella resta quella di sempre.
  static var cartellaPredefinita: URL {
    if let percorso = ProcessInfo.processInfo.environment["MIRRORSCOPIO_CARTELLA_DATI"],
       !percorso.isEmpty {
      return URL(fileURLWithPath: percorso, isDirectory: true)
    }
    return FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MirrorScopio", isDirectory: true)
  }

  init(folder: URL? = nil) {
    let base = folder ?? Self.cartellaPredefinita
    self.folder = base
    self.learnersURL = base.appendingPathComponent("learners.json")
    self.historyURL = base.appendingPathComponent("history.json")
    self.formatoURL = base.appendingPathComponent("formato.json")
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
    // Allenamento fatto: i promemoria di oggi si tolgono di mezzo. Nessuno
    // deve ricevere un invito a fare una cosa che ha appena finito.
    let serie = l.streakCurrent
    Task { await Promemoria().ripianifica(giaFattoOggi: true, serieGiorni: serie) }
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

    var illeggibili: [String] = []

    // Prima di tutto: questi file sono stati scritti da una versione più
    // recente? Allora non si tocca niente, perché quello che questa versione
    // non sa leggere lo cancellerebbe salvando.
    if let d = contenuto(di: formatoURL),
       let f = try? dec.decode(Formato.self, from: d),
       f.versione > Self.versioneFormato {
      scritturaSospesa = true
      guastoNeiDati = """
        Questi dati sono stati salvati da una versione più recente di \
        MirrorScopio (formato \(f.versione), questa app conosce il \
        \(Self.versioneFormato)).

        Non ci scrivo sopra: aggiorna l'app e li ritrovi tutti. La cartella è \
        \(folder.path).
        """
      Log.warn("Formato dati \(f.versione) più recente del previsto: scrittura sospesa.")
      learners = [Learner(name: "")]
      currentID = learners.first?.id
      return
    }

    if let d = contenuto(di: learnersURL) {
      if let l = try? dec.decode([Learner].self, from: d) {
        learners = l
      } else if !d.isEmpty {
        illeggibili.append(metti(daParte: learnersURL, nome: "l'elenco delle persone"))
      }
    }
    if let d = contenuto(di: historyURL) {
      if let h = try? dec.decode([SessionRecord].self, from: d) {
        history = h
      } else if !d.isEmpty {
        illeggibili.append(metti(daParte: historyURL, nome: "lo storico degli allenamenti"))
      }
    }

    if !illeggibili.isEmpty {
      // Non si riparte da zero facendo finta di niente, e soprattutto non si
      // scrive: il file originale resta dov'era, se ne fa una copia con la
      // data, e si dice che cosa è successo. Ricominciare vuoti è una scelta,
      // e la fa una persona.
      scritturaSospesa = true
      guastoNeiDati = """
        Non sono riuscita a leggere \(illeggibili.joined(separator: " e ")).

        Non ho cancellato niente: i file sono al loro posto e ne ho fatto una \
        copia di sicurezza qui accanto (\(copieFatte.joined(separator: ", "))). \
        Finché non decidi tu, non ci scrivo sopra.

        La cartella è \(folder.path).
        """
      Log.warn("Dati illeggibili all'avvio: \(illeggibili.joined(separator: ", ")). Scrittura sospesa.")
    }

    if learners.isEmpty {
      learners = [Learner(name: "")]
    }
    currentID = learners.first?.id
  }

  /// Nomi delle copie appena fatte, per poterli dire a chi legge.
  private var copieFatte: [String] = []

  /// Mette da parte una copia del file illeggibile prima di qualunque altra
  /// cosa. La copia porta la data, così due guasti diversi non si cancellano a
  /// vicenda.
  private func metti(daParte url: URL, nome: String) -> String {
    let quando = ISO8601DateFormatter()
    quando.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
    let marca = quando.string(from: Date())
      .replacingOccurrences(of: ":", with: "-")
    let copia = url.deletingPathExtension()
      .appendingPathExtension("\(marca).illeggibile.json")
    do {
      if FileManager.default.fileExists(atPath: copia.path) {
        try FileManager.default.removeItem(at: copia)
      }
      try FileManager.default.copyItem(at: url, to: copia)
      copieFatte.append(copia.lastPathComponent)
    } catch {
      Log.warn("Non sono riuscito a mettere da parte una copia del file illeggibile",
               motivo: "\(url.lastPathComponent): \(error.localizedDescription)")
    }
    return nome
  }

  /// Ricomincia da zero, di proposito. È l'unica strada che cancella qualcosa,
  /// e la sceglie una persona dopo aver letto che cosa è successo.
  func ricominciaDaCapo() {
    guastoNeiDati = nil
    scritturaSospesa = false
    save()
  }

  /// Toglie l'avviso dallo schermo senza cancellare niente: la scrittura resta
  /// sospesa, quindi la sessione di oggi non verrà salvata ma quelle di prima
  /// restano intatte sul disco. È la scelta che non fa danni.
  func mettiDaParteIlGuasto() {
    guastoNeiDati = nil
  }

  func save() {
    // Se i dati salvati non si sono potuti leggere, scriverci sopra li
    // distruggerebbe per sempre. Si preferisce non salvare la sessione di oggi
    // piuttosto che perdere quelle di sei mesi.
    guard !scritturaSospesa else {
      Log.warn("Salvataggio saltato: c'è un file illeggibile e nessuno ha ancora deciso che farne.")
      return
    }
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601
    do {
      try enc.encode(learners).write(to: learnersURL, options: [.atomic, .completeFileProtection])
      try enc.encode(history).write(to: historyURL, options: [.atomic, .completeFileProtection])
      try enc.encode(Formato(versione: Self.versioneFormato))
        .write(to: formatoURL, options: [.atomic, .completeFileProtection])
    } catch {
      // Un salvataggio che fallisce di nascosto è peggio di uno che fallisce:
      // chi si allena crede che il lavoro sia al sicuro e scopre il contrario
      // settimane dopo. Disco pieno, permessi cambiati, cartella sparita — il
      // motivo cambia, il silenzio no.
      Log.warn("Salvataggio non riuscito", motivo: error.localizedDescription)
      guastoNeiDati = """
        Non sono riuscita a salvare l'allenamento di oggi.

        Il Mac ha risposto: \(error.localizedDescription)

        Di solito è il disco pieno o la cartella spostata. La cartella è \
        \(folder.path). Quello che c'era prima non è stato toccato.
        """
      return
    }
    // `.atomic` sostituisce il file: i permessi vanno riapplicati ogni volta.
    for url in [learnersURL, historyURL, formatoURL] {
      try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                             ofItemAtPath: url.path)
    }
  }

  var storageFolder: URL { folder }
}
