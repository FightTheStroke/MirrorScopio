import SwiftUI

/// **Il triciclo** — il Fight Camp 2023, con i tecnici Ormesa. È stata «in
/// assoluto la lezione più gradita del camp»: al primo giorno pedalavano
/// tutti, e si vedevano mani plegiche che si aprivano da sole per prendere il
/// manubrio.
///
/// Pedalare non è premere al momento giusto: è **dare spinta e non perderla**.
/// Qui ogni pressione è una pedalata, e ogni pedalata aggiunge spinta. La
/// spinta cala da sola, e in salita cala più in fretta: pedali più spesso dove
/// la strada sale, come succede davvero.
///
/// **Non si cade e non si torna indietro.** Se la spinta finisce ci si ferma,
/// e basta ripedalare. Il traguardo si raggiunge sempre — ci si mette solo il
/// tempo che ci vuole, e qui il tempo non è un problema di nessuno.
struct GiocoTriciclo: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var distanza: Double = 0
  @State private var spinta: Double = 0
  @State private var quote: [Double] = []
  @State private var bandierine: [Double] = []
  @State private var prese: Set<Int> = []
  @State private var giri = 0
  @State private var punti = 0
  @State private var pedalata = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let traguardo: Double = 900
  private static let xTriciclo: Double = 56
  private static let suoloBase: Double = 158
  private static let passoQuota: Double = 60

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1600)
      _giri = State(initialValue: 1)
      _distanza = State(initialValue: 300)
      _spinta = State(initialValue: 2.4)
      _quote = State(initialValue: Self.stradaFissa())
      _bandierine = State(initialValue: [360, 470, 560, 700, 840])
      _prese = State(initialValue: [0])
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "IL TRICICLO",
      sottotitolo: fase == .titolo ? "PEDALA E TIENI LA SPINTA"
        : "GIRO \(giri + 1) · \(Int(distanza)) DI \(Int(Self.traguardo)) METRI · \(d.nome)",
      punti: punti, statoDestra: "GIRI \(giri)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Il triciclo del camp. Ogni volta che premi è una pedalata, e ogni pedalata dà spinta. La spinta cala da sola, e in salita cala prima: lì bisogna pedalare più spesso. Le bandierine si prendono passandoci sopra."
    case .gioco: "Pedala. Se ti fermi non è niente: riparti."
    case .arrivo: "Traguardo. Un altro giro, con la strada fatta in un altro modo."
    case .fine: "Tre giri interi. Le gambe hanno lavorato tutte e due."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: UNA PEDALATA" : "PREMI SPAZIO PER PEDALARE"
    case .arrivo: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "Il triciclo. Premi per pedalare, ogni pedalata dà spinta. Premi per giocare."
    case .gioco:
      let dove = pendenza() > 0.12 ? "in salita" : (pendenza() < -0.12 ? "in discesa" : "in piano")
      let come = spinta < 0.6 ? "sei quasi fermo" : (spinta > 2.4 ? "vai forte" : "vai piano")
      return "Sei \(dove) e \(come). \(Int(distanza)) metri di \(Int(Self.traguardo)). Premi per pedalare."
    case .arrivo: return "Traguardo raggiunto. Premi per continuare."
    case .fine: return "Tre giri fatti. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    // Solo il cielo: la strada la disegna il profilo qui sotto, che sale e
    // scende. Quella dritta dello sfondo spuntava fuori dalle colline.
    SfondiSport.cieloAperto(p, orizzonte: SchermoRetro.altezza)

    // Il profilo della strada: la salita e la discesa si vedono, non si
    // leggono. Ogni colonna dello schermo ha la sua altezza.
    var x: Double = 0
    while x < SchermoRetro.larghezza {
      let y = suolo(a: distanza + x - Self.xTriciclo)
      p.rettangolo(x, y, 4, SchermoRetro.altezza - y, C64.grigio)
      p.rettangolo(x, y + 26, 4, SchermoRetro.altezza - y - 26, C64.marrone)
      p.rettangolo(x, y, 4, 4, C64.verde)
      p.rettangolo(x, y + 4, 4, 2, C64.verdeChiaro)
      x += 4
    }
    // La riga di mezzeria segue la strada e scorre: è quella che fa vedere che
    // si avanza. Disegnata sopra il profilo, non sotto, o sparisce.
    var riga = -40 + (-distanza).truncatingRemainder(dividingBy: 40)
    while riga < SchermoRetro.larghezza {
      let y = suolo(a: distanza + riga - Self.xTriciclo)
      p.rettangolo(riga, y + 14, 22, 3, C64.grigioChiaro)
      riga += 40
    }

    // Le bandierine ancora da prendere.
    for (i, b) in bandierine.enumerated() where !prese.contains(i) {
      let sx = b - distanza + Self.xTriciclo
      guard sx > -12, sx < SchermoRetro.larghezza else { continue }
      p.appoggia(OggettiSport.bandierina, x: sx, suolo: suolo(a: b),
                 colori: ["B": C64.giallo, "A": C64.bianco])
    }

    // Il traguardo, a scacchi.
    let sx = Self.traguardo - distanza + Self.xTriciclo
    if sx > -20, sx < SchermoRetro.larghezza {
      for riga in 0..<10 {
        for colonna in 0..<2 where (riga + colonna) % 2 == 0 {
          p.rettangolo(sx + Double(colonna) * 8, suolo(a: Self.traguardo) - 80 + Double(riga) * 8,
                       8, 8, C64.bianco)
        }
      }
      p.rettangolo(sx, suolo(a: Self.traguardo) - 84, 16, 4, C64.rosso)
    }

    // Il triciclo, appoggiato alla strada, che ondeggia col colpo di pedale.
    let salto: Double = pedalata > 0 ? -2 : 0
    p.appoggia(OggettiSport.triciclo, x: Self.xTriciclo,
               suolo: suolo(a: distanza) + salto,
               colori: ["C": C64.giallo, "F": C64.arancio, "O": C64.nero,
                        "M": C64.rosso, "T": C64.verdeChiaro, "R": C64.grigioChiaro])

    barraSpinta(p)

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  /// La spinta che resta, come una barra piena. È l'unica cosa che va guardata
  /// mentre si pedala, quindi sta grande e in basso.
  private func barraSpinta(_ p: Pennello) {
    p.rettangolo(12, SchermoRetro.altezza - 20, 180, 12, C64.bluScuro)
    let quanta = min(1.0, spinta / 3.5) * 176
    p.rettangolo(14, SchermoRetro.altezza - 18, quanta, 8, C64.verdeChiaro)
    // Le tacche: la barra si legge anche senza distinguere il colore.
    for i in 1..<4 {
      p.rettangolo(12 + Double(i) * 44, SchermoRetro.altezza - 20, 2, 12, C64.nero)
    }
  }

  // MARK: - Le regole

  /// L'altezza del terreno a un certo punto della strada, interpolata fra le
  /// quote campionate.
  private func suolo(a metri: Double) -> Double {
    guard !quote.isEmpty else { return Self.suoloBase }
    let posizione = max(0, metri) / Self.passoQuota
    let i = min(quote.count - 1, Int(posizione))
    let j = min(quote.count - 1, i + 1)
    let f = posizione - Double(i)
    return Self.suoloBase - (quote[i] + (quote[j] - quote[i]) * f)
  }

  /// Quanto sale la strada qui: positivo in salita.
  private func pendenza() -> Double {
    (suolo(a: distanza) - suolo(a: distanza + 20)) / 20
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; giri = 0; preparaStrada(); fase = .gioco
    case .gioco:
      pedalata = 8
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
      if fermo {
        // Senza movimento non c'è niente che scorre da solo: una pedalata è un
        // passo avanti, e la strada si fa un pezzo alla volta.
        avanza(di: 34)
      } else {
        spinta = min(3.6, spinta + 1.0 + 0.2 * d.velocita)
      }
    case .arrivo:
      if giri >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaStrada(); fase = .gioco
      }
    case .fine:
      giri = 0; punti = 0; fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if pedalata > 0 { pedalata -= 1 }
    guard !fermo, fase == .gioco else { return }
    // La spinta cala sempre un po', e in salita cala di più. È tutta la regola
    // del gioco, e sta in due righe.
    spinta = max(0, spinta - 0.035 - max(0, pendenza()) * 0.30)
    avanza(di: spinta)
  }

  private func avanza(di quanto: Double) {
    guard quanto > 0 else { return }
    distanza += quanto
    for (i, b) in bandierine.enumerated()
    where !prese.contains(i) && distanza >= b {
      prese.insert(i)
      punti += 100
      mostra(.punti(100))
      d.andataBene()
    }
    if distanza >= Self.traguardo {
      giri += 1
      punti += 1000
      fase = .arrivo
    }
  }

  /// Una strada nuova a ogni giro: salite e discese messe a caso, ma mai più
  /// ripide di quanto una pedalata riesca a vincere.
  private func preparaStrada() {
    distanza = 0
    spinta = 0
    prese = []
    lampo = nil
    lampoFino = 0
    guard !fermo else {
      quote = Self.stradaFissa()
      bandierine = [180, 340, 500, 660, 820]
      return
    }
    let quante = Int(Self.traguardo / Self.passoQuota) + 8
    var nuove: [Double] = [0]
    for _ in 1..<quante {
      let ultima = nuove[nuove.count - 1]
      let salto = Sorte.fra(-9.0, 9.0 + d.densita * 2)
      nuove.append(min(46, max(0, ultima + salto)))
    }
    quote = nuove
    bandierine = (0..<6).map { i in
      120 + Double(i) * 130 + Sorte.fra(-30.0, 30.0)
    }
  }

  /// La strada del modo senza movimento e delle fotografie: una salita, un
  /// piano, una discesa. Sempre uguale, così si può guardare con calma.
  private static func stradaFissa() -> [Double] {
    (0..<24).map { i in
      let n = Double(i)
      if n < 6 { return n * 5 }
      if n < 12 { return 30 }
      if n < 18 { return 30 - (n - 12) * 4 }
      return 6
    }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, arrivo, fine }
}
