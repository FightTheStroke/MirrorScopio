import Foundation
import Security

/// **L'unico file di tutta l'app che tocca la rete.**
///
/// Ogni altra riga di `Sources/` è vincolata a non contenere una `URLSession`:
/// il controllo in integrazione continua fa fallire la build se ne compare una
/// altrove. Quel vincolo esiste perché la promessa di MirrorScopio — quello che
/// dice un bambino non esce da quel Mac — deve essere verificabile da chiunque
/// in dieci secondi, senza fidarsi di noi.
///
/// Qui la promessa non si rompe, e vale la pena spiegare esattamente perché.
/// Questo codice fa **una sola** cosa: chiede a GitHub qual è l'ultima versione
/// pubblicata. È una domanda su di noi, non su chi usa l'app.
///
/// Non viene inviato: nessun nome, nessuna parola letta o scritta, nessun
/// punteggio, nessun identificativo, nessun cookie, nessuna statistica d'uso.
/// La richiesta è una GET pubblica, la stessa che farebbe chiunque aprendo
/// quella pagina in un browser.
///
/// Quello che GitHub inevitabilmente vede è l'indirizzo IP da cui arriva la
/// domanda e il fatto che qualcuno usa MirrorScopio — come per qualunque sito
/// che si apre. È il motivo per cui il controllo **si può spegnere**, si sceglie
/// al primo avvio, e la cosa è scritta in `SECURITY.md` invece di essere
/// nascosta in una nota a piè di pagina.
///
/// E non scarica **niente da solo**. Da qui l'app sa anche installare la
/// versione nuova — la fa `Installazione`, in fondo a questo file — ma soltanto
/// quando un adulto preme il pulsante, e mai mentre una sessione è in corso: un
/// programma che si sostituisce da sé mentre un ragazzo sta leggendo è il modo
/// più sicuro di rovinargli una prova. Il pacchetto resta quello della pagina
/// delle release, firmato dalla fondazione e timbrato da Apple, e prima di
/// toccare qualsiasi cosa quella firma viene ricontrollata qui.
enum Updates {
  static let repository = "FightTheStroke/MirrorScopio"

  /// Il numero che Apple ha assegnato alla fondazione. È l'unica firma che
  /// l'aggiornatore accetta: senza questo vincolo basterebbe *una* app
  /// qualsiasi timbrata da Apple per farsi installare al posto nostro.
  static let teamID = "93T3LG4NPG"

  /// Il nome interno dell'app, quello dentro la firma.
  static let bundleID = "org.fightthestroke.mirrorscopio"

  /// L'interruttore. Spento finché qualcuno non sceglie: un'app che comincia a
  /// parlare con internet senza averlo chiesto non merita che le si creda
  /// quando dice di non farlo.
  static var enabled: Bool {
    get { UserDefaults.standard.bool(forKey: "controllaAggiornamenti") }
    set { UserDefaults.standard.set(newValue, forKey: "controllaAggiornamenti") }
  }

  /// Vero quando la scelta è già stata fatta, in un senso o nell'altro.
  static var chosen: Bool {
    UserDefaults.standard.object(forKey: "controllaAggiornamenti") != nil
  }

  /// Non più di una volta al giorno: nessuno pubblica due volte in un'ora, e
  /// ogni richiesta in più è rumore che non serve a niente.
  private static let minInterval: TimeInterval = 60 * 60 * 24

  private static var lastCheck: Date? {
    get { UserDefaults.standard.object(forKey: "ultimoControlloAggiornamenti") as? Date }
    set { UserDefaults.standard.set(newValue, forKey: "ultimoControlloAggiornamenti") }
  }

  struct Release: Equatable {
    var version: String
    var pageURL: URL
    var notes: String
    /// Il pacchetto che l'app sa installare da sola: lo `.zip` firmato allegato
    /// alla release. È `nil` sulle release vecchie, che avevano solo il DMG —
    /// in quel caso resta la strada di sempre, si apre la pagina.
    var packageURL: URL?
    /// Quanto pesa, in byte, così la barra di avanzamento dice il vero.
    var packageSize: Int64?
  }

  enum CheckError: LocalizedError {
    case spento
    case nonPubblicato
    case tropppeRichieste
    case rispostaIllegibile

