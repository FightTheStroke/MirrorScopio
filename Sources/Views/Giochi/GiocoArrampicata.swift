import SwiftUI

/// **L'arrampicata** — lo sport del Fight Camp 2020, e ancora del 2021 sulla
/// parete sensorizzata costruita dal Politecnico di Milano.
///
/// Al camp la parete serve a due mani insieme: si afferra la presa, si spinge
/// con tutti e due i piedi, e si decide *prima* dove andare. Qui succede la
/// stessa cosa con un tasto solo. Sopra di te scorre la mano, avanti e
/// indietro; quando passa su una presa, premi e ti agganci.
///
/// **Non si cade mai.** Se la mano afferra il vuoto non succede niente di
/// brutto: resti dove sei, compare «ANCORA» e la mano ripassa. La parete non
/// finisce mai in mezzo: sopra c'è sempre una presa raggiungibile, perché una
/// parete impossibile non è una sfida, è una bugia.
struct GiocoArrampicata: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  /// Ogni riga della parete è l'elenco delle x delle sue prese, dal basso.
  @State private var parete: [[Double]] = []
  @State private var altezza = 0
  @State private var xMano: Double = 40
  @State private var verso: Double = 1
  @State private var punti = 0
  @State private var pareti = 0
  @State private var scorrimento: Double = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  /// Quante righe ha una parete, e dove stanno sullo schermo. Chi arrampica sta
  /// sempre alla stessa altezza: è la parete che scende, come in un gioco vero.
  private static let righePerParete = 6
  private static let yPresa: Double = 128
  private static let passoRiga: Double = 38

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 900)
      _pareti = State(initialValue: 1)
      _altezza = State(initialValue: 2)
      _xMano = State(initialValue: 148)
      _parete = State(initialValue: Self.pareteFissa())
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "L'ARRAMPICATA",
      sottotitolo: fase == .titolo ? "AFFERRA LA PRESA"
        : "PARETE \(pareti + 1) · PRESA \(altezza) DI \(Self.righePerParete) · \(d.nome)",
      punti: punti, statoDestra: "PARETI \(pareti)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "La parete del Fight Camp, quella vera con i sensori dentro. La mano scorre da sola sopra di te: premi quando è sopra una presa e ti agganci. Se afferra il vuoto non caschi — resti dove sei e la mano ripassa."
    case .gioco: "Guarda dove passa la mano, poi premi."
    case .cima: "Sei in cima. Ne arriva un'altra, con le prese messe in un altro modo."
    case .fine: "Tre pareti, tutte fino in cima. Una presa alla volta."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: LA MANO VA ALLA PRESA" : "PREMI SPAZIO PER AFFERRARE"
    case .cima: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "L'arrampicata. La mano scorre da sola, tu scegli quando afferrare. Premi per giocare."
    case .gioco:
      return (presaSottoLaMano() != nil ? "La mano è sopra una presa: premi adesso. "
                : "La mano è sul liscio: aspetta. ")
        + "Sei alla presa \(altezza) di \(Self.righePerParete)."
    case .cima: return "Parete finita. Premi per continuare."
    case .fine: return "Tre pareti fatte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.parete(p, scorrimento: scorrimento)

    // Le prese: quella su cui sei, quelle sopra, e una sotto per far vedere da
    // dove sei venuto. La parete si legge come una scala di appigli.
    for salto in -1...3 {
      let riga = altezza + salto
      guard riga >= 0, riga < parete.count else { continue }
      let y = Self.yPresa - Double(salto) * Self.passoRiga
      for x in parete[riga] {
        p.sprite(OggettiSport.presa, x: x, y: y,
                 colori: ["P": salto == 0 ? C64.arancio : C64.verdeChiaro,
                          "I": C64.marrone])
      }
    }

    // Chi arrampica sta appeso alla presa su cui è: le braccia in alto.
    p.sprite(Personaggi.tifo, x: xAncoraggio() - 4, y: Self.yPresa - 6,
             colori: Personaggi.eroe)

    // La mano che cerca, sulla riga sopra.
    if altezza + 1 < parete.count {
      p.sprite(OggettiSport.mano, x: xMano, y: Self.yPresa - Self.passoRiga + 12,
               colori: ["D": C64.giallo])
      // Il filo che collega la mano a chi arrampica: dice a chi appartiene.
      p.rettangolo(xMano + 6, Self.yPresa - Self.passoRiga + 22, 2,
                   Self.passoRiga - 22, C64.giallo.opacity(0.5))
    }

    // Il metro a lato: quante prese mancano alla cima, disegnate a tacche.
    for riga in 0..<Self.righePerParete {
      let y = SchermoRetro.altezza - 16 - Double(riga) * 10
      p.rettangolo(SchermoRetro.larghezza - 14, y, 10, 6,
                   riga < altezza ? C64.verdeChiaro : C64.grigio)
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  /// Dove sta la presa a cui è appeso adesso.
  private func xAncoraggio() -> Double {
    guard altezza < parete.count, let prima = parete[altezza].first else { return 140 }
    return parete[altezza].min(by: { abs($0 - xMano) < abs($1 - xMano) }) ?? prima
  }

  // MARK: - Le regole

  /// La presa che la mano ha davvero sotto di sé. La tolleranza si allarga
  /// quando le cose vanno storte: chi fa fatica trova la parete più larga, non
  /// un gioco diverso.
  private func presaSottoLaMano() -> Double? {
    guard altezza + 1 < parete.count else { return nil }
    return parete[altezza + 1].first { abs($0 - xMano) < d.tolleranza + 6 }
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; pareti = 0; preparaParete(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento la mano non insegue niente: si mette da sé sulla
        // presa più vicina e si aggancia. Resta arrampicata, smette di essere
        // una coincidenza da azzeccare.
        guard altezza + 1 < parete.count,
              let presa = parete[altezza + 1].min(by: { abs($0 - xMano) < abs($1 - xMano) })
        else { return }
        xMano = presa
        aggancia(presa)
      } else if let presa = presaSottoLaMano() {
        aggancia(presa)
      } else {
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
      }
    case .cima:
      if pareti >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaParete(); fase = .gioco
      }
    case .fine:
      pareti = 0; punti = 0; preparaParete(); fase = .titolo
    }
  }

  private func aggancia(_ presa: Double) {
    altezza += 1
    punti += 120
    mostra(.punti(120))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    xMano = presa
    if altezza >= Self.righePerParete {
      pareti += 1
      punti += 1000
      fase = .cima
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }
    xMano += verso * 1.4 * d.velocita
    if xMano < 6 { xMano = 6; verso = 1 }
    if xMano > SchermoRetro.larghezza - 34 { xMano = SchermoRetro.larghezza - 34; verso = -1 }
    scorrimento += 0.2
  }

  /// Una parete nuova ogni volta: quante prese per riga e dove. Mai meno di
  /// due per riga, e mai due righe di fila con le prese tutte da una parte —
  /// così la mano che scorre incontra sempre qualcosa da afferrare.
  private func preparaParete() {
    altezza = 0
    xMano = 40
    verso = 1
    lampo = nil
    lampoFino = 0
    guard !fermo else { parete = Self.pareteFissa(); return }
    var righe: [[Double]] = []
    for _ in 0...Self.righePerParete {
      let quante: Int = max(2, 4 - Int(d.densita))
      let passo: Double = 260 / Double(quante)
      var riga: [Double] = []
      for i in 0..<quante {
        riga.append(20 + Double(i) * passo + Sorte.fra(-10.0, 10.0))
      }
      righe.append(riga.sorted())
    }
    parete = righe
  }

  /// La parete del modo senza movimento e delle fotografie: tre prese per
  /// riga, sempre le stesse, così una schermata si può guardare con calma.
  private static func pareteFissa() -> [[Double]] {
    (0...righePerParete).map { riga in
      let sfasa = Double(riga % 2) * 30
      return [24 + sfasa, 124 + sfasa, 224 + sfasa]
    }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, cima, fine }
}
