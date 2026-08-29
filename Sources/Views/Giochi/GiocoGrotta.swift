import SwiftUI

/// **La grotta** — i massi che cadono e le gemme da raccogliere, come nei
/// giochi di scavo del Commodore.
///
/// Si cammina da soli verso destra, sempre. Il tasto fa una cosa sola:
/// **fermarsi e ripartire**. Tutto il gioco è scegliere quando stare fermi —
/// che è l'esatto contrario di un gioco di riflessi, ed è il motivo per cui sta
/// bene alla fine di una sessione di lettura.
///
/// Il masso che arriva addosso si sbriciola e basta: niente vite, niente
/// ricominciare. La grotta finisce sempre con l'uscita.
struct GiocoGrotta: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var xEroe: Double = 12
  @State private var cammina = true
  @State private var massi: [Masso] = []
  @State private var gemme: [Gemma] = []
  @State private var punti = 0
  @State private var grotte = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @State private var prossimo = 30
  @StateObject private var suoni = Suoni()

  private static let suolo: Double = 178
  private static let uscita: Double = 288

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 3100)
      _grotte = State(initialValue: 1)
      _xEroe = State(initialValue: 96)
      _massi = State(initialValue: [Masso(x: 132, y: 82), Masso(x: 232, y: 40)])
      _gemme = State(initialValue: [Gemma(x: 168), Gemma(x: 244)])
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LA GROTTA",
      sottotitolo: fase == .titolo ? "FERMATI AL MOMENTO GIUSTO"
        : "GROTTA \(grotte + 1) · \(cammina ? "CAMMINI" : "FERMO") · \(d.nome)",
      punti: punti, statoDestra: "GROTTE \(grotte)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Si cammina da soli verso l'uscita. Il tasto serve a fermarsi, e a ripartire. Dal soffitto cadono dei massi: aspetta che siano caduti, poi riparti. Se uno ti prende si sbriciola e basta, non si torna indietro."
    case .gioco: cammina ? "Stai camminando. Fermati se vedi un masso che sta per cadere." : "Sei fermo. Riparti quando la strada è libera."
    case .grottaFatta: "Uscita trovata. Quella dopo ha i massi in altri punti."
    case .fine: "Sei uscito da tutte le grotte, con le gemme in tasca. Aspettare il momento giusto è una cosa che sai fare."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: UN PASSO" : (cammina ? "PREMI SPAZIO PER FERMARTI" : "PREMI SPAZIO PER RIPARTIRE")
    case .grottaFatta: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La grotta. Cammini da solo, il tasto ti ferma e ti fa ripartire. Premi per giocare."
    case .gioco:
      let pericolo = massi.contains { abs($0.x - xEroe) < 26 }
      return (cammina ? "Stai camminando. " : "Sei fermo. ")
        + (pericolo ? "Un masso sta cadendo proprio davanti a te." : "La strada è libera.")
    case .grottaFatta: return "Uscita trovata. Premi per continuare."
    case .fine: return "Sei uscito da tutte le grotte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    Sfondi.roccia(p)

    // Il soffitto e il pavimento della grotta.
    p.rettangolo(0, 0, SchermoRetro.larghezza, 14, C64.grigio)
    p.rettangolo(0, 12, SchermoRetro.larghezza, 3, C64.grigioChiaro)
    p.rettangolo(0, Self.suolo + 10, SchermoRetro.larghezza, 22, C64.marrone)
    p.rettangolo(0, Self.suolo + 10, SchermoRetro.larghezza, 3, C64.arancio)

    // L'uscita: la luce in fondo, sempre visibile fin dal primo istante. Si sa
    // sempre dove si sta andando e quanto manca.
    let porta = Self.uscita + 6
    let altezza = Self.suolo - 76
    p.rettangolo(porta, 86, 28, altezza + 4, C64.giallo.opacity(0.22))
    // I raggi verticali: la luce di fuori che entra dall'apertura. In
    // orizzontale sembravano i pioli di una scala, e la scala qui non c'è.
    for x in [4.0, 12.0, 20.0] {
      p.rettangolo(porta + x, 88, 3, altezza, C64.giallo.opacity(0.45))
    }
    p.rettangolo(porta, 82, 28, 5, C64.giallo)
    p.rettangolo(porta, 82, 5, altezza + 8, C64.giallo)
    p.rettangolo(porta + 23, 82, 5, altezza + 8, C64.giallo)

    for g in gemme where !g.presa {
      p.sprite(OggettiCorsa.gemma, x: g.x, y: Self.suolo - 6,
               colori: ["G": C64.ciano, "L": C64.bianco])
    }

    for m in massi {
      // L'ombra sotto il masso dice *dove* cadrà prima che cada: la sorpresa
      // sarebbe ingiusta, l'attesa no.
      // La striscia a righe dice *dove* cadrà il masso prima che cada: la
      // sorpresa sarebbe ingiusta, l'attesa no.
      p.rettangolo(m.x, Self.suolo + 4, 16, 4, C64.rosso)
      for t in 0..<3 { p.rettangolo(m.x + 2 + Double(t) * 5, Self.suolo + 4, 2, 4, C64.bianco) }
      p.sprite(OggettiGrotta.masso, x: m.x, y: m.y,
               colori: ["M": C64.grigioChiaro, "B": C64.bianco, "S": C64.grigio])
    }

    let sprite = fase == .fine
      ? Personaggi.tifo
      : (cammina && !fermo && (battiti / 6) % 2 == 0 ? Personaggi.corsa : Personaggi.fermo)
    p.appoggia(sprite, x: xEroe, suolo: Self.suolo + 10, colori: Personaggi.eroe)

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; grotte = 0; preparaGrotta(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento la grotta diventa a passi: ogni pressione è un passo
        // avanti, e i massi non cadono mai sul passo che stai facendo.
        xEroe = min(Self.uscita, xEroe + 24)
        raccogli()
        if xEroe >= Self.uscita { esci() }
      } else {
        cammina.toggle()
      }
    case .grottaFatta:
      if grotte >= 2 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaGrotta(); fase = .gioco
      }
    case .fine:
      grotte = 0; punti = 0; preparaGrotta(); fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }

    if cammina {
      xEroe = min(Self.uscita, xEroe + 1.0 * d.velocita)
      punti += 1
    }

    for i in massi.indices { massi[i].y += 2.2 * d.velocita }

    for m in massi where m.y > Self.suolo - 12 && m.y < Self.suolo + 4 {
      guard abs(m.x - xEroe) < 16 else { continue }
      // Ti ha preso: si sbriciola, si perde un attimo, non si perde altro.
      mostra(.ancora)
      d.andataMale()
      cammina = false
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
    }

    massi.removeAll { $0.y > Self.suolo + 4 }

    // Il prossimo masso cade davanti a te, non addosso: c'è sempre il tempo di
    // vederlo partire e decidere di fermarsi.
    prossimo -= 1
    if prossimo <= 0 && xEroe < Self.uscita - 40 {
      massi.append(Masso(x: min(SchermoRetro.larghezza - 20, xEroe + Sorte.fra(60.0, 130.0)), y: 16))
      prossimo = Int(Double(Sorte.fra(40, 90)) / max(0.5, d.densita))
    }

    raccogli()
    if xEroe >= Self.uscita { esci() }
  }

  private func raccogli() {
    for i in gemme.indices where !gemme[i].presa {
      guard abs(gemme[i].x - xEroe) < 14 else { continue }
      gemme[i].presa = true
      punti += 250
      mostra(.punti(250))
      d.andataBene()
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
    }
  }

  private func esci() {
    grotte += 1
    punti += 1000
    massi = []
    fase = .grottaFatta
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
  }

  private func preparaGrotta() {
    xEroe = 12
    cammina = true
    massi = []
    lampo = nil; lampoFino = 0
    prossimo = 24
    // Le gemme cadono a sorte lungo il percorso, mai due attaccate.
    var punto = Sorte.fra(60.0, 110.0)
    var trovate: [Gemma] = []
    while punto < Self.uscita - 20 {
      trovate.append(Gemma(x: punto))
      punto += Sorte.fra(60.0, 100.0)
    }
    gemme = trovate
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, grottaFatta, fine }

  private struct Masso {
    var x: Double
    var y: Double
  }

  private struct Gemma {
    var x: Double
    var presa = false
  }
}

enum OggettiGrotta {
  /// Un masso tondo con la luce in alto a sinistra e l'ombra sotto: si capisce
  /// che è pesante, e che sta cadendo.
  static let masso = SpritePixel(righe: [
    "..BBBB..",
    ".BMMMMS.",
    "BMMMMMMS",
    "MMMMMMSS",
    "MMMMMSSS",
    "SMMMSSSS",
    ".SSSSSS.",
    "..SSSS..",
  ])
}
