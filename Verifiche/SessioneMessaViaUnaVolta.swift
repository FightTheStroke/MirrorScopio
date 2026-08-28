import Testing
import Foundation
@testable import MirrorScopio

/// Mettere via una sessione due volte non deve raddoppiare niente.
///
/// Il conto dei punti, la serie dei giorni e il numero di sessioni fatte
/// vivevano dietro un interruttore che stava dentro la schermata del
/// riepilogo. Uno stato di una schermata SwiftUI riparte da capo ogni volta
/// che SwiftUI decide di ricostruirla — e lo decide lui, non noi. Bastava
/// quello perché a un ragazzo venissero assegnati i punti di una sessione due
/// volte, e un giorno in più nella sua serie.
///
/// Non è un difetto che si vede: si vede solo un numero più alto, che è
/// esattamente quello che uno si aspetta di vedere dopo aver finito.
@Suite("Una sessione si mette via una volta sola")
@MainActor
struct SessioneMessaViaUnaVolta {

  private func cartellaDiProva() -> URL {
    let u = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("mirrorscopio-prova-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }

  private func sessione(giuste: Int = 8, totale: Int = 10) -> SessionRecord {
    var r = SessionRecord()
    r.correct = giuste
    r.total = totale
    return r
  }

  @Test("Mettere via la stessa sessione dieci volte dà i punti una volta sola")
  func puntiUnaVoltaSola() {
    let store = Store(folder: cartellaDiProva())
    let s = sessione()

    store.archivia(s)
    let puntiDopoLaPrima = store.current.xp
    let sessioniDopoLaPrima = store.current.sessionsCompleted

    for _ in 0..<9 { store.archivia(s) }

    #expect(store.current.xp == puntiDopoLaPrima,
            "I punti sono passati da \(puntiDopoLaPrima) a \(store.current.xp): la sessione è stata contata più volte.")
    #expect(store.current.sessionsCompleted == sessioniDopoLaPrima)
    #expect(store.currentHistory.count == 1, "Nel diario dev'esserci una sessione, non dieci.")
  }

  @Test("La serie di giorni non si allunga rimettendo via la stessa sessione")
  func serieNonSiAllunga() {
    let store = Store(folder: cartellaDiProva())
    let s = sessione()
    store.archivia(s)
    let serie = store.current.streakCurrent
    store.archivia(s)
    store.archivia(s)
    #expect(store.current.streakCurrent == serie)
  }

  @Test("Gli obiettivi si sbloccano solo la prima volta")
  func obiettiviUnaVoltaSola() {
    let store = Store(folder: cartellaDiProva())
    let s = sessione()
    let primi = store.archivia(s)
    let secondi = store.archivia(s)
    #expect(!primi.isEmpty, "La prima sessione di sempre sblocca almeno «Si comincia».")
    #expect(secondi.isEmpty, "La seconda volta non c'è niente da sbloccare di nuovo.")
  }

  @Test("Due sessioni diverse si mettono via tutte e due")
  func sessioniDiverseNonSiConfondono() {
    let store = Store(folder: cartellaDiProva())
    store.archivia(sessione())
    store.archivia(sessione(giuste: 5, totale: 10))
    #expect(store.currentHistory.count == 2,
            "Il controllo è sull'identificativo della sessione, non sul suo contenuto.")
  }

  @Test("La sessione messa via porta con sé la persona a cui appartiene")
  func sessioneLegataAllaPersona() {
    let store = Store(folder: cartellaDiProva())
    store.archivia(sessione())
    #expect(store.currentHistory.first?.learnerID == store.currentID,
            "Una sessione senza persona non comparirebbe nel diario di nessuno.")
  }
}
