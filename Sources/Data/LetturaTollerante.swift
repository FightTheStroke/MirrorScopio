import Foundation

/// Perché questo file esiste.
///
/// Swift sa costruire da solo il codice che legge un JSON, ma con una regola
/// che qui fa danni: **un campo assente è un errore**, anche quando la
/// proprietà ha già un valore predefinito scritto accanto. Finché i campi non
/// cambiano non si nota. Il giorno in cui si aggiunge un'impostazione nuova —
/// una sola, un `Bool` — tutto ciò che era stato salvato prima diventa
/// illeggibile in blocco: non quel campo, *tutto il file*.
///
/// È successo davvero, il 28 agosto: l'aggiunta del consenso al lampeggio
/// veloce ha reso illeggibile l'elenco delle persone su un Mac che aveva mesi
/// di lavoro dentro. La protezione contro la perdita dei dati ha retto — copia
/// messa da parte, niente sovrascritto, avviso a schermo — ma l'app era
/// inutilizzabile, e nessuna prova automatica se n'era accorta, perché tutte
/// scrivevano e rileggevano con la *stessa* versione del codice.
///
/// Da qui in avanti la lettura è tollerante: **un campo che manca prende il suo
/// valore predefinito**, e chi aggiorna ritrova i suoi dati. Un campo che c'è
/// ma è scritto male continua a essere un errore, e deve restarlo: quello non è
/// un formato vecchio, è un file rovinato, e fingere di saperlo leggere
/// vorrebbe dire inventare numeri dentro un referto clinico.
extension KeyedDecodingContainer {
  /// Legge un campo; se non c'è, restituisce il valore predefinito.
  func valore<T: Decodable>(_ chiave: Key, _ predefinito: T) throws -> T {
    try decodeIfPresent(T.self, forKey: chiave) ?? predefinito
  }
}