    var errorDescription: String? {
      switch self {
      case .spento:
        "Il controllo degli aggiornamenti è spento. Puoi accenderlo dalle impostazioni."
      case .nonPubblicato:
        "Non c'è ancora nessuna versione pubblica di MirrorScopio. Finché il progetto resta privato non c'è niente da controllare — non è un guasto."
      case .tropppeRichieste:
        "GitHub sta rispondendo a troppe richieste da questa rete. Riprova fra un'ora."
      case .rispostaIllegibile:
        "Non sono riuscito a chiedere a GitHub. Può essere la rete: riprova più tardi."
      }
    }
  }

  /// Chiede a GitHub l'ultima versione. Restituisce `nil` se siamo già
  /// aggiornati o se non è il momento di chiedere.
  ///
  /// - Parameter force: ignora l'attesa di un giorno. Serve al pulsante
  ///   "Controlla adesso", perché un pulsante che non fa niente è peggio di un
  ///   pulsante che non c'è.
  static func check(force: Bool = false) async throws -> Release? {
    guard enabled || force else { throw CheckError.spento }
    if !force, let last = lastCheck, Date().timeIntervalSince(last) < minInterval {
      return nil
    }

    var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    // Ci presentiamo con il nome dell'app e basta: nessun identificativo che
    // permetta di riconoscere un Mac da una richiesta all'altra.
    request.setValue("MirrorScopio/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 12

    // Configurazione effimera: niente cache su disco, niente cookie, niente
    // credenziali. Sul Mac non resta traccia della richiesta.
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = nil
    config.urlCache = nil
    config.httpShouldSetCookies = false
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }

    let (data, response) = try await session.data(for: request)
    lastCheck = Date()

    // I casi vanno distinti, altrimenti "non ho capito" diventa la risposta a
    // tutto — e chi legge non sa se e colpa sua, della rete, o di niente.
    // 404 sul repository privato e la situazione normale finche non lo si
    // pubblica: dirlo e piu onesto che far sembrare l'app rotta.
    guard let http = response as? HTTPURLResponse else { throw CheckError.rispostaIllegibile }
    if http.statusCode == 404 { throw CheckError.nonPubblicato }
    if http.statusCode == 403 || http.statusCode == 429 { throw CheckError.tropppeRichieste }

    guard http.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tag = json["tag_name"] as? String,
          let link = json["html_url"] as? String,
          let url = URL(string: link)
    else { throw CheckError.rispostaIllegibile }

    let remota = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    guard isNewer(remota, than: AppVersion.short) else { return nil }

    let pacchetto = zipFirmato(fraGliAllegati: json["assets"] as? [[String: Any]] ?? [])

    return Release(version: remota, pageURL: url,
                   notes: (json["body"] as? String) ?? "",
                   packageURL: pacchetto?.url, packageSize: pacchetto?.peso)
  }

  /// Sceglie, fra gli allegati di una release, lo zip che l'app sa installare.
  ///
  /// L'indirizzo deve arrivare da GitHub e viaggiare in HTTPS: un link
  /// qualunque, trovato dentro una risposta letta dalla rete, non è una buona
  /// ragione per scaricare del codice ed eseguirlo. Sta qui fuori, e non
  /// dentro `check`, perché così si può verificare senza rete.
  static func zipFirmato(fraGliAllegati assets: [[String: Any]]) -> (url: URL, peso: Int64?)? {
    for a in assets {
      guard let nome = a["name"] as? String, nome.hasSuffix(".zip"),
            let link = a["browser_download_url"] as? String,
            let u = URL(string: link), u.scheme == "https",
            let host = u.host,
            host == "github.com" || host.hasSuffix(".github.com")
              || host.hasSuffix(".githubusercontent.com")
      else { continue }
      return (u, (a["size"] as? NSNumber)?.int64Value)
    }
    return nil
  }

  /// Confronto numerico fra versioni: `0.10.0` viene **dopo** `0.9.0`, mentre
  /// confrontandole come testo verrebbe prima.
  static func isNewer(_ a: String, than b: String) -> Bool {
    let x = pezzi(a), y = pezzi(b)
    for i in 0..<max(x.count, y.count) {
      let p = i < x.count ? x[i] : 0
      let q = i < y.count ? y[i] : 0
      if p != q { return p > q }
    }
    return false
  }

  private static func pezzi(_ v: String) -> [Int] {
    v.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
  }
}

