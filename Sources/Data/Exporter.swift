import Foundation
import AppKit

/// Referto in PDF per il clinico e CSV per chi vuole i numeri grezzi.
/// Nessuna libreria esterna: Core Graphics e basta.
enum Exporter {

  // MARK: - CSV

  static func csv(_ s: SessionRecord, learner: Learner) -> String {
    var rows = ["parola;risposta;esito;esposizione_ms;latenza_ms;tipo_errore;riscaldamento"]
    for i in s.items {
      rows.append([
        i.stimulus, i.response,
        i.correct ? "giusta" : "ancora",
        String(Int(i.exposureMs)),
        i.latencyMs.map { String(Int($0)) } ?? "",
        i.errorKind,
        i.warmup ? "si" : "no",
      ].map(escape).joined(separator: ";"))
    }
    return header(s, learner: learner) + "\n" + rows.joined(separator: "\n") + "\n"
  }

  private static func header(_ s: SessionRecord, learner: Learner) -> String {
    """
    # MirrorScopio
    # nome;\(escape(learner.name.isEmpty ? "senza nome" : learner.name))
    # data;\(dateText(s.date))
    # modalita;\(s.mode == .lettura ? "Leggi ad alta voce" : "Scrivi")
    # livello;\(s.level.title)
    # lista;\(escape(s.setLabel))
    # parole_giuste;\(s.correct)
    # parole_totali;\(s.total)
    # accuratezza_percento;\(Int(s.accuracy * 100))
    # soglia_ms;\(s.thresholdMs.map { String(Int($0)) } ?? "")
    # latenza_media_ms;\(s.meanLatencyMs.map { String(Int($0)) } ?? "")
    """
  }

  /// Mette un campo dentro il file rispettando la regola dei CSV (RFC 4180) e
  /// disinnescando le formule.
  ///
  /// Prima qui si sostituiva il punto e virgola con una virgola: il file
  /// restava leggibile, ma **il dato cambiava**. La parola che il bambino ha
  /// letto davvero non è un dettaglio da correggere di nascosto in un referto
  /// clinico. Ora il campo si racchiude fra virgolette e le virgolette interne
  /// si raddoppiano, come vuole lo standard: il testo arriva identico.
  ///
  /// L'apostrofo davanti a `= + - @ tab` non è pignoleria: Excel e Numbers
  /// eseguono come formula un campo che comincia così, e in una lista di parole
  /// scritte da un ragazzo ci finisce di tutto.
  ///
  /// L'apostrofo però **entra nel dato** per chi legge il file con un
  /// programma invece che con un foglio di calcolo. Quindi si mette solo dove
  /// serve davvero: un numero negativo — `-120` fra le latenze — non è una
  /// formula, ed era l'unico modo in cui questa protezione poteva a sua volta
  /// falsificare un numero.
  private static func escape(_ s: String) -> String {
    var campo = s
    if let primo = campo.first, "=+-@\t\r".contains(primo), Double(s) == nil {
      campo = "'" + campo
    }
    return "\"" + campo.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  // MARK: - PDF

  static func pdf(_ s: SessionRecord, learner: Learner) -> Data {
    pdf(sessions: [s], learner: learner, title: "Referto di sessione")
  }

  static func pdf(sessions: [SessionRecord], learner: Learner,
                  title: String = "Storico delle sessioni") -> Data {
    let page = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 a 72 dpi
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data),
          let ctx = CGContext(consumer: consumer, mediaBox: [page], nil) else { return Data() }

    var mediaBox = page
    var y: CGFloat = 0
    var open = false

    /// Apre una pagina nuova quando lo spazio finisce.
    func newPage() {
      if open { ctx.endPDFPage() }
      ctx.beginPDFPage([kCGPDFContextMediaBox as String: NSData(
        bytes: &mediaBox, length: MemoryLayout<CGRect>.size)] as CFDictionary)
      open = true
      y = page.height - 56
    }

    func space(_ needed: CGFloat) {
      if y - needed < 56 { newPage() }
    }

    func line(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
              color: NSColor = .black, gap: CGFloat = 6) {
      space(size + gap)
      draw(text, in: ctx, at: CGPoint(x: 56, y: y - size),
           width: page.width - 112, size: size, weight: weight, color: color)
      y -= size + gap
    }

    func rule() {
      space(14)
      ctx.setStrokeColor(NSColor(white: 0.8, alpha: 1).cgColor)
      ctx.setLineWidth(0.5)
      ctx.move(to: CGPoint(x: 56, y: y - 7))
      ctx.addLine(to: CGPoint(x: page.width - 56, y: y - 7))
      ctx.strokePath()
      y -= 14
    }

    newPage()

    line("MirrorScopio", size: 11, color: NSColor(white: 0.45, alpha: 1), gap: 2)
    line(title, size: 22, weight: .bold, gap: 4)
    line(learner.name.isEmpty ? "Senza nome" : learner.name,
         size: 13, color: NSColor(white: 0.35, alpha: 1))
    rule()

    for (index, s) in sessions.enumerated() {
      if index > 0 { rule() }

      line(dateText(s.date), size: 14, weight: .semibold)
      line("\(s.mode == .lettura ? "Leggi ad alta voce" : "Scrivi") · livello \(s.level.title) · \(s.setLabel)",
           size: 11, color: NSColor(white: 0.35, alpha: 1))
      y -= 4

      let facts: [(String, String)] = [
        ("Parole prese", "\(s.correct) su \(s.total)"),
        ("Accuratezza", "\(Int(s.accuracy * 100))%"),
        ("Soglia", s.thresholdMs.map { "\(Int($0)) ms" } ?? "—"),
        ("Latenza media", s.meanLatencyMs.map { "\(Int($0)) ms" } ?? "—"),
      ]
      space(34)
      for (i, f) in facts.enumerated() {
        let x = 56 + CGFloat(i) * ((page.width - 112) / CGFloat(facts.count))
        draw(f.0, in: ctx, at: CGPoint(x: x, y: y - 10), width: 130, size: 9,
             weight: .regular, color: NSColor(white: 0.45, alpha: 1))
        draw(f.1, in: ctx, at: CGPoint(x: x, y: y - 28), width: 130, size: 15,
             weight: .semibold, color: .black)
      }
      y -= 40

      if !s.errorCounts.isEmpty {
        let summary = s.errorCounts.sorted { $0.value > $1.value }
          .map { "\($0.key): \($0.value)" }.joined(separator: " · ")
        line("Errori — \(summary)", size: 10, color: NSColor(white: 0.3, alpha: 1))
      }

      // Il dettaglio parola per parola solo quando la sessione è una sola,
      // altrimenti lo storico diventa illeggibile.
      if sessions.count == 1 {
        y -= 6
        line("Parola per parola", size: 11, weight: .semibold)
        let cols: [CGFloat] = [56, 190, 330, 400, 470]
        space(16)
        for (t, x) in zip(["parola", "risposta", "esito", "ms", "latenza"], cols) {
          draw(t, in: ctx, at: CGPoint(x: x, y: y - 9), width: 130, size: 8,
               weight: .regular, color: NSColor(white: 0.5, alpha: 1))
        }
        y -= 16

        for i in s.items {
          space(15)
          let grey = NSColor(white: i.warmup ? 0.55 : 0.1, alpha: 1)
          let values = [
            i.stimulus,
            i.response.isEmpty ? "—" : i.response,
            i.warmup ? "prova" : (i.correct ? "giusta" : "ancora"),
            String(Int(i.exposureMs)),
            i.latencyMs.map { String(Int($0)) } ?? "—",
          ]
          for (v, x) in zip(values, cols) {
            let color = (x == cols[2] && !i.warmup)
              ? (i.correct ? NSColor(red: 0, green: 0.45, blue: 0.25, alpha: 1)
                           : NSColor(red: 0.65, green: 0.1, blue: 0.1, alpha: 1))
              : grey
            draw(v, in: ctx, at: CGPoint(x: x, y: y - 11), width: 130, size: 10,
                 weight: .regular, color: color)
          }
          y -= 15
        }
      }
    }

    y -= 10
    line("Strumento di esercizio e osservazione, non un test diagnostico. Dati elaborati solo su questo Mac.",
         size: 8, color: NSColor(white: 0.55, alpha: 1))

    if open { ctx.endPDFPage() }
    ctx.closePDF()
    return data as Data
  }

