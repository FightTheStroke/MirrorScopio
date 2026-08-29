import SwiftUI

/// **Le bolle** — lo sciame che scende dall'alto, come negli sparatutto a
/// schermo fisso del Commodore, ma senza sparare a nessuno.
///
/// Dall'alto scendono bolle di sapone. In basso una retina scorre da sola
/// avanti e indietro: premendo, salta in su e ne prende una. Non c'è mira da
/// fare — la retina si muove da sé — c'è solo da scegliere l'istante, e la
/// bolla che tocca terra non si perde: rimbalza e risale.
struct GiocoBolle: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var bolle: [Bolla] = []
  @State private var xRete: Double = 20
  @State private var verso: Double = 1
  @State private var soffio: Double?
  @State private var punti = 0
  @State private var sciami = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let yRete: Double = 172

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1750)
      _sciami = State(initialValue: 1)
      _xRete = State(initialValue: 130)
      _soffio = State(initialValue: 0.55)
      _bolle = State(initialValue: Self.sciameFisso())
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LE BOLLE",
      sottotitolo: fase == .titolo ? "PRENDILE CON LA RETINA"
        : "SCIAME \(sciami + 1) · RESTANO \(bolle.count) · \(d.nome)",
      punti: punti, statoDestra: "SCIAMI \(sciami)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "La retina va avanti e indietro da sola: non devi guidarla. Premi quando si trova sotto una bolla e salta a prenderla. Le bolle che arrivano in fondo rimbalzano e risalgono: non se ne perde nessuna."
    case .gioco: "Aspetta che la retina sia sotto una bolla, poi premi."
    case .sciameFatto: "Sciame preso tutto. Ne arriva un altro, messo in un modo diverso."
    case .fine: "Le hai prese tutte. Una alla volta, con il tuo tempo."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: LA RETINA VA E PRENDE" : "PREMI SPAZIO PER PRENDERE"
    case .sciameFatto: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "Le bolle. La retina scorre da sola, tu scegli quando saltare. Premi per giocare."
    case .gioco:
      return (bersaglio() != nil ? "La retina è sotto una bolla: premi adesso. " : "La retina è nel vuoto: aspetta. ")
        + "Restano \(bolle.count) bolle."
    case .sciameFatto: return "Sciame completato. Premi per continuare."
    case .fine: return "Le hai prese tutte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    Sfondi.cielo(p)
    p.rettangolo(0, Self.yRete + 16, SchermoRetro.larghezza, 8, C64.verde)
    p.rettangolo(0, Self.yRete + 16, SchermoRetro.larghezza, 2, C64.verdeChiaro)

    for b in bolle {
      p.sprite(OggettiBolle.bolla, x: b.x, y: b.y,
               colori: ["O": OggettiBolle.tinte[b.colore], "L": C64.bianco])
    }

    // Il soffio: la scia che sale dalla retina. È largo e visibile apposta —
    // serve a capire *dopo* perché la bolla è stata presa o no.
    if let s = soffio {
      let cima = Self.yRete - s * 150
      var y = Self.yRete
      while y > cima {
        p.rettangolo(xRete + 10, y - 6, 4, 5, C64.bianco.opacity(0.8))
        y -= 10
      }
      p.rettangolo(xRete + 6, cima, 12, 4, C64.ciano)
    }

    p.sprite(OggettiBolle.retina, x: xRete - 4, y: Self.yRete,
             colori: ["R": C64.giallo, "M": C64.marrone, "B": C64.bianco])

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  /// La bolla che la retina ha davvero sopra di sé adesso. La tolleranza si
  /// allarga quando le cose vanno storte: il gioco si adatta a chi gioca, non
  /// il contrario.
  private func bersaglio() -> Int? {
    let centro = xRete + 12
    return bolle.indices
      .filter { abs(bolle[$0].x + 8 - centro) < d.tolleranza + 8 }
      .max { bolle[$0].y < bolle[$1].y }
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; sciami = 0; preparaSciame(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento la retina non insegue niente: si mette da sé sotto la
        // bolla più bassa e la prende. Resta un gioco, smette di essere una
        // coincidenza da azzeccare.
        guard let i = bolle.indices.max(by: { bolle[$0].y < bolle[$1].y }) else { return }
        xRete = bolle[i].x - 4
        prendi(i)
      } else if soffio == nil {
        soffio = 0
      }
    case .sciameFatto:
      if sciami >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaSciame(); fase = .gioco
      }
    case .fine:
      sciami = 0; punti = 0; preparaSciame(); fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }

    xRete += verso * 1.5 * d.velocita
    if xRete < 4 { xRete = 4; verso = 1 }
    if xRete > SchermoRetro.larghezza - 28 { xRete = SchermoRetro.larghezza - 28; verso = -1 }

    for i in bolle.indices {
      bolle[i].y += bolle[i].verso * 0.28 * d.velocita
      bolle[i].oscilla += 0.06
      // Nessuna bolla si perde: toccato il prato risale, e sopra il soffitto
      // ridiscende. Il campo è chiuso, e chiuso vuol dire sicuro.
      if bolle[i].y > Self.yRete - 8 { bolle[i].verso = -1 }
      if bolle[i].y < 22 { bolle[i].verso = 1 }
    }

    if let s = soffio {
      let avanti = s + 1.0 / 10.0
      if avanti >= 1 {
        soffio = nil
      } else {
        soffio = avanti
        // Il soffio prende la prima bolla che incontra salendo.
        let cima = Self.yRete - avanti * 150
        if let i = bolle.indices.first(where: {
          abs(bolle[$0].x + 8 - (xRete + 12)) < d.tolleranza + 8
            && bolle[$0].y + 16 >= cima && bolle[$0].y <= cima + 20
        }) {
          soffio = nil
          prendi(i)
        } else if avanti > 0.94 {
          mostra(.ancora)
          d.andataMale()
          suoni.suona(.ancora, a11y: a11y.perIlMotore)
        }
      }
    }
  }

  private func prendi(_ i: Int) {
    let valore = 100 + (bolle[i].colore == 2 ? 150 : 0)
    bolle.remove(at: i)
    punti += valore
    mostra(.punti(valore))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    if bolle.isEmpty {
      sciami += 1
      punti += 1000
      fase = .sciameFatto
    }
  }

  private func preparaSciame() {
    soffio = nil; lampo = nil; lampoFino = 0
    xRete = 20; verso = 1
    // Lo sciame nasce diverso ogni volta: quante bolle, su quante file, quanto
    // spostate. Mai più di dieci, però: uno schermo pieno di roba da guardare
    // è uno schermo che non si guarda.
    guard !fermo else { bolle = Self.sciameFisso(); return }
    let quante: Int = min(10, 5 + Sorte.fra(0, Int(d.densita * 4)))
    let perFila: Int = Sorte.fra(3, 5)
    let passo: Double = 270 / Double(perFila)
    var nuove: [Bolla] = []
    for i in 0..<quante {
      let x: Double = 20 + Double(i % perFila) * passo + Sorte.fra(-6.0, 6.0)
      let y: Double = 40 + Double(i / perFila) * 34 + Sorte.fra(-4.0, 4.0)
      nuove.append(Bolla(x: x, y: y, colore: Sorte.fra(0, 2), oscilla: Sorte.fra(0.0, 6.0)))
    }
    bolle = nuove
  }

  /// Lo sciame del modo senza movimento e quello della fotografia: due file
  /// ordinate, sempre le stesse.
  private static func sciameFisso() -> [Bolla] {
    var fuori: [Bolla] = []
    for i in 0..<8 {
      let x: Double = 30 + Double(i % 4) * 68
      let y: Double = 44 + Double(i / 4) * 38
      fuori.append(Bolla(x: x, y: y, colore: i % 3, oscilla: 0))
    }
    return fuori
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, sciameFatto, fine }

  private struct Bolla {
    var x: Double
    var y: Double
    var colore: Int
    var oscilla: Double
    var verso: Double = 1
  }
}

enum OggettiBolle {
  /// Le bolle hanno tre tinte, e la terza vale di più — ma il valore sta anche
  /// scritto nel numero che compare quando la prendi, mai solo nel colore.
  static let tinte = [C64.ciano, C64.verdeChiaro, C64.giallo]

  static let bolla = SpritePixel(righe: [
    "..OOOO..",
    ".OOOOOO.",
    "OOLLOOOO",
    "OOLOOOOO",
    "OOOOOOOO",
    "OOOOOOOO",
    ".OOOOOO.",
    "..OOOO..",
  ])

  /// La retina: il cerchio in alto è la parte che prende — largo più di una
  /// bolla, così si vede subito che ci sta dentro — e il manico sta sotto.
  static let retina = SpritePixel(righe: [
    "..RRRRRRRR..",
    ".RRRRRRRRRR.",
    "RRB.B.B.B.RR",
    "RR.B.B.B.BRR",
    "RRB.B.B.B.RR",
    ".RR.B.B.BRR.",
    "..RRRRRRRR..",
    "....RMMR....",
    ".....MM.....",
    ".....MM.....",
  ])
}
