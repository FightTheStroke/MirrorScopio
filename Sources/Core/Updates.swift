import Foundation

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
/// E non scarica né installa niente da solo. Un aggiornamento automatico
/// significa che un programma decide di sostituirsi mentre un ragazzo lo sta
/// usando: qui l'app dice soltanto "ce n'è una nuova", e chi si occupa di lui
/// decide se e quando. Il pacchetto si prende dalla pagina delle release, dove
/// è firmato dalla fondazione e timbrato da Apple.
enum Updates {
  static let repository = "FightTheStroke/MirrorScopio"

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
  }

  enum CheckError: LocalizedError {
    case spento
    case rispostaIllegibile

    var errorDescription: String? {
      switch self {
      case .spento:
        "Il controllo degli aggiornamenti è spento. Puoi accenderlo dalle impostazioni."
      case .rispostaIllegibile:
        "GitHub ha risposto in un modo che non ho capito. Riprova più tardi."
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

    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tag = json["tag_name"] as? String,
          let link = json["html_url"] as? String,
          let url = URL(string: link)
    else { throw CheckError.rispostaIllegibile }

    let remota = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    guard isNewer(remota, than: AppVersion.short) else { return nil }

    return Release(version: remota, pageURL: url,
                   notes: (json["body"] as? String) ?? "")
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
