import Foundation

/// Come si trasformano le prove di una sessione nel referto che qualcuno
/// leggerà.
///
/// Sta fuori dal motore della sessione, e non è un riordino di scaffali. Qui
/// dentro ci sono le due regole cliniche più delicate di tutta l'app — che
/// cosa entra nel conto e che cosa no — e finché stavano dentro un oggetto di
/// mille righe, legate a un microfono acceso e a un orologio che gira, non
/// c'era modo di provarle se non facendo una sessione vera a mano.
///
/// Adesso sono funzioni pure: si dà un elenco di prove, si guarda che cosa
/// esce. Le prove che stanno in `Verifiche/ContiDelReferto.swift` non
/// esistevano perché non si potevano scrivere.
enum RegistroSessione {

  /// Il referto di una sessione finita.
  ///
  /// Due esclusioni dal conteggio, e nessuna delle due è un dettaglio:
  ///
  /// - **Il riscaldamento non conta.** Sono parole facili mostrate molto più a
  ///   lungo, fatte apposta per prendere la mano. Contarle gonfiava la
  ///   percentuale di fine sessione e spingeva in su il livello suggerito. Un
  ///   numero che si abbellisce da solo è peggio di un numero severo: toglie
  ///   senso anche ai miglioramenti veri.
  /// - **Le prove interrotte non contano.** Una prova interrotta è una in cui
  ///   il Mac si è addormentato o il microfono è sparito: metterla nel totale
  ///   senza poterla mettere fra le giuste farebbe scendere la percentuale per
  ///   una cosa che il ragazzo non ha fatto. Il referto racconterebbe un
  ///   peggioramento che non è mai avvenuto.
  ///
  /// Le prove restano **tutte** nell'elenco dettagliato: escluse dal conto,
  /// non nascoste. Chi guarda il dettaglio deve poter vedere che quella parola
  /// c'è stata e com'è andata a finire.
  static func referto(prove: [Trial],
                      config: SessionConfig,
                      sogliaMs: Double?) -> SessionRecord {
    var r = SessionRecord()
    r.mode = config.mode
    r.level = config.level
    r.setLabel = config.set.label

    let contate = prove.filter { $0.id > config.warmupTrials && !$0.interrotto }
    r.total = contate.count
    r.correct = contate.filter(\.correct).count
    r.thresholdMs = sogliaMs

    let latenze = prove.filter { !$0.interrotto }.compactMap(\.vocalLatencyMs)
    r.meanLatencyMs = latenze.isEmpty ? nil : latenze.reduce(0, +) / Double(latenze.count)

    r.items = prove.map {
      ItemRecord(stimulus: $0.stimulus, response: $0.response, correct: $0.correct,
                 exposureMs: $0.actualExposureMs > 0 ? $0.actualExposureMs : $0.requestedExposureMs,
                 latencyMs: $0.vocalLatencyMs, errorKind: $0.errorKind.label,
                 warmup: $0.id <= config.warmupTrials,
                 interrotto: $0.interrotto,
                 refreshHz: $0.refreshHz,
                 frameSaltato: $0.frameSaltato,
                 motivoInterruzione: $0.motivoInterruzione)
    }
    return r
  }

  /// Velocità di partenza suggerita dal test iniziale.
  ///
  /// Si prende la soglia misurata e si concede un margine del 25%: allenarsi
  /// al limite scoraggia, quindi si parte appena sopra, dove si sbaglia poco
  /// ma non zero.
  static func partenzaSuggerita(prove: [Trial],
                                sogliaMs: Double?) -> (exposureMs: Double, level: Level)? {
    guard !prove.isEmpty else { return nil }
    let misurata = sogliaMs ?? prove.filter(\.correct).map(\.requestedExposureMs).min()
    guard let misurata else { return nil }
    let suggerita = min(1000, max(80, misurata * 1.25))
    let livello: Level = switch suggerita {
    case ..<180: .avanzato
    case ..<380: .intermedio
    case ..<700: .base
    default: .inizio
    }
    return (suggerita, livello)
  }
}
