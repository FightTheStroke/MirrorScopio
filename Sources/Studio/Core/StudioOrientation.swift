import Foundation

enum StudioOrientation {
  static let trialTitle = "Una prova già pronta"
  static let trialExplanation = "Premi Inizia: ti accompagno in una prova con un breve testo e due domande."
  static let parentExplanation = "Il genitore prepara le lezioni di scuola in «Per il genitore». Tu premi Inizia o Continua."

  static func showsInstructions(in archive: StudioArchive) -> Bool {
    archive.sessions.filter { $0.outcome == .completed }.count < 3
  }

  static func label(for recall: StudioRecall) -> String {
    switch recall {
    case .remembered: "Ricordato: senza aiuti"
    case .helped: "Con aiuto: ho usato un aiuto"
    case .again: "Ancora: da riprendere"
    }
  }
}

enum StudioInstruction: String {
  case reading, recall, comparison, parent

  var title: String {
    switch self {
    case .reading: "1. Leggi o ascolta"
    case .recall: "2. Prova a ricordare"
    case .comparison: "3. Confronta, senza voti"
    case .parent: "Come preparo il percorso?"
    }
  }

  var explanation: String {
    switch self {
    case .reading:
      "Leggi il testo oppure premi Ascolta.\nNon devi rispondere adesso. Il testo resta qui: puoi rileggerlo."
    case .recall:
      "Prova a rispondere a voce: l'app non ti ascolta.\nSe non ricordi, apri Un aiuto.\nPoi premi Vedi la risposta."
    case .comparison:
      "Qui sotto trovi una risposta di riferimento.\nNon servono le stesse parole. Scegli come hai risposto, senza voti."
    case .parent:
      "1. Scegli Prepara con Apple Intelligence e scrivi un argomento, oppure aggiungi un testo dal libro.\n2. Controlla il materiale e conferma il salvataggio: solo allora entra nel percorso.\n3. Metti le lezioni nell'ordine desiderato. Poi torna a Casa: chi studia deve solo premere Inizia."
    }
  }
}
