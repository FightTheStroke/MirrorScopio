import AVFoundation

/// Quali voci italiane esistono su macOS, e quali di queste mancano qui.
///
/// macOS non permette a nessuna app di scaricare una voce: l'ho verificato,
/// non e una scorciatoia che non ho preso. AVSpeechSynthesisVoice sa
/// elencare quello che c'e gia e basta — non esiste nessuna chiamata per
/// installare il resto, ne in AVFoundation ne altrove, e Apple lo tiene cosi
/// apposta (una voce sono centinaia di megabyte e la scelta resta di chi
/// possiede il Mac).
///
/// Quello che l'app puo fare, e che prima non faceva, e non lasciare la
/// persona davanti a un elenco muto: dire quali voci italiane esistono, quali
/// mancano su questo Mac, portarla esattamente alla pagina giusta e
/// accorgersi da sola quando la voce e arrivata.
enum ItalianVoices {

  struct Nota {
    let nome: String
    let descrizione: String
  }

  /// Le voci italiane che macOS 26 offre. I nomi sono quelli che compaiono in
  /// Impostazioni di Sistema, altrimenti l'elenco qui e l'elenco li non si
  /// somigliano e la ricerca diventa una caccia.
  static let catalogo: [Nota] = [
    .init(nome: "Alice", descrizione: "La voce italiana di serie. Chiara, un po' meccanica."),
    .init(nome: "Alice (migliorata)", descrizione: "La stessa voce, molto più naturale. È quella che consiglio: si capisce meglio e stanca meno."),
    .init(nome: "Alice (premium)", descrizione: "La versione più naturale di tutte. Occupa più spazio."),
    .init(nome: "Federica", descrizione: "Voce femminile, tono più caldo."),
    .init(nome: "Emma", descrizione: "Voce femminile, ritmo più disteso."),
    .init(nome: "Paola", descrizione: "Voce femminile, dizione molto marcata."),
    .init(nome: "Luca", descrizione: "Voce maschile."),
    .init(nome: "Eloquence", descrizione: "Voce sintetica classica: brutta da ascoltare, ma regge velocità altissime. Serve a chi legge con lo screen reader."),
  ]

  /// Le voci italiane davvero installate adesso.
  static func installate() -> [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("it") }
      .sorted { $0.quality.rawValue > $1.quality.rawValue }
  }

  /// Quelle del catalogo che su questo Mac non ci sono. Il confronto e sul
  /// nome perche gli identificativi cambiano fra versioni di macOS.
  static func mancanti() -> [Nota] {
    let presenti = installate().map { $0.name.lowercased() }
    return catalogo.filter { nota in
      let n = nota.nome.lowercased()
      // "Alice (migliorata)" in elenco e "Alice" con qualita enhanced qui.
      if let base = n.split(separator: " ").first.map(String.init),
         n.contains("(") {
        let qualita: AVSpeechSynthesisVoiceQuality = n.contains("premium") ? .premium : .enhanced
        return !installate().contains { $0.name.lowercased().hasPrefix(base) && $0.quality == qualita }
      }
      return !presenti.contains { $0.hasPrefix(n) }
    }
  }

  /// Vero quando c'e almeno una voce piu naturale di quella di serie: sotto
  /// questa soglia vale la pena suggerire di aggiungerne una.
  static var haUnaVoceBuona: Bool {
    installate().contains { $0.quality != .default }
  }
}
