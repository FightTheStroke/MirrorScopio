import Testing
import Foundation
@testable import MirrorScopio

/// Nessuna larghezza sfugge alla scala del testo.
///
/// È il seguito diretto della prova sulle griglie, e nasce dallo stesso
/// difetto guardato in un punto diverso dell'app. Il 29 agosto 2026, con
/// «Dimensione di tutto» a ×2, la seconda schermata della prima accensione
/// mostrava un pulsante con scritto **«Indiet ro»**: la parola spezzata a metà,
/// dentro un riquadro che non era cresciuto insieme al suo testo.
///
/// La causa è identica a quella delle griglie: cinquanta `.frame(maxWidth: N)`
/// sparsi per le viste, con il numero scritto a mano e mai moltiplicato da
/// `a11y.size()`. Il testo raddoppiava, il contenitore restava fermo, e quello
/// che non ci stava andava a capo o spariva. Nella stessa schermata la colonna
/// di lettura era bloccata a 820 punti su una finestra da 1352: metà pagina
/// vuota, e il titolo su tre righe.
///
/// E come per le griglie, **colpisce solo chi ha alzato il testo** — cioè chi
/// vede poco, cioè esattamente la persona per cui quella manopola esiste. Chi
/// legge bene non lo vedrebbe mai, e infatti per mesi nessuno l'ha visto.
///
/// Questa prova non misura una vista: **legge il codice**. È l'unico modo di
/// impedire che il difetto rientri dalla porta di servizio la prossima volta
/// che qualcuno scrive un numero comodo dentro un `frame`. Una prova che
/// guarda il risultato di una schermata sola avrebbe lasciato scoperte le
/// altre tredici.
@Suite("Nessuna larghezza sfugge alla scala del testo")
struct LarghezzeCheCrescono {

  /// I sorgenti veri, cercati a partire da questo file.
  ///
  /// `#filePath` è l'unico appiglio che funziona sia lanciando le prove da
  /// riga di comando sia da Xcode, dove la cartella di lavoro è altrove.
  static func sorgenti() -> [URL] {
    var radice = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()   // Verifiche/
      .deletingLastPathComponent()   // radice del progetto
    radice.appendPathComponent("Sources")
    let f = FileManager.default
    guard let elenco = f.enumerator(at: radice, includingPropertiesForKeys: nil) else { return [] }
    return elenco.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
  }

  /// Le larghezze scritte a mano che non passano dalla scala.
  ///
  /// Si guardano solo `maxWidth` e `minWidth`, cioè quelle che contengono
  /// testo. Un `width: 3` è una linea di separazione e con il testo non
  /// c'entra: farla raddoppiare sarebbe un difetto al contrario.
  static func larghezzeFisse(in testo: String) -> [String] {
    let regola = try! NSRegularExpression(pattern: #"(maxWidth|minWidth):\s*(\d+)(?![\d.])"#)
    let r = NSRange(testo.startIndex..., in: testo)
    return regola.matches(in: testo, range: r).compactMap { m in
      guard let s = Range(m.range, in: testo) else { return nil }
      return String(testo[s])
    }
  }

  @Test("Nelle viste non resta nessuna larghezza che ignora la scala")
  func nessunaLarghezzaFissa() throws {
    var colpevoli: [String] = []
    for file in Self.sorgenti() {
      // La dimensione minima della finestra è l'unica eccezione, ed è
      // dichiarata: non contiene testo, e una finestra che raddoppia perché
      // è raddoppiato il carattere diventerebbe più grande dello schermo.
      if file.lastPathComponent == "App.swift" { continue }
      // Letto dal disco passando dal percorso, non da un indirizzo. Il modo
      // più diretto di leggere un file in Swift accetta anche un indirizzo di
      // rete, e il guardiano che difende la promessa «niente esce da questo
      // Mac» non può distinguere i due casi da fuori. Ha ragione lui: qui il
      // percorso basta.
      guard let dati = FileManager.default.contents(atPath: file.path) else {
        Issue.record("Non riesco a leggere \(file.lastPathComponent)")
        continue
      }
      let testo = String(decoding: dati, as: UTF8.self)
      for trovata in Self.larghezzeFisse(in: testo) {
        colpevoli.append("\(file.lastPathComponent): \(trovata)")
      }
    }
    #expect(colpevoli.isEmpty, """
      Queste larghezze non crescono con il testo. A ×2 il contenitore resta \
      fermo mentre le parole raddoppiano: la scritta va a capo dentro il \
      pulsante, o sparisce. Passa il numero da a11y.size(), come fanno tutti \
      gli altri. Trovate: \(colpevoli.joined(separator: ", "))
      """)
  }

  @Test("La regola riconosce davvero il caso che ha prodotto il difetto")
  func laRegolaFunziona() {
    // Senza questa, la prova sopra potrebbe passare per il motivo sbagliato —
    // cioè perché non trova niente, non perché non c'è niente.
    #expect(Self.larghezzeFisse(in: ".frame(maxWidth: 220)").count == 1)
    #expect(Self.larghezzeFisse(in: ".frame(maxWidth: a11y.size(220))").isEmpty,
      "quella corretta non deve essere segnalata")
    #expect(Self.larghezzeFisse(in: ".frame(width: 3)").isEmpty,
      "una linea di separazione non contiene testo e non deve raddoppiare")
    #expect(Self.larghezzeFisse(in: ".frame(minWidth: 320, maxHeight: 460)").count == 1)
  }

  @Test("I sorgenti si trovano davvero")
  func iSorgentiSiTrovano() {
    // Se un giorno la cartella cambia nome, la prova sopra passerebbe su un
    // elenco vuoto senza dire niente: sarebbe un cancello aperto che sembra
    // chiuso.
    #expect(Self.sorgenti().count > 20,
      "l'elenco dei sorgenti è sospettosamente corto: la prova sta guardando nel posto sbagliato")
  }
}
