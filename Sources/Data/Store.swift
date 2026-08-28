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

  /// Il turno si è fermato per una ragione che non riguarda chi legge: il Mac
  /// si è addormentato, il microfono è sparito.
  ///
  /// Senza questo campo l'informazione moriva dentro il motore, e la parola
  /// arrivava nel referto come «nessuna risposta» — cioè come un errore del
  /// ragazzo. Un referto clinico che attribuisce a un bambino un'omissione
  /// causata dal Mac dice una cosa falsa su di lui.
  var interrotto: Bool = false

  /// Quanti fotogrammi al secondo mostrava lo schermo, e se il Mac ne ha persi
  /// durante l'esposizione. Servono a chi legge il referto per sapere quanto
  /// fidarsi dei millesimi di secondo dichiarati.
  var refreshHz: Double?
  var frameSaltato: Bool = false

}

extension ItemRecord {
  /// Come sopra, ma qui cinque campi sono obbligatori davvero: una prova senza
  /// lo stimolo o senza l'esito non è una prova incompleta, è un dato che non
  /// significa niente.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.valore(.id, UUID())
    stimulus = try c.decode(String.self, forKey: .stimulus)
    response = try c.decode(String.self, forKey: .response)
    correct = try c.decode(Bool.self, forKey: .correct)
    exposureMs = try c.decode(Double.self, forKey: .exposureMs)
    latencyMs = try c.valore(.latencyMs, nil)
    errorKind = try c.decode(String.self, forKey: .errorKind)
    warmup = try c.valore(.warmup, false)
    interrotto = try c.valore(.interrotto, false)
    refreshHz = try c.valore(.refreshHz, nil)
    frameSaltato = try c.valore(.frameSaltato, false)
  }

  init(stimulus: String, response: String, correct: Bool, exposureMs: Double,
       latencyMs: Double?, errorKind: String, warmup: Bool = false,
       interrotto: Bool = false, refreshHz: Double? = nil, frameSaltato: Bool = false) {
    self.stimulus = stimulus
    self.response = response
    self.correct = correct
    self.exposureMs = exposureMs
    self.latencyMs = latencyMs
    self.errorKind = errorKind
    self.warmup = warmup
    self.interrotto = interrotto
    self.refreshHz = refreshHz
    self.frameSaltato = frameSaltato
  }
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

  /// Le parole che non sono venute, per poterle ripassare subito dopo.
  ///
  /// Le interrotte non ci sono: far ripetere una parola che non è mai
  /// comparsa sullo schermo è chiedere conto di una cosa mai successa.
  var missedWords: [String] {
    items.filter { !$0.correct && !$0.warmup && !$0.interrotto }.map(\.stimulus)
  }

  var errorCounts: [String: Int] {
    Dictionary(grouping: items.filter { !$0.correct && !$0.interrotto }, by: \.errorKind)
      .mapValues(\.count)
  }

}

extension SessionRecord {
  /// Legge tollerando i campi che non c'erano ancora quando questi dati sono
  /// stati salvati. Vedi `Sources/Data/LetturaTollerante.swift`.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    id = try c.valore(.id, id)
    learnerID = try c.valore(.learnerID, learnerID)
    date = try c.valore(.date, date)
    mode = try c.valore(.mode, mode)
    level = try c.valore(.level, level)
    setLabel = try c.valore(.setLabel, setLabel)
    correct = try c.valore(.correct, correct)
    total = try c.valore(.total, total)
    thresholdMs = try c.valore(.thresholdMs, thresholdMs)
    meanLatencyMs = try c.valore(.meanLatencyMs, meanLatencyMs)
    items = try c.valore(.items, items)
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

extension Learner {
  /// Legge tollerando i campi che non c'erano ancora quando questi dati sono
  /// stati salvati. Vedi `Sources/Data/LetturaTollerante.swift`.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    id = try c.valore(.id, id)
    name = try c.valore(.name, name)
    a11y = try c.valore(.a11y, a11y)
    config = try c.valore(.config, config)
    calibratedExposureMs = try c.valore(.calibratedExposureMs, calibratedExposureMs)
    calibratedAt = try c.valore(.calibratedAt, calibratedAt)
    xp = try c.valore(.xp, xp)
    streakCurrent = try c.valore(.streakCurrent, streakCurrent)
    streakLongest = try c.valore(.streakLongest, streakLongest)
    lastSessionDay = try c.valore(.lastSessionDay, lastSessionDay)
    sessionsCompleted = try c.valore(.sessionsCompleted, sessionsCompleted)
    unlockedAchievements = try c.valore(.unlockedAchievements, unlockedAchievements)
  }
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

