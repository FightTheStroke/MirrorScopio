import SwiftUI

/// **La traversata** — il fiume da attraversare saltando di zattera in zattera.
///
/// È il gioco delle rane del Commodore, girato dalla parte gentile: non c'è
/// niente che ti investe, ci sono zattere che passano e bisogna scegliere il
/// momento. Chi finisce in acqua non annega e non ricomincia: galleggia e la
/// corrente lo riporta alla zattera di prima. Si perde un pezzo di strada, mai
/// la partita.
///
/// Il tempo è tutto il gioco, ma è un tempo lungo: le zattere passano larghe e
/// spesso, e più spesso ancora se le ultime prove sono andate storte.
struct GiocoTraversata: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var corsie: [Corsia] = []
  @State private var riva = 0
  @State private var salto: Double?
  @State private var punti = 0
  @State private var sponde = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let xEroe: Double = 152
  private static let quante = 5

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 900)
      _sponde = State(initialValue: 1)
      _riva = State(initialValue: 2)
      _corsie = State(initialValue: Self.corsieFisse())
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LA TRAVERSATA",
      sottotitolo: fase == .titolo ? "DI ZATTERA IN ZATTERA"
        : "FIUME \(sponde + 1) · \(d.nome)",
      punti: punti, statoDestra: "SPONDE \(sponde)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Il fiume si attraversa saltando sulle zattere che passano. Aspetta che una arrivi davanti a te, poi premi. Se finisci in acqua galleggi: la corrente ti riporta indietro di una zattera, e si riprova."
    case .gioco:
      riva == 0 ? "Aspetta la zattera e salta." : "Bravo. Ancora una, con calma."
    case .sponda: "Sponda raggiunta. Il fiume dopo è un po' diverso: le zattere passano da un'altra parte."
    case .fine: "Hai attraversato tutto il fiume. Nessuno ti ha messo fretta, e sei arrivato dall'altra parte."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: "PREMI SPAZIO PER SALTARE"
    case .sponda: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La traversata. Salta di zattera in zattera, non si può perdere. Premi per giocare."
    case .gioco:
      return riva >= Self.quante ? "Sei sull'ultima zattera, manca la sponda."
        : (zatteraDavanti(riva + 1) != nil
           ? "C'è una zattera davanti a te: premi adesso."
           : "Acqua libera: aspetta la prossima zattera.")
    case .sponda: return "Sponda raggiunta. Premi per continuare."
    case .fine: return "Hai attraversato il fiume. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  /// L'altezza della riva numero `n`: 0 è la sponda di partenza in basso,
  /// `quante + 1` è quella d'arrivo in alto.
  private static func y(_ n: Int) -> Double { 172 - Double(n) * 26 }

  /// Dove poggiano i piedi su ciascuna riva: sulla sponda è l'erba, in mezzo
  /// al fiume è il bordo di sopra della zattera. Senza questa distinzione il
  /// personaggio sembrava affondato dentro il legno.
  private static func appoggio(_ n: Int) -> Double {
    if n <= 0 { return y(0) + 4 }
    if n > quante { return y(quante + 1) + 2 }
    return y(n) - 4
  }

  private func disegna(_ p: Pennello) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.blu)

    // L'acqua: righe orizzontali che si spostano piano. Danno il senso della
    // corrente senza riempire lo sfondo di roba che distrae.
    for i in 0..<24 {
      let y = 24 + Double(i) * 6
      let scorrimento = fermo ? 0 : Double((battiti / 3 + i * 7) % 40)
      p.rettangolo(scorrimento, y, 22, 2, C64.bluChiaro.opacity(0.5))
      p.rettangolo(scorrimento + 150, y, 16, 2, C64.bluChiaro.opacity(0.35))
    }

    // Le due sponde: erba, ferma, sicura.
    sponda(p, y: Self.y(0) + 4)
    sponda(p, y: Self.y(Self.quante + 1) - 12)

    for c in corsie {
      for x in c.zattere { zattera(p, x: x, y: Self.y(c.indice) - 4, lunghezza: c.lunghezza) }
    }

    let da = Self.appoggio(riva)
    let a = Self.appoggio(min(riva + 1, Self.quante + 1))
    let y = salto == nil ? da : da + (a - da) * (salto ?? 0)
    let sprite = salto == nil ? Personaggi.fermo : Personaggi.salto
    p.appoggia(sprite, x: Self.xEroe, suolo: y, colori: Personaggi.eroe)

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  /// Una zattera di tronchi legati. I bordi chiari servono a far vedere fin
  /// dove si può atterrare: il confine dev'essere leggibile a colpo d'occhio.
  private func zattera(_ p: Pennello, x: Double, y: Double, lunghezza: Double) {
    p.rettangolo(x, y, lunghezza, 12, C64.marrone)
    p.rettangolo(x, y, lunghezza, 2, C64.arancio)
    p.rettangolo(x, y + 10, lunghezza, 2, C64.arancio)
    for t in stride(from: x + 6, to: x + lunghezza - 2, by: 12) {
      p.rettangolo(t, y + 2, 2, 8, C64.nero.opacity(0.45))
    }
  }

  private func sponda(_ p: Pennello, y: Double) {
    p.rettangolo(0, y, SchermoRetro.larghezza, 14, C64.verde)
    p.rettangolo(0, y, SchermoRetro.larghezza, 3, C64.verdeChiaro)
  }

  // MARK: - Le regole

  /// La zattera che in questo istante sta davvero sotto i piedi, se c'è.
  private func zatteraDavanti(_ indice: Int) -> Double? {
    guard indice >= 1, indice <= Self.quante else { return nil }
    guard let c = corsie.first(where: { $0.indice == indice }) else { return nil }
    let mezzo = Self.xEroe + 10
    return c.zattere.first { mezzo >= $0 - 4 && mezzo <= $0 + c.lunghezza + 4 }
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; sponde = 0; preparaFiume(); fase = .gioco
    case .gioco:
      guard salto == nil else { return }
      if fermo { atterra(su: riva + 1) } else { salto = 0 }
    case .sponda:
      if sponde >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaFiume(); fase = .gioco
      }
    case .fine:
      sponde = 0; punti = 0; preparaFiume(); fase = .titolo
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo, fase == .gioco else { return }

    for i in corsie.indices { corsie[i].scorri(d.velocita) }

    if let s = salto {
      let avanti = s + 1.0 / 9.0
      if avanti >= 1 { salto = nil; atterra(su: riva + 1) } else { salto = avanti }
    }
  }

  /// L'atterraggio. È l'unico punto in cui si decide qualcosa, e la decisione
  /// non è mai «hai perso»: o si sale, o la corrente riporta indietro di uno.
  private func atterra(su nuova: Int) {
    if nuova > Self.quante {
      riva = Self.quante + 1
      sponde += 1
      punti += 1000
      fase = .sponda
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
      return
    }
    if fermo || zatteraDavanti(nuova) != nil {
      riva = nuova
      punti += 150
      mostra(.punti(150))
      d.andataBene()
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
    } else {
      riva = max(0, riva - 1)
      mostra(.ancora)
      d.andataMale()
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
    }
  }

  private func preparaFiume() {
    riva = 0
    salto = nil; lampo = nil; lampoFino = 0
    corsie = fermo ? Self.corsieFisse() : (1...Self.quante).map { i in
      // Ogni corsia è estratta a sorte: da che parte va, quanto è veloce,
      // quanto sono lunghe le zattere. Ma il passo fra una zattera e l'altra
      // ha un tetto: l'attesa non può mai diventare eterna.
      let lunghezza = Sorte.fra(46.0, 78.0) - Double(d.passo) * 3
      let passo = min(150.0, lunghezza + Sorte.fra(34.0, 62.0) + Double(6 - d.passo) * 4)
      return Corsia(indice: i,
                    verso: Sorte.moneta() ? 1 : -1,
                    velocita: Sorte.fra(0.7, 1.5),
                    lunghezza: lunghezza,
                    passo: passo,
                    partenza: Sorte.fra(0, passo))
    }
  }

  /// Il fiume del modo senza movimento e quello della fotografia: le zattere
  /// stanno ferme, una per corsia, sempre davanti a chi salta.
  private static func corsieFisse() -> [Corsia] {
    (1...quante).map { i in
      Corsia(indice: i, verso: 1, velocita: 0, lunghezza: 64, passo: 150,
             partenza: xEroe - 24 + Double((i % 3) - 1) * 8)
    }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, sponda, fine }

  /// Una corsia del fiume: zattere tutte uguali, distanziate uguali, che
  /// scorrono in un verso solo. La regolarità è voluta — un ritmo prevedibile
  /// si impara guardandolo, e chi ha bisogno di più tempo può contarlo.
  private struct Corsia {
    let indice: Int
    let verso: Double
    let velocita: Double
    let lunghezza: Double
    let passo: Double
    var partenza: Double

    var zattere: [Double] {
      stride(from: -passo, through: SchermoRetro.larghezza + passo, by: passo)
        .map { $0 + partenza }
        .filter { $0 > -lunghezza && $0 < SchermoRetro.larghezza + 4 }
    }

    mutating func scorri(_ fattore: Double) {
      partenza += verso * velocita * fattore
      if partenza > passo { partenza -= passo }
      if partenza < 0 { partenza += passo }
    }
  }
}