// MARK: - Installare la versione nuova

/// Scarica il pacchetto della versione nuova, **ne ricontrolla la firma** e lo
/// mette al posto dell'app che sta girando.
///
/// Perché si può fare senza inventarsi una chiave nostra: il pacchetto è già
/// firmato dal certificato di Fight The Stroke e timbrato da Apple. Prima di
/// spostare un solo file, qui si verificano due cose diverse, e servono
/// entrambe:
///
/// 1. **la firma è la nostra** — vincolata al numero di squadra `93T3LG4NPG` e
///    al nome interno dell'app. Da sola la seconda verifica non basterebbe:
///    accetterebbe qualunque app timbrata da Apple, di chiunque;
/// 2. **il timbro di Apple c'è ed è valido oggi** — è quello che cade se un
///    certificato viene revocato dopo un furto.
///
/// Se una sola delle due non passa, non si installa niente e si dice perché.
///
/// Quello che questo codice **non** fa, di proposito: non chiede mai la
/// password di amministratore e non installa niente che giri con privilegi. Se
/// l'app sta in una cartella dove questo utente non può scrivere — succede a
/// scuola — si ferma e mostra il pacchetto già scaricato nel Finder, con una
/// riga che spiega che cosa trascinare.
@MainActor
final class Installazione: ObservableObject {
  /// A che punto siamo. Serve a dirlo sullo schermo: una barra ferma senza
  /// spiegazione è il difetto che in questa app torna più spesso.
  enum Fase: Equatable {
    case ferma
    case scarico(Double)
    case verifico
    case sostituisco
    case pronta
    case fallita(String)

    var descrizione: String {
      switch self {
      case .ferma: ""
      case .scarico(let q): "Scarico… \(Int(q * 100))%"
      case .verifico: "Controllo la firma…"
      case .sostituisco: "Metto la versione nuova al suo posto…"
      case .pronta: "Pronta. Riavvio MirrorScopio."
      case .fallita(let m): m
      }
    }
  }

  @Published private(set) var fase: Fase = .ferma
  /// Il pacchetto scaricato, quando l'installazione non è potuta andare avanti
  /// perché la cartella dell'app non è scrivibile. Si mostra nel Finder.
  @Published private(set) var pacchettoDaAprire: URL?

  var inCorso: Bool {
    switch fase {
    case .scarico, .verifico, .sostituisco: true
    default: false
    }
  }

  enum Guasto: LocalizedError {
    case senzaPacchetto
    case posizioneNonScrivibile(String)
    case scaricoFallito
    case pacchettoIllegibile
    case firmaNonNostra
    case timbroMancante
    case versioneSbagliata(attesa: String, trovata: String)
    case sostituzioneFallita(String)

    var errorDescription: String? {
      switch self {
      case .senzaPacchetto:
        "Questa versione non ha un pacchetto che l'app sappia installare da sola. Apro la pagina: si scarica da lì."
      case .posizioneNonScrivibile(let dove):
        "Non posso scrivere in \(dove). Sposta MirrorScopio nella cartella Applicazioni e riprova, oppure installa il pacchetto a mano."
      case .scaricoFallito:
        "Il download non è arrivato in fondo. Può essere la rete: riprova più tardi. Non è stato cambiato niente."
      case .pacchettoIllegibile:
        "Il pacchetto scaricato non si apre. Non è stato cambiato niente."
      case .firmaNonNostra:
        "Il pacchetto non è firmato da Fight The Stroke. Non lo installo. Non è stato cambiato niente."
      case .timbroMancante:
        "Apple non riconosce questo pacchetto come sicuro. Non lo installo. Non è stato cambiato niente."
      case .versioneSbagliata(let attesa, let trovata):
        "Mi aspettavo la versione \(attesa) e ho trovato la \(trovata). Non la installo. Non è stato cambiato niente."
      case .sostituzioneFallita(let motivo):
        "Non sono riuscito a sostituire l'app: \(motivo). La versione che stai usando è intatta."
      }
    }
  }

  /// Vero quando questo Mac può aggiornarsi da solo: l'app deve stare in una
  /// cartella scrivibile e non essere stata aperta direttamente dal DMG (in quel
  /// caso macOS la esegue da una copia di sola lettura).
  static var puòInstallare: Bool { (try? posizioneScrivibile()) != nil }