  /// Vero solo quando ricominciare da zero non distruggerebbe l'ultima copia
  /// rimasta.
  ///
  /// Non coincide con `scritturaSospesa`, ed è la differenza che conta: la
  /// scrittura si sospende anche quando i file sono **sani** (scritti da una
  /// versione più recente) o quando la copia di sicurezza non è riuscita. In
  /// quei due casi offrire "Ricomincia da capo" vorrebbe dire proporre di
  /// cancellare per sempre subito dopo aver promesso di non toccare niente.
  @Published private(set) var ricominciareÈPossibile = false

  /// Come va detto il guasto nel titolo: le parole giuste cambiano se il
  /// problema è leggere o scrivere, e un titolo che contraddice il testo si
  /// legge male proprio nel momento in cui si è spaventati.
  enum GenereDelGuasto { case lettura, scrittura }
  @Published private(set) var genereDelGuasto: GenereDelGuasto = .lettura

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
  /// Mette via una sessione finita e restituisce gli obiettivi appena sbloccati.
  ///
  /// Sta qui, e non nella schermata del riepilogo, per una ragione precisa:
  /// mettere via una sessione **assegna anche i punti**, e i punti non si
  /// possono assegnare due volte. Prima il controllo «l'ho già messa via?»
  /// viveva in uno stato della schermata del riepilogo, e uno stato di una
  /// schermata è la cosa più fragile su cui appoggiare un conto che non si può
  /// rifare: basta che SwiftUI ricostruisca quella schermata — e lo fa quando
  /// vuole — perché il conto riparta da capo e i punti di quella sessione
  /// vengano dati due volte, insieme a un giorno in più nella serie.
  ///
  /// Adesso il controllo è l'identificativo della sessione, che non dipende da
  /// nessuno schermo: chiamare questo metodo dieci volte con la stessa
  /// sessione produce lo stesso risultato di chiamarlo una volta.
  @discardableResult
  func archivia(_ session: SessionRecord) -> [Achievement] {
    guard !history.contains(where: { $0.id == session.id }) else { return [] }
    var persona = current
    let sbloccati = Gamification.apply(session: session, to: &persona)
    var messaVia = session
    messaVia.learnerID = currentID
    history.append(messaVia)
    // `current` salva già da solo: si scrive per ultimo, così il salvataggio
    // è uno solo e comprende anche la sessione appena aggiunta.
    current = persona
    return sbloccati
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

  /// Che cosa si è trovato provando a leggere un file.
  ///
  /// La distinzione fra «non c'è» e «c'è ma non si legge» non è pignoleria: è
  /// il difetto. Prima le due cose tornavano tutte e due `nil`, e un file
  /// protetto da permessi sbagliati veniva scambiato per un primo avvio e
  /// sovrascritto — cioè esattamente la perdita silenziosa che si voleva
  /// chiudere.
  private enum Lettura {
    case nonCE
    case letto(Data)
    case guasto
  }

  /// Legge un file dalla cartella dell'app, e nient'altro.
  ///
  /// Passa dal percorso invece che dall'URL di proposito: le funzioni che
  /// leggono un URL accettano anche un indirizzo di rete, e il controllo
  /// automatico che tiene fuori la rete da questo programma non puo
  /// distinguere i due casi guardando il codice. Questa forma non ha quel
  /// doppio uso — la promessa resta dimostrabile senza eccezioni da spiegare.
  private func contenuto(di url: URL) -> Lettura {
    guard FileManager.default.fileExists(atPath: url.path) else { return .nonCE }
    guard let d = FileManager.default.contents(atPath: url.path) else { return .guasto }
    return .letto(d)
  }

  private func load() {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601

    var illeggibili: [String] = []

    // Prima di tutto: questi file sono stati scritti da una versione più
    // recente? Allora non si tocca niente, perché quello che questa versione
    // non sa leggere lo cancellerebbe salvando.
    if case .letto(let d) = contenuto(di: formatoURL) {
      if let f = try? dec.decode(Formato.self, from: d) {
        if f.versione > Self.versioneFormato {
          scritturaSospesa = true
          genereDelGuasto = .lettura
          // `ricominciareÈPossibile` resta falso di proposito: qui non è stata
          // fatta nessuna copia, perché i file sono sani — e offrire
          // "Ricomincia da capo" vorrebbe dire distruggere dati integri subito
          // dopo aver scritto che non si tocca niente.
          guastoNeiDati = """
            Questi dati sono stati salvati da una versione più recente di \
            MirrorScopio (formato \(f.versione), questa app conosce il \
            \(Self.versioneFormato)).

            Non ci scrivo sopra e non ho cancellato niente: aggiorna l'app e li \
            ritrovi tutti. La cartella è \(folder.path).
            """
          Log.warn("Formato dati più recente del previsto: scrittura sospesa.",
                   motivo: "formato \(f.versione) > \(Self.versioneFormato)")
          learners = [Learner(name: "")]
          currentID = learners.first?.id
          return
        }
      } else if !d.isEmpty {
        // Un `formato.json` che c'è ma non si legge può benissimo essere un
        // formato futuro scritto a metà. Ignorarlo e riscriverci sopra
        // "versione 1" cancellerebbe la sola cosa che avvisa del pericolo.
        illeggibili.append(metti(daParte: formatoURL, nome: "il segnalibro del formato"))
      }
    }

    switch contenuto(di: learnersURL) {
    case .nonCE: break
    case .guasto:
      illeggibili.append(metti(daParte: learnersURL, nome: "l'elenco delle persone"))
    case .letto(let d):
      if let l = try? dec.decode([Learner].self, from: d) {
        learners = l
      } else if !d.isEmpty {
        illeggibili.append(metti(daParte: learnersURL, nome: "l'elenco delle persone"))
      }
    }

    switch contenuto(di: historyURL) {
    case .nonCE: break
    case .guasto:
      illeggibili.append(metti(daParte: historyURL, nome: "lo storico degli allenamenti"))
    case .letto(let d):
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
      // e la fa una persona — ma solo se una copia esiste davvero.
      scritturaSospesa = true
      genereDelGuasto = .lettura
      ricominciareÈPossibile = copieFatte.count == illeggibili.count
      let elenco = illeggibili.joined(separator: " e ")
      let dovEFinita = ricominciareÈPossibile
        ? "I file sono al loro posto e ne ho fatto una copia di sicurezza qui accanto (\(copieFatte.joined(separator: ", "))). Finché non decidi tu, non ci scrivo sopra."
        : "I file sono al loro posto e non ci scrivo sopra. Non sono però riuscita a farne una copia: finché non l'hai messa al sicuro tu, non ti propongo di ricominciare da capo, perché sarebbe l'unica copia rimasta."
      guastoNeiDati = """
        Non sono riuscita a leggere \(elenco).

        Non ho cancellato niente. \(dovEFinita)

        La cartella è \(folder.path).
        """
      Log.warn("Dati illeggibili all'avvio: scrittura sospesa.", motivo: elenco)
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
    // Barriera, non decorazione: `ricominciareÈPossibile` è falso anche quando
    // la scrittura è sospesa perché sul disco c'è roba scritta da una versione
    // più nuova dell'app. Lì non c'è nessun guasto e nessuna copia: cancellare
    // vorrebbe dire distruggere dati integri di qualcun altro.
    guard ricominciareÈPossibile else { return }
    guastoNeiDati = nil
    scritturaSospesa = false
    ricominciareÈPossibile = false
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
      // E lo si ridice: la prima volta l'avviso c'era, ma chi lo chiude non
      // deve poi allenarsi tutto il pomeriggio credendo che il lavoro venga
      // salvato. Un guasto che si dice una volta sola torna a essere silenzio.
      genereDelGuasto = .scrittura
      guastoNeiDati = messaggioScritturaSospesa
      Log.warn("Salvataggio saltato: c'è un file che non si legge e nessuno ha ancora deciso che farne.")
      return
    }
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601

    // Prima si prepara tutto in memoria, poi si scrive. Così un errore di
    // codifica non lascia mai un file nuovo accanto a uno vecchio.
    let daScrivere: [(URL, Data)]
    do {
      daScrivere = [
        // Il segnalibro del formato va scritto per primo: se il Mac si spegne
        // a metà, deve essere già chiaro con che versione sono stati scritti i
        // file che seguono, non dopo.
        (formatoURL, try enc.encode(Formato(versione: Self.versioneFormato))),
        (learnersURL, try enc.encode(learners)),
        (historyURL, try enc.encode(history)),
      ]
    } catch {
      segnalaSalvataggioFallito(error, giaScritti: [])
      return
    }

    var fatti: [String] = []
    for (url, dati) in daScrivere {
      do {
        try dati.write(to: url, options: [.atomic, .completeFileProtection])
        // `.atomic` sostituisce il file: i permessi vanno riapplicati ogni volta.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: url.path)
        fatti.append(url.lastPathComponent)
      } catch {
        // Non si mente su che cosa è stato toccato: se il disco si riempie fra
        // il primo file e il secondo, il primo è già stato sostituito, e chi
        // legge deve saperlo per capire che cosa ha in mano.
        segnalaSalvataggioFallito(error, giaScritti: fatti)
        return
      }
    }
  }

  /// Il messaggio che spiega perché oggi non si salva. Sta in un posto solo
  /// perché va ridetto ogni volta che qualcuno prova a salvare.
  private var messaggioScritturaSospesa: String {
    """
    L'allenamento di oggi non viene salvato.

    C'è un file di dati che non sono riuscita a leggere, e scriverci sopra \
    cancellerebbe per sempre quello che c'è dentro. Preferisco perdere oggi \
    che perdere i mesi passati.

    La cartella è \(folder.path).
    """
  }

  private func segnalaSalvataggioFallito(_ errore: Error, giaScritti: [String]) {
    // Un salvataggio che fallisce di nascosto è peggio di uno che fallisce:
    // chi si allena crede che il lavoro sia al sicuro e scopre il contrario
    // settimane dopo. Disco pieno, permessi cambiati, cartella sparita — il
    // motivo cambia, il silenzio no.
    Log.warn("Salvataggio non riuscito", motivo: errore.localizedDescription)
    genereDelGuasto = .scrittura
    let statoDeiFile = giaScritti.isEmpty
      ? "Quello che c'era prima non è stato toccato."
      : "Attenzione: \(giaScritti.joined(separator: " e ")) era già stato aggiornato prima che il salvataggio si fermasse, il resto no."
    guastoNeiDati = """
      Non sono riuscita a salvare l'allenamento di oggi.

      Il Mac ha risposto: \(errore.localizedDescription)

      Di solito è il disco pieno o la cartella spostata. \(statoDeiFile) La \
      cartella è \(folder.path).
      """
  }

  var storageFolder: URL { folder }
}
