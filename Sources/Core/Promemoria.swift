import Foundation
@preconcurrency import UserNotifications

/// I promemoria giornalieri: un invito gentile a tornare, spegnibile.
///
/// Un esercizio di logopedia rende se lo si fa ogni giorno, e quello che manca
/// quasi mai è la voglia: è il ricordarsene. Questo è l'unico compito di questo
/// file — chiedere al Mac di mostrare una notifica **tutta locale** all'ora
/// scelta. Non tocca la rete: `UserNotifications` mostra un avviso su questo
/// stesso Mac, niente esce da qui.
///
/// Due promesse che questo progetto ha già fatto e che qui vanno mantenute:
///
/// - **Se l'app sa qualcosa, lo dice.** Il permesso delle notifiche si chiede
///   *solo* quando si accende l'interruttore, mai a freddo. E se il permesso è
///   negato, un interruttore acceso che non fa arrivare niente sarebbe una
///   bugia: lo stato negato viene reso visibile (`permesso`) perché chi guarda
///   le impostazioni possa rimediare.
/// - **Non colpevolizzare.** Il testo non dice mai «non ti sei allenato» né «hai
///   saltato». È un invito che si può ignorare senza sentirsi in debito.
///
/// E soprattutto: **non si notifica se l'esercizio di oggi è già stato fatto.**
/// Per questo i promemoria non sono un unico avviso che si ripete all'infinito
/// (quello scatterebbe anche nei giorni in cui il ragazzo ha già letto le sue
/// parole, e nessun codice gira per fermarlo mentre l'app è chiusa), ma una
/// fila di avvisi per i prossimi giorni, ricalcolata a ogni avvio e alla fine
/// di ogni sessione: il giorno già allenato viene semplicemente saltato.
@MainActor
final class Promemoria: ObservableObject {

  /// Quali giorni ricordare. Poche opzioni di proposito.
  enum Giorni: String, CaseIterable, Codable, Identifiable {
    case tutti, feriali

    var id: String { rawValue }

    var label: String {
      switch self {
      case .tutti: "Tutti i giorni"
      case .feriali: "Dal lunedì al venerdì"
      }
    }

    /// `weekday` di `Calendar`: 1 è domenica, 7 è sabato.
    func includeGiorno(weekday: Int) -> Bool {
      switch self {
      case .tutti: true
      case .feriali: (2...6).contains(weekday)
      }
    }
  }

  // MARK: - Stato scelto dall'utente (tiene in `UserDefaults`)

  /// La posizione dell'interruttore: che cosa **vuole** l'utente. Se il permesso
  /// è negato resta acceso lo stesso, così l'app può dire che manca qualcosa
  /// invece di spegnersi in silenzio.
  @Published private(set) var acceso: Bool
  @Published private(set) var ora: Int
  @Published private(set) var minuto: Int
  @Published private(set) var giorni: Giorni

  /// Che cosa il Mac ci ha davvero concesso. Reso visibile perché un permesso
  /// negato taciuto è esattamente il difetto che questo progetto non ripete.
  @Published private(set) var permesso: UNAuthorizationStatus = .notDetermined

  private let difese = UserDefaults.standard
  private enum Chiave {
    static let acceso = "promemoriaAcceso"
    static let ora = "promemoriaOra"
    static let minuto = "promemoriaMinuto"
    static let giorni = "promemoriaGiorni"
  }

  /// Per quanti giorni in avanti preparare gli avvisi. Oltre, se l'app non
  /// viene mai riaperta, i promemoria si esauriscono: dopo settimane di
  /// silenzio insistere non aiuterebbe nessuno.
  private let giorniInAvanti = 14
  private let prefissoID = "promemoria.giorno."

  init() {
    acceso = difese.bool(forKey: Chiave.acceso)
    ora = difese.object(forKey: Chiave.ora) as? Int ?? 17
    minuto = difese.object(forKey: Chiave.minuto) as? Int ?? 0
    giorni = (difese.string(forKey: Chiave.giorni)).flatMap(Giorni.init) ?? .tutti
  }

  // MARK: - L'orario, comodo da mostrare in un selettore

  /// L'ora scelta come `Date` di oggi, per legarla a un `DatePicker`.
  var orario: Date {
    Calendar.current.date(bySettingHour: ora, minute: minuto, second: 0, of: Date()) ?? Date()
  }

  var orarioTesto: String {
    String(format: "%02d:%02d", ora, minuto)
  }

  // MARK: - Accendere e spegnere

  /// Accende i promemoria. **È qui, e solo qui, che si chiede il permesso** —
  /// mai all'avvio a freddo. Se l'utente lo nega, l'interruttore resta acceso
  /// ma `permesso` racconta la verità, così le impostazioni possono spiegare
  /// dove si rimedia.
  func accendi(giaFattoOggi: Bool, serieGiorni: Int = 0) async {
    acceso = true
    difese.set(true, forKey: Chiave.acceso)

    let centro = UNUserNotificationCenter.current()
    do {
      _ = try await centro.requestAuthorization(options: [.alert, .sound])
    } catch {
      // Un errore qui vuol dire che il Mac non ce l'ha concesso: lo scopriamo
      // rileggendo lo stato qui sotto, non fingendo che sia andata bene.
    }
    await aggiornaPermesso()
    await ripianifica(giaFattoOggi: giaFattoOggi, serieGiorni: serieGiorni)
  }

