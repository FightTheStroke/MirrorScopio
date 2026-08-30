import SwiftUI

/// **Lo skateboard** — il Fight Camp 2024, insieme al calcio e al flag
/// football.
///
/// Sulla tavola non conta la velocità: conta stare in equilibrio, e
/// l'equilibrio non si tiene una volta per tutte — si aggiusta di continuo,
/// spostando il peso da un piede all'altro. È esattamente il lavoro che il
/// camp chiede al controllo posturale.
///
/// Qui la tavola pende sempre un po' da una parte, e premendo si sposta il
/// peso dall'altra. Non c'è niente da colpire e niente da schivare: c'è da
/// restare in mezzo mentre la strada scorre.
///
/// **Non si cade.** Quando la tavola pende troppo si appoggia un piede a
/// terra: compare «ANCORA», la tavola torna dritta e si riparte da lì. La
/// strada non torna mai indietro.
struct GiocoSkate: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  /// Da -1 (tutta a sinistra) a +1 (tutta a destra). Zero è dritta.
  @State private var inclinazione: Double = 0
  /// Da che parte tira la strada adesso.
  @State private var deriva: Double = 0.010
  /// Da che parte è il peso: -1 sinistra, +1 destra.
  @State private var peso: Double = -1
  @State private var distanza: Double = 0
  @State private var piediATerra = 0
  @State private var discese = 0
  @State private var punti = 0
  @State private var prossimaRaffica: Double = 120
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let arrivo: Double = 800
  private static let suolo: Double = 160
  private static let xTavola: Double = 140

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1250)
      _discese = State(initialValue: 1)
      _distanza = State(initialValue: 420)
      _inclinazione = State(initialValue: -0.35)
      _peso = State(initialValue: 1)
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LO SKATE",
      sottotitolo: fase == .titolo ? "TIENI LA TAVOLA DRITTA"
        : "DISCESA \(discese + 1) · \(Int(distanza)) DI \(Int(Self.arrivo)) · \(d.nome)",
      punti: punti, statoDestra: "DISCESE \(discese)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "La tavola pende sempre un po' da una parte. Premendo sposti il peso dall'altra e la raddrizzi. Non c'è niente da schivare: c'è solo da restare in mezzo. Se pende troppo appoggi un piede e riparti, non cadi."
    case .gioco: "Guarda da che parte pende e sposta il peso."
    case .arrivo: "Discesa finita in piedi. Ne arriva un'altra, che tira in un altro modo."
    case .fine: "Tre discese. La tavola l'hai tenuta tu."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: RADDRIZZI E AVANZI" : "PREMI SPAZIO PER SPOSTARE IL PESO"
    case .arrivo: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "Lo skate. Premi per spostare il peso e tenere la tavola dritta. Premi per giocare."
    case .gioco:
      let dove = inclinazione < -0.15 ? "a sinistra" : (inclinazione > 0.15 ? "a destra" : "dritta")
      let mio = peso < 0 ? "sinistra" : "destra"
      return "La tavola pende \(dove), il peso è a \(mio). \(Int(distanza)) su \(Int(Self.arrivo))."
    case .arrivo: return "Discesa finita. Premi per continuare."
    case .fine: return "Tre discese fatte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.strada(p, suolo: Self.suolo, avanzamento: -distanza)

    // I birilli lungo la strada: non c'è da schivarli, servono a far vedere
    // che si avanza davvero.
    var m = (distanza / 90).rounded(.down) * 90
    while m < distanza + 400 {
      let sx = m - distanza + Self.xTavola
      if sx > -8, sx < SchermoRetro.larghezza {
        p.rettangolo(sx, Self.suolo + 14, 10, 14, C64.arancio)
        p.rettangolo(sx + 2, Self.suolo + 9, 6, 6, C64.arancio)
      }
      m += 90
    }

    disegnaTavola(p)
    barraEquilibrio(p)

    // Il traguardo della discesa.
    let sx = Self.arrivo - distanza + Self.xTavola
    if sx > -20, sx < SchermoRetro.larghezza {
      for riga in 0..<9 {
        for colonna in 0..<2 where (riga + colonna) % 2 == 0 {
          p.rettangolo(sx + Double(colonna) * 8, Self.suolo - 74 + Double(riga) * 8, 8, 8, C64.bianco)
        }
      }
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  /// La tavola disegnata inclinata davvero: una colonna alla volta, ognuna un
  /// po' più su o più giù. Chi guarda vede la pendenza, non deve dedurla.
  private func disegnaTavola(_ p: Pennello) {
    let mezza: Double = 26
    var i: Double = -mezza
    while i < mezza {
      let y = Self.suolo - 10 + i * inclinazione * 0.55
      p.rettangolo(Self.xTavola + i, y, 4, 5, C64.marrone)
      i += 4
    }
    // Le ruote, alle due estremità.
    p.rettangolo(Self.xTavola - mezza + 4, Self.suolo - 6 - mezza * inclinazione * 0.55, 6, 6, C64.grigioChiaro)
    p.rettangolo(Self.xTavola + mezza - 8, Self.suolo - 6 + mezza * inclinazione * 0.55, 6, 6, C64.grigioChiaro)

    // Chi ci sta sopra: si sposta col peso, e quando il piede va a terra
    // cambia posa. La posa dice quello che dice la scritta, non di meno.
    // Chi ci sta sopra ha i piedi *sulla* tavola: la posa con le gambe aperte
    // aveva due righe vuote sotto e lo faceva galleggiare.
    let sposta = peso * 8
    let posa = piediATerra > 0 ? Personaggi.fermo : Personaggi.corsa
    p.appoggia(posa, x: Self.xTavola - 10 + sposta,
               suolo: Self.suolo - 9 + sposta * inclinazione * 0.55,
               colori: Personaggi.eroe)
  }

  /// La barra dell'equilibrio: un cursore fra due paletti. Fuori dai paletti si
  /// appoggia il piede. È l'unica cosa da guardare, quindi sta grande in alto.
  private func barraEquilibrio(_ p: Pennello) {
    let centro = SchermoRetro.larghezza / 2
    // Una targa scura sotto: senza, la barra si mescolava alle nuvole e al
    // sole e sembrava un tubo appeso in cielo.
    p.rettangolo(centro - 90, 10, 180, 36, C64.nero)
    p.rettangolo(centro - 86, 14, 172, 28, C64.bluScuro)
    p.rettangolo(centro - 30, 18, 60, 20, C64.verde)
    p.rettangolo(centro - 82, 16, 4, 24, C64.bianco)
    p.rettangolo(centro + 78, 16, 4, 24, C64.bianco)
    p.rettangolo(centro - 2, 18, 4, 20, C64.grigioChiaro)
    p.rettangolo(centro - 4 + inclinazione * 78, 14, 8, 28, C64.giallo)
  }

  // MARK: - Le regole

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; discese = 0; preparaDiscesa(); fase = .gioco
    case .gioco:
      peso = -peso
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
      if fermo {
        // Senza movimento la tavola non deriva: ogni tocco la rimette dritta e
        // fa un pezzo di strada. Resta uno skate, smette di essere un inseguire.
        inclinazione = 0
        avanza(di: 40)
      }
    case .arrivo:
      if discese >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaDiscesa(); fase = .gioco
      }
    case .fine:
      discese = 0; punti = 0; fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if piediATerra > 0 { piediATerra -= 1 }
    guard !fermo, fase == .gioco, piediATerra == 0 else { return }

    // La tavola pende per conto suo, e il peso la tira dalla parte opposta.
    inclinazione += deriva - peso * 0.016
    if abs(inclinazione) > 1 {
      inclinazione = 0
      piediATerra = 20
      mostra(.ancora)
      d.andataMale()
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
    } else if abs(inclinazione) < 0.2 {
      // Stare in mezzo è il gioco: è lì che si fanno i punti.
      punti += 2
    }
    avanza(di: 1.6 * d.velocita)

    if distanza > prossimaRaffica {
      // Ogni tanto la strada cambia inclinazione: mai due raffiche identiche,
      // e mai una così forte da non potersi vincere spostando il peso.
      deriva = Sorte.fra(-0.014, 0.014) * (0.7 + d.densita * 0.4)
      if abs(deriva) < 0.004 { deriva = deriva < 0 ? -0.006 : 0.006 }
      prossimaRaffica = distanza + Sorte.fra(90.0, 200.0)
    }
  }

  private func avanza(di quanto: Double) {
    distanza += quanto
    if distanza >= Self.arrivo {
      discese += 1
      punti += 1000
      d.andataBene()
      fase = .arrivo
    }
  }

  private func preparaDiscesa() {
    distanza = 0
    inclinazione = 0
    peso = -1
    piediATerra = 0
    lampo = nil
    lampoFino = 0
    deriva = fermo ? 0 : (Sorte.moneta() ? 0.010 : -0.010)
    prossimaRaffica = 130
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, arrivo, fine }
}
