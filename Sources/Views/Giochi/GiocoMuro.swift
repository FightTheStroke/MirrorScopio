import SwiftUI

/// **Il muro** — i mattoni da buttare giù con la pallina, il gioco che sul
/// Commodore stava in ogni cassetta.
///
/// Con una differenza che cambia tutto: sotto non c'è il vuoto, c'è un
/// **trampolino**. La pallina non si perde mai, quindi non ci sono vite da
/// perdere. La racchetta scorre da sola e il tasto serve solo a farle cambiare
/// direzione: niente mira, niente inseguimento.
struct GiocoMuro: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var mattoni: [Mattone] = []
  @State private var xRacchetta: Double = 130
  @State private var versoRacchetta: Double = 1
  @State private var palla = CGPoint(x: 150, y: 120)
  @State private var moto = CGPoint(x: 1.4, y: -1.4)
  @State private var punti = 0
  @State private var muri = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let yRacchetta: Double = 168
  private static let larghezzaRacchetta: Double = 52

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 2400)
      _muri = State(initialValue: 1)
      _palla = State(initialValue: CGPoint(x: 148, y: 118))
      _xRacchetta = State(initialValue: 122)
      _mattoni = State(initialValue: Self.muroFisso())
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "IL MURO",
      sottotitolo: fase == .titolo ? "SOTTO C'E' UN TRAMPOLINO"
        : "MURO \(muri + 1) · RESTANO \(mattoni.count) · \(d.nome)",
      punti: punti, statoDestra: "MURI \(muri)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "La racchetta va avanti e indietro da sola: premendo cambia direzione, tutto qui. Sotto la racchetta c'è un trampolino, quindi la pallina non si perde mai e non ci sono vite da perdere."
    case .gioco: "Cambia direzione quando serve. La pallina torna sempre."
    case .muroFatto: "Muro giù. Il prossimo è disegnato in un altro modo."
    case .fine: "Non è rimasto in piedi un mattone. E la pallina non si è persa nemmeno una volta."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: UN TIRO, UN MATTONE" : "PREMI SPAZIO PER CAMBIARE VERSO"
    case .muroFatto: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "Il muro. La racchetta scorre da sola, premi per farle cambiare verso. Premi per giocare."
    case .gioco:
      let dove = palla.x < xRacchetta ? "a sinistra" : (palla.x > xRacchetta + Self.larghezzaRacchetta ? "a destra" : "sopra")
      return "Restano \(mattoni.count) mattoni. La pallina è \(dove) della racchetta."
    case .muroFatto: return "Muro completato. Premi per continuare."
    case .fine: return "Hai buttato giù tutti i muri. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.nero)

    for m in mattoni {
      p.rettangolo(m.x, m.y, Mattone.larghezza, Mattone.altezza, m.tinta)
      p.rettangolo(m.x, m.y, Mattone.larghezza, 2, C64.bianco.opacity(0.55))
      p.rettangolo(m.x, m.y, 2, Mattone.altezza, C64.bianco.opacity(0.3))
    }

    // Il trampolino: si vede che è un trampolino, con le molle. È la promessa
    // «non puoi perdere» resa visibile, non solo scritta nella frase sotto.
    let yTrampolino = SchermoRetro.altezza - 16
    p.rettangolo(0, yTrampolino, SchermoRetro.larghezza, 6, C64.verdeChiaro)
    // Le molle: tre traversine sfalsate per ognuna, come una molla vista di
    // lato. Servono a far capire a colpo d'occhio che sotto si rimbalza.
    for x in stride(from: 6.0, to: SchermoRetro.larghezza - 6, by: 20) {
      p.rettangolo(x, yTrampolino + 6, 10, 2, C64.verde)
      p.rettangolo(x + 4, yTrampolino + 9, 10, 2, C64.verde)
      p.rettangolo(x, yTrampolino + 12, 10, 2, C64.verde)
    }

    p.rettangolo(xRacchetta, Self.yRacchetta, Self.larghezzaRacchetta, 8, C64.giallo)
    p.rettangolo(xRacchetta, Self.yRacchetta, Self.larghezzaRacchetta, 3, C64.bianco)
    // La freccia dice da che parte sta andando: il verso è l'unica cosa che si
    // comanda, quindi dev'essere scritto sullo schermo, non da indovinare.
    // La freccia: una punta vera, non un trattino. Il verso è l'unica cosa
    // che si comanda, quindi dev'essere scritto sullo schermo.
    let avanti = versoRacchetta > 0
    let sinistra = avanti ? xRacchetta + Self.larghezzaRacchetta - 12 : xRacchetta + 4
    // Un triangolo vero: la riga di mezzo è la più lunga, e la punta cade da
    // quella parte. Prima era una scaletta, e sembrava un pezzo mancante.
    for (r, largo) in [(0.0, 4.0), (1.0, 8.0), (2.0, 4.0)] {
      let x = avanti ? sinistra : sinistra + (8 - largo)
      p.rettangolo(x, Self.yRacchetta + 1 + r * 2, largo, 2, C64.nero)
    }

    p.sprite(OggettiMuro.palla, x: palla.x - 6, y: palla.y - 6,
             colori: ["P": C64.bianco, "L": C64.ciano])

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; muri = 0; preparaMuro(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento: ogni pressione è un tiro che va a segno sul mattone
        // più basso. La pallina ci va e torna, e il muro cala di uno.
        guard let i = mattoni.indices.max(by: { mattoni[$0].y < mattoni[$1].y }) else { return }
        palla = CGPoint(x: mattoni[i].x + Mattone.larghezza / 2, y: mattoni[i].y + Mattone.altezza)
        xRacchetta = min(SchermoRetro.larghezza - Self.larghezzaRacchetta,
                         max(0, palla.x - Self.larghezzaRacchetta / 2))
        rompi(i)
      } else {
        versoRacchetta *= -1
      }
    case .muroFatto:
      if muri >= 2 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaMuro(); fase = .gioco
      }
    case .fine:
      muri = 0; punti = 0; preparaMuro(); fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }

    xRacchetta += versoRacchetta * 1.9 * d.velocita
    if xRacchetta < 0 { xRacchetta = 0; versoRacchetta = 1 }
    if xRacchetta > SchermoRetro.larghezza - Self.larghezzaRacchetta {
      xRacchetta = SchermoRetro.larghezza - Self.larghezzaRacchetta
      versoRacchetta = -1
    }

    var x = palla.x + moto.x * d.velocita
    var y = palla.y + moto.y * d.velocita

    if x < 6 { x = 6; moto.x = abs(moto.x) }
    if x > SchermoRetro.larghezza - 6 { x = SchermoRetro.larghezza - 6; moto.x = -abs(moto.x) }
    if y < 8 { y = 8; moto.y = abs(moto.y) }

    if moto.y > 0, y >= Self.yRacchetta - 4, y <= Self.yRacchetta + 8,
       x >= xRacchetta - 4, x <= xRacchetta + Self.larghezzaRacchetta + 4 {
      y = Self.yRacchetta - 4
      moto.y = -abs(moto.y)
      // Dove colpisce la racchetta decide l'angolo: è l'unico modo di
      // «mirare» che questo gioco concede, e si impara guardandolo.
      let quota = (x - xRacchetta) / Self.larghezzaRacchetta - 0.5
      moto.x = max(-2.2, min(2.2, quota * 3.4))
      punti += 20
      d.andataBene()
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
    }

    // Il trampolino. La pallina torna su comunque: quello che cambia è che se
    // la racchetta non c'era compare «ANCORA», e il gioco rallenta un po'.
    if y > SchermoRetro.altezza - 20 {
      y = SchermoRetro.altezza - 20
      moto.y = -abs(moto.y)
      mostra(.ancora)
      d.andataMale()
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
    }

    palla = CGPoint(x: x, y: y)

    if let i = mattoni.firstIndex(where: {
      x >= $0.x - 4 && x <= $0.x + Mattone.larghezza + 4
        && y >= $0.y - 4 && y <= $0.y + Mattone.altezza + 4
    }) {
      moto.y *= -1
      rompi(i)
    }
  }

  private func rompi(_ i: Int) {
    punti += mattoni[i].valore
    mostra(.punti(mattoni[i].valore))
    mattoni.remove(at: i)
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    if mattoni.isEmpty {
      muri += 1
      punti += 1000
      fase = .muroFatto
    }
  }

  private func preparaMuro() {
    lampo = nil; lampoFino = 0
    palla = CGPoint(x: 150, y: 120)
    moto = CGPoint(x: Sorte.moneta() ? 1.4 : -1.4, y: -1.4)
    xRacchetta = 130
    versoRacchetta = Sorte.moneta() ? 1 : -1
    mattoni = fermo ? Self.muroFisso() : Self.muroACaso(passo: d.passo)
  }

  /// Il muro nasce da un disegno estratto a sorte fra pochi, non da mattoni
  /// buttati a caso: una forma riconoscibile si guarda volentieri, un mucchio
  /// disordinato no. E in ogni disegno resta sempre un varco per la pallina.
  private static func muroACaso(passo: Int) -> [Mattone] {
    let file = 3 + min(2, passo / 3)
    let colonne = 8
    let disegno = Sorte.fra(0, 3)
    var fuori: [Mattone] = []
    for r in 0..<file {
      for c in 0..<colonne {
        let salta: Bool
        switch disegno {
        case 0: salta = false                                  // il muro pieno
        case 1: salta = (r + c) % 3 == 0                        // le diagonali
        case 2: salta = c == 0 || c == colonne - 1              // le due torri
        default: salta = r % 2 == 1 && c % 2 == 1               // la scacchiera
        }
        if salta { continue }
        fuori.append(Mattone(riga: r, colonna: c))
      }
    }
    return fuori
  }

  private static func muroFisso() -> [Mattone] {
    (0..<4).flatMap { r in (0..<8).map { c in Mattone(riga: r, colonna: c) } }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 20
  }

  private enum Fase: Equatable { case titolo, gioco, muroFatto, fine }

  /// Un mattone. Le file più in alto valgono di più, come nell'originale.
  struct Mattone {
    static let larghezza: Double = 36
    static let altezza: Double = 12

    let riga: Int
    let colonna: Int

    var x: Double { 8 + Double(colonna) * (Mattone.larghezza + 2) }
    var y: Double { 34 + Double(riga) * (Mattone.altezza + 4) }
    var valore: Int { 150 - riga * 25 }
    var tinta: Color {
      [C64.rosso, C64.arancio, C64.giallo, C64.verdeChiaro, C64.ciano][riga % 5]
    }
  }
}

enum OggettiMuro {
  static let palla = SpritePixel(righe: [
    ".LLPP.",
    "LLPPPP",
    "LPPPPP",
    "PPPPPP",
    "PPPPPP",
    ".PPPP.",
  ])
}