  /// Spegne i promemoria e cancella gli avvisi già in coda.
  func spegni() {
    acceso = false
    difese.set(false, forKey: Chiave.acceso)
    rimuoviTutti()
  }

  // MARK: - Cambiare orario e giorni

  func impostaOrario(da data: Date) {
    let c = Calendar.current.dateComponents([.hour, .minute], from: data)
    ora = c.hour ?? ora
    minuto = c.minute ?? minuto
    difese.set(ora, forKey: Chiave.ora)
    difese.set(minuto, forKey: Chiave.minuto)
  }

  func impostaGiorni(_ g: Giorni) {
    giorni = g
    difese.set(g.rawValue, forKey: Chiave.giorni)
  }

  // MARK: - Sapere che cosa ci ha concesso il Mac

  /// Rilegge dal sistema lo stato del permesso. Da chiamare all'apertura delle
  /// impostazioni: l'utente può averlo cambiato nel frattempo dalle Impostazioni
  /// di Sistema, e l'app deve dire quello che sa *adesso*.
  func aggiornaPermesso() async {
    let impostazioni = await UNUserNotificationCenter.current().notificationSettings()
    permesso = impostazioni.authorizationStatus
  }

  /// Vero quando il permesso è stato esplicitamente negato: l'interruttore è
  /// acceso ma non arriverà niente finché non si rimedia.
  var permessoNegato: Bool {
    acceso && (permesso == .denied)
  }

  // MARK: - Ripianificare

  /// Rifà la coda degli avvisi. Da chiamare all'avvio dell'app e alla fine di
  /// ogni sessione, passando se l'esercizio di oggi è già stato fatto: quel
  /// giorno viene saltato, così non arriva un invito per qualcosa di già fatto.
  func ripianifica(giaFattoOggi: Bool, serieGiorni: Int = 0) async {
    rimuoviTutti()
    guard acceso else { return }
    await aggiornaPermesso()
    guard permesso == .authorized || permesso == .provisional else {
      return
    }

    let centro = UNUserNotificationCenter.current()
    let cal = Calendar.current
    let adesso = Date()
    var messi = 0

    for scarto in 0...(giorniInAvanti + 6) where messi < giorniInAvanti {
      guard let giorno = cal.date(byAdding: .day, value: scarto, to: adesso) else { continue }
      let weekday = cal.component(.weekday, from: giorno)
      guard giorni.includeGiorno(weekday: weekday) else { continue }

      var comp = cal.dateComponents([.year, .month, .day], from: giorno)
      comp.hour = ora
      comp.minute = minuto
      guard let quando = cal.date(from: comp) else { continue }

      // Un avviso nel passato non serve: se l'ora di oggi è già passata, si parte
      // da domani. E se oggi l'esercizio è già stato fatto, oggi si salta.
      if quando <= adesso { continue }
      if cal.isDateInToday(quando), giaFattoOggi { continue }

      let contenuto = UNMutableNotificationContent()
      contenuto.title = "MirrorScopio"
      contenuto.body = messaggio(perGiorno: messi, serieGiorni: serieGiorni)
      contenuto.sound = .default

      let scatto = UNCalendarNotificationTrigger(
        dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: quando),
        repeats: false)
      let richiesta = UNNotificationRequest(
        identifier: "\(prefissoID)\(idData(quando))",
        content: contenuto,
        trigger: scatto)
      try? await centro.add(richiesta)
      messi += 1
    }
  }

  private func rimuoviTutti() {
    // In tutta l'app solo i promemoria mettono avvisi in coda: svuotarla tutta
    // è sicuro e non lascia in giro il promemoria di ieri.
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
  }

  private func idData(_ data: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: data)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  // MARK: - Le parole del promemoria

  /// Il testo dell'invito. Mai un rimprovero: qualcosa di leggero, che si può
  /// ignorare senza sentirsi in debito. La serie di giorni, se c'è, si nomina
  /// con affetto — «ti fa compagnia», mai «stai per perderla».
  private func messaggio(perGiorno indice: Int, serieGiorni: Int) -> String {
    if serieGiorni >= 2, indice == 0 {
      return "Un piccolo giro di parole? La tua serie di \(serieGiorni) giorni ti fa compagnia."
    }
    let inviti = [
      "Una parola al volo? Bastano due minuti.",
      "Quando hai voglia, c'è un giro di parole che ti aspetta.",
      "Va bene anche solo un minuto insieme.",
      "Ci facciamo qualche parola oggi?",
    ]
    return inviti[indice % inviti.count]
  }
}