  private static func draw(_ text: String, in ctx: CGContext, at p: CGPoint,
                           width: CGFloat, size: CGFloat,
                           weight: NSFont.Weight, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: color,
    ]
    let s = NSAttributedString(string: text, attributes: attrs)
    let framesetter = CTFramesetterCreateWithAttributedString(s)
    let path = CGPath(rect: CGRect(x: p.x, y: p.y, width: width, height: size * 1.4), transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    CTFrameDraw(frame, ctx)
  }

  // MARK: - Salvataggio

  /// Salva e, se non riesce, **lo dice**.
  ///
  /// Prima l'errore veniva ingoiato da un `try?`: il logopedista credeva di
  /// avere il referto e non ce l'aveva. Un salvataggio che fallisce in silenzio
  /// è peggio di un salvataggio che non c'è.
  static func save(data: Data, suggested: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggested
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      let avviso = NSAlert()
      avviso.alertStyle = .warning
      avviso.messageText = "Non sono riuscito a salvare il file"
      avviso.informativeText = """
        \(error.localizedDescription)

        Prova a salvarlo in un'altra cartella, per esempio sulla Scrivania.
        """
      avviso.addButton(withTitle: "Ho capito")
      avviso.runModal()
    }
  }

  static func save(text: String, suggested: String) {
    save(data: Data(text.utf8), suggested: suggested)
  }

  /// Come `save(text:)`, ma per i file di numeri destinati a un foglio di
  /// calcolo: davanti ci mette il contrassegno che dice «questo è UTF-8».
  ///
  /// Senza, Excel su Mac apre il file con la codifica di sistema e «perché»
  /// diventa «perchÃ©». In un referto clinico è lo stesso difetto della
  /// sostituzione dei punti e virgola: il file si apre e mostra una parola
  /// diversa da quella che il bambino ha letto davvero.
  static func salvaFoglioDiCalcolo(text: String, suggested: String) {
    var dati = Data([0xEF, 0xBB, 0xBF])
    dati.append(Data(text.utf8))
    save(data: dati, suggested: suggested)
  }

  static func fileStem(_ s: SessionRecord, learner: Learner) -> String {
    let name = learner.name.isEmpty ? "sessione" : learner.name
      .replacingOccurrences(of: " ", with: "-")
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd-HHmm"
    return "MirrorScopio-\(name)-\(f.string(from: s.date))"
  }

  private static func dateText(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "it_IT")
    f.dateStyle = .long
    f.timeStyle = .short
    return f.string(from: d)
  }
}