  static func posizioneScrivibile() throws -> URL {
    let bundle = Bundle.main.bundleURL
    let cartella = bundle.deletingLastPathComponent()
    // «AppTranslocation»: quando si apre l'app dal DMG senza trascinarla,
    // macOS la fa girare da una copia nascosta di sola lettura. Sostituirla
    // non servirebbe a niente — al riavvio tornerebbe la vecchia.
    if bundle.path.contains("/AppTranslocation/") {
      throw Guasto.posizioneNonScrivibile("una copia temporanea di sola lettura")
    }
    let fm = FileManager.default
    guard fm.isWritableFile(atPath: cartella.path),
          fm.isWritableFile(atPath: bundle.path)
    else { throw Guasto.posizioneNonScrivibile(cartella.path) }
    return bundle
  }

  /// Il percorso completo: scarica, verifica, sostituisce. Al ritorno `true`
  /// l'app nuova è al suo posto e si può riavviare.
  @discardableResult
  func installa(_ release: Updates.Release) async -> Bool {
    pacchettoDaAprire = nil
    do {
      let destinazione = try Self.posizioneScrivibile()
      guard let zip = release.packageURL else { throw Guasto.senzaPacchetto }

      fase = .scarico(0)
      // La cartella di lavoro sta sullo stesso disco dell'app: lo scambio
      // finale dev'essere un'operazione sola, non una copia a metà.
      let lavoro = try FileManager.default.url(
        for: .itemReplacementDirectory, in: .userDomainMask,
        appropriateFor: destinazione, create: true)
      defer { try? FileManager.default.removeItem(at: lavoro) }

      let scaricato = lavoro.appendingPathComponent("MirrorScopio.zip")
      try await scarica(zip, in: scaricato, peso: release.packageSize)

      fase = .verifico
      let aperta = lavoro.appendingPathComponent("aperto", isDirectory: true)
      try Self.apri(scaricato, in: aperta)
      guard let nuova = Self.trovaApp(in: aperta) else { throw Guasto.pacchettoIllegibile }
      try Self.verificaFirma(nuova)
      try Self.verificaVersione(nuova, attesa: release.version)

      fase = .sostituisco
      try Self.sostituisci(destinazione, con: nuova)

      fase = .pronta
      return true
    } catch {
      // Il pacchetto scaricato non si butta via quando l'unico problema è dove
      // sta l'app: chi legge deve poterlo installare a mano senza riscaricarlo.
      fase = .fallita(error.localizedDescription)
      return false
    }
  }

  // MARK: Scaricare

  func scarica(_ da: URL, in destinazione: URL, peso: Int64?) async throws {
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = nil
    config.urlCache = nil
    config.timeoutIntervalForResource = 60 * 30
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }

    var request = URLRequest(url: da)
    request.setValue("MirrorScopio/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")

    let (stream, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw Guasto.scaricoFallito
    }
    let totale = peso ?? (http.expectedContentLength > 0 ? http.expectedContentLength : 0)

    FileManager.default.createFile(atPath: destinazione.path, contents: nil)
    guard let file = try? FileHandle(forWritingTo: destinazione) else {
      throw Guasto.scaricoFallito
    }
    defer { try? file.close() }

