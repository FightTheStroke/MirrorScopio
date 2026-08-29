import SwiftUI

/// **La vela** — il Fight Camp 2022, quello "da pirati": otto ragazzi a bordo
/// del brigantino Nave Italia, da Civitavecchia a La Spezia.
///
/// A bordo si issano le vele, e si issano con due mani sulla stessa cima,
/// tirando tutti insieme *a tempo con l'onda*: quando la barca sale, la cima
/// si allenta e si guadagna un pezzo; fuori tempo si tira e basta.
///
/// Qui la stessa cosa: una barra va avanti e indietro, e in mezzo c'è la zona
/// dell'onda buona. Premi dentro quella zona e la vela sale di un pezzo. Sei
/// pezzi e la vela è issata: la nave fa una tappa. Quattro tappe e si arriva.
///
/// **La nave non torna mai indietro.** Un colpo dato fuori tempo non fa
/// scendere la vela: compare «ANCORA» e la barra ripassa.
struct GiocoVela: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var cursore: Double = 20
  @State private var verso: Double = 1
  @State private var zona: Double = 130
  @State private var pezzi = 0
  @State private var tappa = 0
  @State private var punti = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let pezziPerVela = 6
  private static let tappe = ["CIVITAVECCHIA", "GIGLIO", "ELBA", "PORTOFINO", "LA SPEZIA"]
  private static let yBarra: Double = 168
  private static let orizzonte: Double = 86

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 2100)
      _pezzi = State(initialValue: 4)
      _tappa = State(initialValue: 2)
      _zona = State(initialValue: 130)
      _cursore = State(initialValue: 150)
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  /// Quanto è larga la zona buona. Con la difficoltà bassa è larghissima: a
  /// bordo nessuno ti chiede di essere preciso al centesimo, ti chiedono di
  /// tirare insieme agli altri.
  private var larghezzaZona: Double { max(30, d.tolleranza * 3 + 22) }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LA VELA",
      sottotitolo: fase == .titolo ? "ISSA A TEMPO CON L'ONDA"
        : "\(Self.tappe[min(tappa, Self.tappe.count - 1)]) · VELA \(pezzi) DI \(Self.pezziPerVela) · \(d.nome)",
      punti: punti, statoDestra: "TAPPE \(tappa)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Nave Italia, da Civitavecchia a La Spezia, come al camp del 2022. La vela si issa a tempo con l'onda: il cursore corre sulla barra, e la parte chiara in mezzo è l'onda che ti aiuta. Premi lì dentro e la vela sale di un pezzo."
    case .gioco: "Premi quando il cursore è dentro la parte chiara."
    case .vela: "Vela issata. La nave fa la sua tappa."
    case .fine: "La Spezia. Ci siete arrivati, tirando insieme."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: IL CURSORE VA SULL'ONDA" : "PREMI SPAZIO PER TIRARE"
    case .vela: "PREMI SPAZIO PER SALPARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La vela. Premi quando il cursore entra nell'onda. Premi per giocare."
    case .gioco:
      return (dentroLOnda() ? "Il cursore è dentro l'onda: tira adesso. " : "Il cursore è fuori: aspetta. ")
        + "Vela a \(pezzi) pezzi su \(Self.pezziPerVela). Tappa: \(Self.tappe[min(tappa, Self.tappe.count - 1)])."
    case .vela: return "Vela issata. Premi per salpare."
    case .fine: return "Arrivati a La Spezia. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.mare(p, orizzonte: Self.orizzonte, battiti: battiti, fermo: fermo)

    // La rotta, in cima: i porti in fila, quelli già passati pieni. È una
    // riga sola e sta lontana dal resto, così non si confonde con il mare.
    p.rettangolo(10, 2, 300, 22, C64.bluScuro)
    for (i, _) in Self.tappe.enumerated() {
      let x = 22 + Double(i) * 62
      p.rettangolo(x, 8, 12, 10, i <= tappa ? C64.verdeChiaro : C64.grigio)
      if i < Self.tappe.count - 1 {
        p.rettangolo(x + 14, 12, 46, 2, i < tappa ? C64.verdeChiaro : C64.grigio)
      }
    }

    disegnaNave(p)
    disegnaBarra(p)

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  /// Il brigantino, grande, in mezzo allo schermo. La vela cresce verso l'alto
  /// a ogni tirata: il progresso è una forma che sale, non un numero da
  /// leggere.
  private func disegnaNave(_ p: Pennello) {
    let x: Double = 108
    let ponte: Double = 132
    // Lo scafo, a trapezio.
    p.rettangolo(x, ponte, 108, 10, C64.marrone)
    p.rettangolo(x + 8, ponte + 10, 92, 8, C64.marrone)
    p.rettangolo(x + 22, ponte + 18, 64, 6, C64.marrone)
    p.rettangolo(x, ponte, 108, 3, C64.arancio)
    // Gli oblò: si vede che è una nave e non una cassa.
    for i in 0..<4 {
      p.rettangolo(x + 18 + Double(i) * 20, ponte + 3, 6, 5, C64.giallo)
    }
    // L'albero e il pennone.
    p.rettangolo(x + 46, 34, 6, ponte - 34, C64.grigioChiaro)
    p.rettangolo(x + 16, 34, 66, 4, C64.grigioChiaro)
    // La vela: parte dal pennone e scende quanto sono i pezzi issati.
    let quanta = Double(pezzi) / Double(Self.pezziPerVela) * 88
    if quanta > 0 {
      p.rettangolo(x + 18, 38, 62, quanta, C64.bianco)
      p.rettangolo(x + 18, 38 + quanta - 3, 62, 3, C64.grigioChiaro)
    }
    // Chi tira la cima, in coperta.
    p.appoggia(Personaggi.tifo, x: x + 84, suolo: ponte, colori: Personaggi.eroe)
    p.appoggia(Personaggi.fermo, x: x + 6, suolo: ponte, colori: Personaggi.compagno(0))
  }

  /// La barra dell'onda, in basso: il cursore, la finestra buona fra due
  /// paletti, e le tacche dei pezzi già issati.
  private func disegnaBarra(_ p: Pennello) {
    p.rettangolo(14, Self.yBarra, 292, 20, C64.bluScuro)
    p.rettangolo(14, Self.yBarra, 292, 2, C64.grigio)
    p.rettangolo(zona, Self.yBarra + 2, larghezzaZona, 16, C64.ciano)
    p.rettangolo(zona, Self.yBarra - 6, 3, 30, C64.bianco)
    p.rettangolo(zona + larghezzaZona - 3, Self.yBarra - 6, 3, 30, C64.bianco)
    p.rettangolo(cursore, Self.yBarra - 10, 6, 38, C64.giallo)
    p.rettangolo(10, Self.yBarra - 28, 104, 16, C64.bluScuro)
    for i in 0..<Self.pezziPerVela {
      p.rettangolo(14 + Double(i) * 16, Self.yBarra - 24, 12, 8,
                   i < pezzi ? C64.bianco : C64.grigio)
    }
  }

  // MARK: - Le regole

  private func dentroLOnda() -> Bool {
    cursore + 3 >= zona && cursore + 3 <= zona + larghezzaZona
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; pezzi = 0; tappa = 0; preparaOnda(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento il cursore non corre: si mette da sé dentro l'onda e
        // tira. Il gioco resta lo stesso, il tempo lo decidi tu.
        cursore = zona + larghezzaZona / 2 - 3
        tira()
      } else if dentroLOnda() {
        tira()
      } else {
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
      }
    case .vela:
      if tappa >= Self.tappe.count - 1 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        pezzi = 0; preparaOnda(); fase = .gioco
      }
    case .fine:
      tappa = 0; pezzi = 0; punti = 0; fase = .titolo
    }
  }

  private func tira() {
    pezzi += 1
    punti += 130
    mostra(.punti(130))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    preparaOnda()
    if pezzi >= Self.pezziPerVela {
      tappa += 1
      punti += 1000
      fase = .vela
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }
    cursore += verso * 1.6 * d.velocita
    if cursore < 16 { cursore = 16; verso = 1 }
    if cursore > 300 { cursore = 300; verso = -1 }
  }

  /// L'onda si sposta a ogni tirata: mai due volte nello stesso punto, ma mai
  /// così ai bordi da diventare una trappola.
  private func preparaOnda() {
    guard !fermo else { zona = 130; return }
    zona = Sorte.fra(30.0, 290.0 - larghezzaZona)
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, vela, fine }
}
