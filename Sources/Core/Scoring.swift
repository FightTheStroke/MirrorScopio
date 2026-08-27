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
}

extension String {
  /// Spazi e a capo tolti da entrambi i lati. Sta qui perché serve nel
  /// riconoscimento, dove la stessa riga si ripeteva in cinque punti.
  func trimmed() -> String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
