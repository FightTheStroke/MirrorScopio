import Foundation

/// Le regole deterministiche della Corsa, separate dal disegno e dai suoni.
enum RegoleCorsa {
  static let puntiOstacolo = 100
  static let puntiGemma = 250
  static let puntiTappa = 1_000
  static let numeroTappe = 4

  enum EsitoOstacolo: Equatable {
    case superato
    case ancora

    var punti: Int {
      switch self {
      case .superato: RegoleCorsa.puntiOstacolo
      case .ancora: 0
      }
    }
  }

  enum PassaggioTappa: Equatable {
    case prossima(Int)
    case fine
  }

  static func altezzaSalto(progresso: Double?, altezzaMassima: Double) -> Double {
    guard let progresso else { return 0 }
    return sin(progresso * .pi) * altezzaMassima
  }

  /// La finestra è larga apposta: chi preme presto è ancora in aria
  /// quando arriva l'ostacolo, senza trasformare il gioco in una prova di riflessi.
  static func inAria(progressoSalto: Double?) -> Bool {
    guard let progressoSalto else { return false }
    return progressoSalto > 0.10 && progressoSalto < 0.90
  }

  static func esitoOstacolo(progressoSalto: Double?) -> EsitoOstacolo {
    inAria(progressoSalto: progressoSalto) ? .superato : .ancora
  }

  static func posizioneDopoPasso(da posizione: Double, traguardo: Double) -> Double {
    min(traguardo, posizione + 27)
  }

  static func posizioniOstacoliCalmi(dopo posizione: Double,
                                     traguardo: Double) -> [Double] {
    Array(stride(from: posizione + 50, to: traguardo - 30, by: 54))
  }

  static func deveGenerareOstacolo(prossimo: Int, posizione: Double,
                                   traguardo: Double) -> Bool {
    prossimo <= 0 && posizione < traguardo - 80
  }

  static func puoRaccogliereGemma(distanza: Double, fermo: Bool,
                                  altezzaSalto: Double) -> Bool {
    abs(distanza) < 16 && (fermo || altezzaSalto > 10)
  }

  static func squadraDopoTappa(_ squadra: Int) -> Int {
    min(numeroTappe, max(0, squadra) + 1)
  }

  static func passaggioDopoTappa(livello: Int) -> PassaggioTappa {
    let prossimo = livello + 1
    return prossimo >= numeroTappe ? .fine : .prossima(prossimo)
  }
}