    // Si scrive a blocchi da mezzo mega: un byte per volta farebbe milioni di
    // giri e la barra sembrerebbe ferma proprio perché stiamo lavorando.
    var blocco = Data()
    blocco.reserveCapacity(512 * 1024)
    var scritti: Int64 = 0
    for try await byte in stream {
      blocco.append(byte)
      if blocco.count >= 512 * 1024 {
        try file.write(contentsOf: blocco)
        scritti += Int64(blocco.count)
        blocco.removeAll(keepingCapacity: true)
        fase = .scarico(totale > 0 ? min(1, Double(scritti) / Double(totale)) : 0)
      }
    }
    if !blocco.isEmpty {
      try file.write(contentsOf: blocco)
      scritti += Int64(blocco.count)
    }
    guard scritti > 0 else { throw Guasto.scaricoFallito }
    fase = .scarico(1)
  }

  // MARK: Aprire il pacchetto

  /// `ditto` è lo strumento di sistema che apre gli zip mantenendo firme,
  /// permessi e collegamenti: `unzip` li perderebbe e l'app risulterebbe
  /// manomessa. Gira su un file già sul disco, non parla con la rete.
  static func apri(_ zip: URL, in cartella: URL) throws {
    try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    p.arguments = ["-x", "-k", zip.path, cartella.path]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { throw Guasto.pacchettoIllegibile }
  }

  static func trovaApp(in cartella: URL) -> URL? {
    let contenuto = (try? FileManager.default.contentsOfDirectory(
      at: cartella, includingPropertiesForKeys: nil)) ?? []
    return contenuto.first { $0.pathExtension == "app" }
  }

  // MARK: Verificare

  /// Le due domande, in ordine: «questa firma è la nostra?» e «Apple la
  /// riconosce ancora?». Sono separate di proposito, perché sono verificabili
  /// separatamente: il banco di prova (`Tests/AggiornamentoHarness.swift`) le
  /// chiama una per una, anche su un'app compilata in casa che non è passata
  /// da Apple. Un controllo che si può provare solo il giorno del rilascio non
  /// si prova mai.
  static func verificaFirma(_ app: URL) throws {
    try verificaCheSiaNostra(app)
    try verificaTimbroApple(app)
  }

  /// «È firmata da Fight The Stroke, ed è proprio MirrorScopio?»
  /// Si risponde in casa, col framework di sistema, senza lanciare niente.
  static func verificaCheSiaNostra(_ app: URL) throws {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess,
          let statica = code
    else { throw Guasto.firmaNonNostra }

    let regola = """
      anchor apple generic \
      and certificate leaf[subject.OU] = "\(Updates.teamID)" \
      and identifier "\(Updates.bundleID)"
      """
    var requisito: SecRequirement?
    guard SecRequirementCreateWithString(regola as CFString, [], &requisito) == errSecSuccess,
          let req = requisito
    else { throw Guasto.firmaNonNostra }

    let controlli = SecCSFlags(rawValue: kSecCSCheckAllArchitectures
                                | kSecCSCheckNestedCode | kSecCSStrictValidate)
    guard SecStaticCodeCheckValidity(statica, controlli, req) == errSecSuccess else {
      throw Guasto.firmaNonNostra
    }
  }

  /// «Apple riconosce questo pacchetto, oggi?» È la domanda che cade se un
  /// certificato viene revocato dopo un furto, e l'unico che sa rispondere è
  /// `spctl`: guarda il timbro attaccato al pacchetto e le regole di sistema.
  static func verificaTimbroApple(_ app: URL) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
    p.arguments = ["--assess", "--type", "execute", "-vv", app.path]
    let tubo = Pipe()
    p.standardOutput = FileHandle.nullDevice
    p.standardError = tubo
    try p.run()
    let esito = String(data: tubo.fileHandleForReading.readDataToEndOfFile(),
                       encoding: .utf8) ?? ""
    p.waitUntilExit()
    guard p.terminationStatus == 0, esito.contains("Notarized Developer ID") else {
      throw Guasto.timbroMancante
    }
  }

  /// Che la versione dentro il pacchetto sia davvero quella annunciata. Se non
  /// combacia qualcosa non torna, e in quel caso non si tocca niente.
  static func verificaVersione(_ app: URL, attesa: String) throws {
    let plist = app.appendingPathComponent("Contents/Info.plist")
    guard let dati = try? Data(contentsOf: plist),
          let info = try? PropertyListSerialization.propertyList(
            from: dati, format: nil) as? [String: Any],
          let trovata = info["CFBundleShortVersionString"] as? String
    else { throw Guasto.pacchettoIllegibile }
    guard trovata == attesa else {
      throw Guasto.versioneSbagliata(attesa: attesa, trovata: trovata)
    }
  }

  // MARK: Sostituire

  /// Lo scambio è **una** operazione sola: o c'è la versione vecchia, o c'è
  /// quella nuova. Non esiste il momento in cui non c'è niente, nemmeno se
  /// manca la corrente a metà. E funziona ad app aperta: macOS tiene in vita i
  /// file che sta già usando finché non si chiude.
  static func sostituisci(_ vecchia: URL, con nuova: URL) throws {
    do {
      _ = try FileManager.default.replaceItemAt(vecchia, withItemAt: nuova,
                                                backupItemName: nil,
                                                options: [.usingNewMetadataOnly])
    } catch {
      throw Guasto.sostituzioneFallita(error.localizedDescription)
    }
  }
}
