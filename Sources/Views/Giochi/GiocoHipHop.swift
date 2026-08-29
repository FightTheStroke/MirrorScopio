import SwiftUI

/// **L'hip hop** — il Fight Camp 2026. L'insegnante l'ha raccontato così: «la
/// sfida è stata trovare soluzioni creative e motorie adattate alla propria
/// condizione, trasformando il limite in una possibilità espressiva unica». E
/// alla fine c'è stata la performance davanti a tutti.
///
/// Ballare è tenere il tempo, non essere veloci. Qui i passi della coreografia
/// arrivano da destra e passano sulla riga: quando un passo è sulla riga, si
/// preme. Non c'è da mirare e non c'è da scegliere: c'è da **stare a tempo**,
/// che è la cosa che al camp si impara imitando, un pezzo alla volta.
///
/// **La musica non si ferma mai.** Un passo mancato non fa ricominciare la
/// coreografia: compare «ANCORA» e il passo dopo arriva lo stesso. Alla fine
/// si balla comunque davanti a tutti.
struct GiocoHipHop: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  /// I passi che devono ancora arrivare, con la loro posizione e se sono doppi.
  @State private var passi: [Passo] = []
  @State private var fatti = 0
  @State private var coreografie = 0
  @State private var punti = 0
  @State private var posa = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let suolo: Double = 160
  private static let xRiga: Double = 74
  private static let yPassi: Double = 96
  private static let passiPerCoreografia = 12

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1900)
      _fatti = State(initialValue: 5)
      _coreografie = State(initialValue: 1)
      _posa = State(initialValue: 8)
      _passi = State(initialValue: Self.coreografiaFissa())
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "L'HIP HOP",
      sottotitolo: fase == .titolo ? "STAI A TEMPO"
        : "COREOGRAFIA \(coreografie + 1) · PASSI \(fatti) DI \(Self.passiPerCoreografia) · \(d.nome)",
      punti: punti, statoDestra: "BALLI \(coreografie)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "I passi della coreografia arrivano da destra e passano sulla riga. Quando un passo è sulla riga, premi. Non serve essere veloci: serve stare a tempo. I passi doppi, quelli più larghi, valgono di più."
    case .gioco: "Premi quando il passo è sulla riga."
    case .ballata: "Coreografia finita. Ne arriva un'altra, con il tempo diverso."
    case .fine: "Tre coreografie, e la performance davanti a tutti."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: IL PASSO ARRIVA E LO FAI" : "PREMI SPAZIO PER FARE IL PASSO"
    case .ballata: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "L'hip hop. Premi quando il passo arriva sulla riga. Premi per giocare."
    case .gioco:
      return (sullaRiga() != nil ? "C'è un passo sulla riga: premi adesso. " : "Il passo sta arrivando: aspetta. ")
        + "Passi \(fatti) di \(Self.passiPerCoreografia)."
    case .ballata: return "Coreografia finita. Premi per continuare."
    case .fine: return "Tre coreografie fatte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.palestra(p, suolo: Self.suolo)

    // I manifesti alla parete: la sala non è una stanza vuota.
    p.rettangolo(20, 22, 44, 52, C64.viola)
    p.rettangolo(24, 26, 36, 30, C64.giallo)
    p.rettangolo(24, 60, 36, 6, C64.bianco)
    p.rettangolo(84, 30, 50, 40, C64.rosso)
    p.rettangolo(88, 34, 42, 24, C64.ciano)
    p.rettangolo(88, 62, 42, 4, C64.bianco)

    // La cassa della musica, in fondo a destra: dice da dove viene il tempo.
    p.rettangolo(258, 24, 52, 62, C64.marrone)
    p.rettangolo(258, 24, 52, 4, C64.arancio)
    p.rettangolo(268, 34, 32, 22, C64.nero)
    p.rettangolo(274, 40, 20, 10, C64.grigioChiaro)
    p.rettangolo(268, 62, 32, 16, C64.nero)
    p.rettangolo(276, 66, 16, 8, C64.grigioChiaro)

    // La riga del tempo: alta, spessa, con la finestra buona segnata dai
    // paletti. È una forma, non un colore.
    let mezza = d.tolleranza + 8
    p.rettangolo(Self.xRiga - mezza, Self.yPassi - 8, mezza * 2, 34, C64.viola.opacity(0.5))
    p.rettangolo(Self.xRiga - 2, Self.yPassi - 14, 5, 46, C64.bianco)
    p.rettangolo(Self.xRiga - mezza, Self.yPassi - 14, 3, 46, C64.grigioChiaro)
    p.rettangolo(Self.xRiga + mezza, Self.yPassi - 14, 3, 46, C64.grigioChiaro)

    for passo in passi where passo.x > -20 && passo.x < SchermoRetro.larghezza {
      p.sprite(passo.doppio ? OggettiSport.passoDoppio : OggettiSport.passo,
               x: passo.x, y: Self.yPassi,
               colori: ["P": passo.doppio ? C64.giallo : C64.ciano])
    }

    // Chi balla: cambia posa a ogni passo preso. Il ballo si vede.
    let figura: SpritePixel = posa > 6 ? Personaggi.tifo : (posa > 0 ? Personaggi.salto : Personaggi.fermo)
    p.appoggia(figura, x: 22, suolo: Self.suolo, colori: Personaggi.eroe)

    // I compagni che ballano con te: al camp non si balla mai da soli.
    p.appoggia(posa > 3 ? Personaggi.tifo : Personaggi.fermo, x: 246,
               suolo: Self.suolo, colori: Personaggi.compagno(1))
    p.appoggia(posa > 3 ? Personaggi.fermo : Personaggi.tifo, x: 280,
               suolo: Self.suolo, colori: Personaggi.compagno(2))

    // I passi già fatti, in tacche.
    for i in 0..<Self.passiPerCoreografia {
      p.rettangolo(8 + Double(i) * 12, SchermoRetro.altezza - 12, 9, 6,
                   i < fatti ? C64.giallo : C64.grigio)
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  /// Il passo che sta davvero sulla riga adesso.
  private func sullaRiga() -> Int? {
    passi.indices.first { abs(passi[$0].x + 6 - Self.xRiga) < d.tolleranza + 8 }
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; fatti = 0; coreografie = 0; preparaCoreografia(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento la musica non scorre: ogni tocco porta il passo
        // successivo sulla riga e lo fa. Si balla lo stesso, a proprio tempo.
        guard !passi.isEmpty else { return }
        passi[0].x = Self.xRiga - 6
        prendi(0)
      } else if let i = sullaRiga() {
        prendi(i)
      } else {
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
      }
    case .ballata:
      if coreografie >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        preparaCoreografia(); fase = .gioco
      }
    case .fine:
      coreografie = 0; punti = 0; fatti = 0; fase = .titolo
    }
  }

  private func prendi(_ i: Int) {
    let valore = passi[i].doppio ? 220 : 120
    passi.remove(at: i)
    fatti += 1
    posa = 12
    punti += valore
    mostra(.punti(valore))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    if fatti >= Self.passiPerCoreografia {
      coreografie += 1
      punti += 1000
      fase = .ballata
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if posa > 0 { posa -= 1 }
    guard !fermo, fase == .gioco else { return }

    let passo = 1.5 * d.velocita
    for i in passi.indices { passi[i].x -= passo }
    // Un passo che esce dallo schermo è un passo perso, e basta: la musica non
    // si ferma e non si ricomincia niente.
    if let primo = passi.first, primo.x < -20 {
      passi.removeFirst()
      fatti += 1
      mostra(.ancora)
      d.andataMale()
      if fatti >= Self.passiPerCoreografia {
        coreografie += 1
        punti += 500
        fase = .ballata
      }
    }
  }

  /// Una coreografia nuova ogni volta: gli intervalli cambiano, ma non
  /// scendono mai sotto una distanza che si riesce a tenere.
  private func preparaCoreografia() {
    fatti = 0
    lampo = nil
    lampoFino = 0
    guard !fermo else { passi = Self.coreografiaFissa(); return }
    var nuovi: [Passo] = []
    var x: Double = SchermoRetro.larghezza + 30
    for i in 0..<Self.passiPerCoreografia {
      nuovi.append(Passo(x: x, doppio: i % 4 == 3))
      x += max(46, 84 - d.densita * 14 + Sorte.fra(-10.0, 16.0))
    }
    passi = nuovi
  }

  /// La coreografia del modo senza movimento e delle fotografie: passi in fila,
  /// sempre alla stessa distanza.
  private static func coreografiaFissa() -> [Passo] {
    (0..<passiPerCoreografia).map { i in
      Passo(x: xRiga - 6 + Double(i) * 62, doppio: i % 4 == 3)
    }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, ballata, fine }

  private struct Passo {
    var x: Double
    /// I passi doppi sono più larghi e valgono di più: la differenza si vede
    /// nella forma, non solo nel punteggio.
    var doppio: Bool
  }
}
