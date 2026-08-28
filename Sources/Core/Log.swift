import OSLog

/// Il posto dove finiscono i guasti che non fermano la sessione.
///
/// Ce ne sono pochi ed è giusto così: quasi ogni errore in questa app viene
/// detto alla persona, in parole sue, sullo schermo — un guasto taciuto è la
/// cosa che ha fatto sembrare rotta l'app più volte. Restano i casi in cui
/// interrompere sarebbe peggio del guasto: lì il messaggio deve comunque
/// esistere da qualche parte, altrimenti un giorno l'app smette di funzionare
/// e nessuno sa perché.
///
/// **Non ci finisce mai nulla di ciò che il ragazzo legge, dice o scrive.** Il
/// registro di sistema è leggibile da altri programmi sul Mac: la promessa che
/// i dati non escono da qui vale anche verso il Mac stesso.
enum Log {
  private static let logger = Logger(subsystem: "org.fightthestroke.mirrorscopio",
                                     category: "app")

  static func warn(_ messaggio: String) {
    logger.warning("\(messaggio, privacy: .public)")
  }

  /// Come `warn`, ma tiene fuori dalla parte leggibile ciò che riguarda questo
  /// Mac e questa persona: percorsi di cartelle, nomi di file, messaggi del
  /// sistema. Il registro di sistema lo possono leggere altri programmi, e un
  /// percorso contiene il nome dell'utente.
  ///
  /// La parte `motivo` resta visibile solo a chi ha il Mac davanti e attiva la
  /// diagnostica di proposito.
  static func warn(_ messaggio: String, motivo: String) {
    logger.warning("\(messaggio, privacy: .public): \(motivo, privacy: .private)")
  }
}
