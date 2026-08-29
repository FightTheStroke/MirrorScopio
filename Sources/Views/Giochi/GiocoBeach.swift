import SwiftUI

/// **Il beach volley** — il Fight Camp 2025, insieme al para-standing tennis e
/// al para-taekwondo. Sulla sabbia niente è stabile: ogni appoggio va deciso
/// prima, e il pallone dice dove andare molto prima di arrivarci.
///
/// Per questo qui **l'ombra sulla sabbia conta più del pallone**. L'ombra si
/// vede subito e sta ferma: dice dove cadrà. Chi gioca si sposta da solo verso
/// l'ombra — non c'è nessuno da guidare — e l'unica cosa da scegliere è
/// *quando* alzare le mani.
///
/// **Il pallone non va mai perso.** Se cade sulla sabbia lo si raccoglie e si
/// ributta su: compare «ANCORA» e lo scambio continua da lì.
struct GiocoBeach: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var xPallone: Double = 160
  @State private var yPallone: Double = 60
  @State private var vy: Double = 0
  @State private var xCaduta: Double = 160
  @State private var xGiocatore: Double = 60
  @State private var manialzate = 0
  @State private var scambio = 0
  @State private var scambi = 0
  @State private var punti = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let suolo: Double = 168
  private static let palleggiPerScambio = 8
  /// L'altezza a cui il pallone si può colpire: una fascia larga, non un punto.
  private static let yColpo: Double = 118

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1100)
      _scambio = State(initialValue: 5)
      _scambi = State(initialValue: 1)
      _xPallone = State(initialValue: 168)
      _yPallone = State(initialValue: 104)
      _xCaduta = State(initialValue: 180)
      _xGiocatore = State(initialValue: 166)
      _manialzate = State(initialValue: 8)
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "IL BEACH VOLLEY",
      sottotitolo: fase == .titolo ? "GUARDA L'OMBRA SULLA SABBIA"
        : "SCAMBIO \(scambi + 1) · PALLEGGI \(scambio) DI \(Self.palleggiPerScambio) · \(d.nome)",
      punti: punti, statoDestra: "SCAMBI \(scambi)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Sulla sabbia il pallone si legge dall'ombra: l'ombra sta ferma e dice dove cadrà. Chi gioca ci va da solo, tu scegli solo quando alzare le mani. Se il pallone tocca la sabbia lo raccogli e si continua."
    case .gioco: "Premi quando il pallone ti arriva all'altezza delle mani."
    case .scambioFatto: "Scambio lungo. Se ne fa un altro, con l'ombra che va in altri punti."
    case .fine: "Tre scambi tenuti su. Con due mani, tutte e due."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: VAI SOTTO E PALLEGGI" : "PREMI SPAZIO PER PALLEGGIARE"
    case .scambioFatto: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "Il beach volley. Premi quando il pallone arriva all'altezza delle mani. Premi per giocare."
    case .gioco:
      return (colpibile() ? "Il pallone è a tiro: premi adesso. " : "Il pallone è ancora alto: aspetta. ")
        + "Palleggi \(scambio) di \(Self.palleggiPerScambio)."
    case .scambioFatto: return "Scambio finito. Premi per continuare."
    case .fine: return "Tre scambi fatti. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.sabbia(p, suolo: Self.suolo)

    // La rete, sul fondo: maglie vere, non solo righe orizzontali — sette
    // righe da sole sembravano i pioli di una scala.
    p.rettangolo(SchermoRetro.larghezza - 30, Self.suolo - 78, 5, 78, C64.marrone)
    p.rettangolo(SchermoRetro.larghezza - 76, Self.suolo - 80, 51, 5, C64.bianco)
    for riga in 0..<6 {
      p.rettangolo(SchermoRetro.larghezza - 76, Self.suolo - 70 + Double(riga) * 10, 51, 2, C64.bianco)
    }
    for colonna in 0..<5 {
      p.rettangolo(SchermoRetro.larghezza - 74 + Double(colonna) * 10, Self.suolo - 76, 2, 66, C64.bianco)
    }

    // L'ombra: sta ferma, e per questo è l'unica cosa da guardare.
    p.sprite(OggettiSport.ombra, x: xCaduta - 8, y: Self.suolo + 2,
             colori: ["O": C64.marrone])
    // La linea che collega l'ombra al pallone: lega le due cose a colpo d'occhio.
    var y = Self.suolo - 2
    while y > yPallone + 16 {
      p.rettangolo(xCaduta - 1, y, 2, 4, C64.bianco.opacity(0.4))
      y -= 12
    }

    // La fascia a cui il pallone si può colpire: due tacche ai lati, così
    // l'altezza giusta si vede e non si indovina.
    var tacca: Double = 14
    while tacca < SchermoRetro.larghezza - 14 {
      p.rettangolo(tacca, Self.yColpo + 1, 6, 2, C64.bianco.opacity(0.35))
      tacca += 16
    }
    p.rettangolo(0, Self.yColpo, 14, 4, C64.verdeChiaro)
    p.rettangolo(SchermoRetro.larghezza - 14, Self.yColpo, 14, 4, C64.verdeChiaro)

    p.sprite(OggettiSport.pallone, x: xPallone - 8, y: yPallone,
             colori: ["P": C64.bianco, "B": C64.arancio])

    let posa = manialzate > 0 ? Personaggi.tifo : Personaggi.corsa
    p.appoggia(posa, x: xGiocatore - 10, suolo: Self.suolo, colori: Personaggi.eroe)

    // I palleggi fatti, in tacche.
    for i in 0..<Self.palleggiPerScambio {
      p.rettangolo(10 + Double(i) * 14, SchermoRetro.altezza - 14, 10, 7,
                   i < scambio ? C64.giallo : C64.grigio)
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  /// Il pallone si può colpire se sta scendendo dentro la fascia e chi gioca è
  /// abbastanza vicino. La fascia e la vicinanza si allargano quando le cose
  /// vanno storte.
  private func colpibile() -> Bool {
    let altezzaGiusta = abs(yPallone - Self.yColpo) < d.tolleranza + 14 && vy > 0
    let vicino = abs(xGiocatore - xPallone) < d.tolleranza + 26
    return altezzaGiusta && vicino
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; scambio = 0; scambi = 0; lancia(da: 160); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento non c'è niente da inseguire: si va sotto al pallone e
        // si palleggia. È lo stesso gioco, un tocco alla volta.
        xGiocatore = xCaduta
        xPallone = xCaduta
        palleggia()
      } else if colpibile() {
        palleggia()
      } else {
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
      }
    case .scambioFatto:
      if scambi >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        scambio = 0; lancia(da: xPallone); fase = .gioco
      }
    case .fine:
      scambi = 0; punti = 0; scambio = 0; fase = .titolo
    }
  }

  private func palleggia() {
    manialzate = 10
    scambio += 1
    punti += 110
    mostra(.punti(110))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    if scambio >= Self.palleggiPerScambio {
      scambi += 1
      punti += 1000
      fase = .scambioFatto
    } else {
      lancia(da: xPallone)
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if manialzate > 0 { manialzate -= 1 }
    guard !fermo, fase == .gioco else { return }

    // Chi gioca cammina da solo verso l'ombra: il gioco non chiede di guidare
    // nessuno, chiede solo di scegliere l'istante.
    let passo = 1.9 * d.velocita
    if abs(xGiocatore - xCaduta) > passo {
      xGiocatore += xGiocatore < xCaduta ? passo : -passo
    } else {
      xGiocatore = xCaduta
    }

    vy += 0.16
    yPallone += vy
    xPallone += (xCaduta - xPallone) * 0.05

    if yPallone > Self.suolo - 18 {
      // Il pallone in sabbia non finisce lo scambio: si raccoglie e si ributta.
      mostra(.ancora)
      d.andataMale()
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
      lancia(da: xCaduta)
    }
  }

  /// Il pallone risale, e l'ombra si mette da un'altra parte: mai troppo
  /// lontano da dove si è, perché nessuno debba correre per arrivarci.
  private func lancia(da x: Double) {
    xPallone = x
    yPallone = Self.suolo - 34
    vy = -3.4
    guard !fermo else { xCaduta = 180; return }
    let sposta = Sorte.fra(-70.0, 70.0) * (0.5 + d.densita * 0.5)
    xCaduta = min(SchermoRetro.larghezza - 40, max(30, x + sposta))
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, scambioFatto, fine }
}
