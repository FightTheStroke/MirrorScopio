import Foundation

enum Scoring {
  /// Riduce trascrizione e stimolo a una forma confrontabile: niente maiuscole,
  /// niente punteggiatura, niente diacritici, spazi normalizzati.
  static func normalize(_ s: String) -> String {
    let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
    let stripped = folded.unicodeScalars.filter {
      CharacterSet.alphanumerics.contains($0) || $0 == " "
    }
    return String(String.UnicodeScalarView(stripped))
      .split(separator: " ")
      .joined(separator: " ")
  }

  /// Vero quando la trascrizione ancora provvisoria dice già lo stimolo, e
  /// quindi non ha più senso aspettare il silenzio di fine risposta.
  ///
  /// Il confronto è volutamente più severo di `classify`: qui non si perdona
  /// nulla di dubbio, perché una chiusura anticipata sbagliata taglierebbe la
  /// voce a metà a chi si stava correggendo. L'unica indulgenza è quella sulla
  /// segmentazione — «far falla» per *farfalla* è come il riconoscitore divide
  /// le parole, non come una persona legge.
  static func combaciaGia(stimolo: String, testo: String) -> Bool {
    let atteso = normalize(stimolo)
    let detto = normalize(testo)
    guard !atteso.isEmpty, !detto.isEmpty else { return false }
    if atteso == detto { return true }
    return atteso.replacingOccurrences(of: " ", with: "")
      == detto.replacingOccurrences(of: " ", with: "")
  }

  static func editDistance(_ a: [Character], _ b: [Character]) -> Int {    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var prev = Array(0...b.count)
    var cur = [Int](repeating: 0, count: b.count + 1)
    for i in 1...a.count {
      cur[0] = i
      for j in 1...b.count {
        let cost = a[i - 1] == b[j - 1] ? 0 : 1
        cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
      }
      swap(&prev, &cur)
    }
    return prev[b.count]
  }

  /// Classificazione dell'errore secondo le categorie usate in clinica.
  static func classify(target: String, response: String) -> (correct: Bool, kind: ErrorKind, distance: Int) {
    let t = normalize(target)
    let r = normalize(response)

    if r.isEmpty { return (false, .omissioneTotale, t.count) }
    if t == r { return (true, .none, 0) }

    let tc = Array(t.replacingOccurrences(of: " ", with: ""))
    let rc = Array(r.replacingOccurrences(of: " ", with: ""))

    // Il riconoscitore segmenta le parole a modo suo: "far falla" per "farfalla"
    // è un artefatto di trascrizione, non un errore di lettura.
    if tc == rc { return (true, .none, 0) }

    let d = editDistance(tc, rc)

    if tc.sorted() == rc.sorted() { return (false, .inversione, d) }
    if tc.count == rc.count { return (false, .sostituzione, d) }
    if rc.count < tc.count { return (false, .omissione, d) }
    if rc.count > tc.count { return (false, .aggiunta, d) }
    return (false, .altroErrore, d)
  }

  /// Allinea le parole, invece di confrontarle per posizione: una parola
  /// mancante non deve far segnalare anche tutte quelle che vengono dopo.
  static func revisioneParole(target: String, response: String) -> [ParolaScritta] {
    let attese = normalize(target).split(separator: " ").map(String.init)
    let scritte = response.split(separator: " ").map(String.init)
      .filter { !normalize($0).isEmpty }
    let confronto = scritte.map(normalize)
    var distanze = Array(repeating: Array(repeating: 0, count: scritte.count + 1),
                         count: attese.count + 1)
    for i in 0...attese.count { distanze[i][0] = i }
    for j in 0...scritte.count { distanze[0][j] = j }
    for i in attese.indices {
      for j in scritte.indices {
        distanze[i + 1][j + 1] = min(
          distanze[i][j] + (attese[i] == confronto[j] ? 0 : 1),
          distanze[i][j + 1] + 1,
          distanze[i + 1][j] + 1)
      }
    }

    var risultato: [ParolaScritta] = []
    var i = attese.count, j = scritte.count
    while i > 0 || j > 0 {
      if i > 0, j > 0,
         distanze[i][j] == distanze[i - 1][j - 1] + (attese[i - 1] == confronto[j - 1] ? 0 : 1) {
        risultato.append(ParolaScritta(
          testo: scritte[j - 1], indiceRisposta: j - 1,
          esito: attese[i - 1] == confronto[j - 1] ? .confermata : .daRivedere))
        i -= 1
        j -= 1
      } else if i > 0, distanze[i][j] == distanze[i - 1][j] + 1 {
        risultato.append(ParolaScritta(testo: "", indiceRisposta: nil, esito: .mancante))
        i -= 1
      } else {
        risultato.append(ParolaScritta(testo: scritte[j - 1], indiceRisposta: j - 1, esito: .inPiu))
        j -= 1
      }
    }
    return risultato.reversed()
  }
}

struct ParolaScritta: Equatable {
  enum Esito: Equatable {
    case confermata, daRivedere, inPiu, mancante
  }

  let testo: String
  let indiceRisposta: Int?
  let esito: Esito

  var indicazione: String {
    switch esito {
    case .confermata: "Va bene: \(testo)"
    case .daRivedere: "Ancora: \(testo)"
    case .inPiu: "In più: \(testo)"
    case .mancante: "Manca una parola"
    }
  }
}

/// Riscontro della consegna, non del testo mentre viene modificato.
/// Non si salva nei risultati: quelli conservano la prima risposta.
struct RevisioneScrittura: Equatable {
  static let riproveMassime = 3
  let consegne: Int
  let risposta: String
  let parole: [ParolaScritta]

  var esaurite: Bool { consegne >= 1 + Self.riproveMassime }

  var invito: String {
    esaurite
      ? "Hai fatto le tre riprove. Guarda il modello: quando vuoi, puoi continuare."
      : "Ancora. Modifica il testo e premi Fatto: riprova \(consegne) di \(Self.riproveMassime)."
  }
}

extension String {
  /// Spazi e a capo tolti da entrambi i lati. Sta qui perché serve nel
  /// riconoscimento, dove la stessa riga si ripeteva in cinque punti.
  func trimmed() -> String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
