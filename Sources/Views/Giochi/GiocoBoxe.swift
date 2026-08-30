import SwiftUI

/// **La boxe** — il Fight Camp 2026, insieme all'ultimate e all'hip hop.
///
/// Il maestro di boxe del camp l'ha detto meglio di chiunque: «la boxe
/// richiede un controllo simultaneo dei quattro arti… un errore tipico di
/// chiunque inizi è concentrarsi esclusivamente su un arto, tralasciando gli
/// altri». Sul ring il pugno non è il punto: il punto sono **i piedi**.
///
/// Perciò qui non si preme per tirare. Si preme per **cambiare direzione**:
/// avanti o indietro. Quando il colpitore del maestro si accende e tu sei alla
/// distanza giusta, il diretto parte da solo — perché a quel punto l'hai già
/// fatto tutto tu, con gli spostamenti.
///
/// **Non si prende mai un colpo.** Se il colpitore si spegne senza che tu ci
/// sia arrivato compare «ANCORA» e il maestro lo riapre. Niente di più.
struct GiocoBoxe: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var xPugile: Double = 60
  /// +1 va avanti, -1 torna indietro.
  @State private var verso: Double = 1
  @State private var colpitoreAcceso = false
  @State private var restaCosi = 40
  @State private var direttoFino = 0
  @State private var colpi = 0
  @State private var riprese = 0
  @State private var punti = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let suolo: Double = 150
  private static let xMaestro: Double = 208
  private static let colpiPerRipresa = 6

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1750)
      _colpi = State(initialValue: 3)
      _riprese = State(initialValue: 1)
      _xPugile = State(initialValue: 176)
      _colpitoreAcceso = State(initialValue: true)
      _direttoFino = State(initialValue: 8)
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  /// La misura: la distanza a cui il diretto arriva. Si allarga quando le cose
  /// vanno storte, come tutto il resto in questi giochi.
  private var misura: ClosedRange<Double> {
    let centro = Self.xMaestro - 62
    let mezza = d.tolleranza + 12
    return (centro - mezza)...(centro + mezza)
  }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LA BOXE",
      sottotitolo: fase == .titolo ? "I PIEDI PRIMA DEL PUGNO"
        : "RIPRESA \(riprese + 1) · COLPI \(colpi) DI \(Self.colpiPerRipresa) · \(d.nome)",
      punti: punti, statoDestra: "RIPRESE \(riprese)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Nella boxe conta dove stanno i piedi. Tu cammini da solo: premendo cambi direzione, avanti o indietro. Quando il colpitore si apre e tu sei dentro la misura — la striscia disegnata a terra — il diretto parte da sé."
    case .gioco: "Stai dentro la striscia quando il colpitore si apre."
    case .ripresaFatta: "Ripresa finita. Il maestro apre a tempi diversi."
    case .fine: "Tre riprese. I piedi hanno lavorato più delle mani."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: ENTRI IN MISURA E TIRI" : "PREMI SPAZIO PER CAMBIARE DIREZIONE"
    case .ripresaFatta: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La boxe. Premi per cambiare direzione e stare nella misura giusta. Premi per giocare."
    case .gioco:
      let dove = inMisura() ? "sei dentro la misura" : (xPugile < misura.lowerBound ? "sei troppo lontano" : "sei troppo vicino")
      let cosa = colpitoreAcceso ? "il colpitore è aperto" : "il colpitore è chiuso"
      return "\(cosa.capitalized) e \(dove). Vai \(verso > 0 ? "avanti" : "indietro"). Colpi \(colpi) di \(Self.colpiPerRipresa)."
    case .ripresaFatta: return "Ripresa finita. Premi per continuare."
    case .fine: return "Tre riprese fatte. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.palestra(p, suolo: Self.suolo)

    // Il ring: tre corde e i due pali agli angoli. Incornicia la scena invece
    // di sembrare un muro a righe sul fondo.
    // Il pubblico, in alto: sagome piccole dietro il ring.
    for i in 0..<16 {
      let x = 6 + Double(i) * 20
      p.rettangolo(x, 18, 12, 14, i % 2 == 0 ? C64.viola : C64.blu)
      p.rettangolo(x + 3, 12, 6, 6, C64.arancio)
    }
    for riga in 0..<3 {
      p.rettangolo(6, 48 + Double(riga) * 30, SchermoRetro.larghezza - 12, 4, C64.rosso)
    }
    p.rettangolo(4, 42, 10, Self.suolo - 42, C64.grigioChiaro)
    p.rettangolo(SchermoRetro.larghezza - 14, 42, 10, Self.suolo - 42, C64.grigioChiaro)

    // La misura disegnata a terra: una striscia, con i due paletti ai bordi.
    // È una forma, non una tinta: si vede anche a chi i colori si somigliano.
    p.rettangolo(misura.lowerBound, Self.suolo, misura.upperBound - misura.lowerBound, 10, C64.giallo.opacity(0.55))
    p.rettangolo(misura.lowerBound, Self.suolo - 6, 3, 16, C64.bianco)
    p.rettangolo(misura.upperBound, Self.suolo - 6, 3, 16, C64.bianco)

    p.appoggia(OggettiSport.maestro, x: Self.xMaestro, suolo: Self.suolo,
               colori: ["H": C64.marrone, "F": C64.arancio, "O": C64.nero,
                        "M": C64.viola, "G": C64.bianco, "S": C64.bianco])

    // Il colpitore, davanti alle mani del maestro. Aperto è il cuscino tondo
    // col centro chiaro; chiuso è girato di taglio e diventa una lista sottile.
    if colpitoreAcceso {
      p.sprite(OggettiSport.colpitore, x: Self.xMaestro - 16, y: Self.suolo - 22,
               colori: ["C": C64.rosso, "M": C64.bianco, "G": C64.marrone])
    } else {
      p.rettangolo(Self.xMaestro - 4, Self.suolo - 20, 6, 16, C64.rosso)
    }

    let posa = direttoFino > 0 ? OggettiSport.pugileDiretto : OggettiSport.pugileGuardia
    p.appoggia(posa, x: xPugile, suolo: Self.suolo,
               colori: ["H": C64.giallo, "F": C64.arancio, "O": C64.nero,
                        "M": C64.rosso, "G": C64.ciano, "S": C64.bianco])

    // La freccia della direzione, per terra sotto i piedi: si vede da che
    // parte stai andando senza aspettare di vederti muovere.
    let fx = xPugile + 10
    p.rettangolo(fx - 10, Self.suolo + 14, 18, 3, C64.grigioChiaro)
    for i in 0..<5 {
      let alta = Double(10 - i * 2)
      p.rettangolo(fx + verso * (8 + Double(i) * 3), Self.suolo + 15 - alta / 2, 3, alta, C64.grigioChiaro)
    }

    // I colpi messi a segno, in tacche.
    for i in 0..<Self.colpiPerRipresa {
      p.rettangolo(10 + Double(i) * 16, SchermoRetro.altezza - 14, 12, 7,
                   i < colpi ? C64.giallo : C64.grigio)
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  private func inMisura() -> Bool { misura.contains(xPugile) }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; colpi = 0; riprese = 0; xPugile = 60; verso = 1
      colpitoreAcceso = true; restaCosi = durata(); fase = .gioco
    case .gioco:
      if fermo {
        // Senza movimento nessuno cammina da solo: un tocco ti mette in misura
        // e apre il colpitore, il diretto parte. Il gioco resta il gioco.
        xPugile = (misura.lowerBound + misura.upperBound) / 2
        colpitoreAcceso = true
        diretto()
      } else {
        verso = -verso
      }
    case .ripresaFatta:
      if riprese >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        colpi = 0; colpitoreAcceso = false; restaCosi = durata(); fase = .gioco
      }
    case .fine:
      riprese = 0; punti = 0; colpi = 0; fase = .titolo
    }
  }

  private func diretto() {
    direttoFino = 10
    colpi += 1
    punti += 140
    mostra(.punti(140))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    colpitoreAcceso = false
    restaCosi = durata()
    if colpi >= Self.colpiPerRipresa {
      riprese += 1
      punti += 1000
      fase = .ripresaFatta
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if direttoFino > 0 { direttoFino -= 1 }
    guard !fermo, fase == .gioco else { return }

    xPugile += verso * 1.3 * d.velocita
    // Il ring ha i suoi bordi, e ai bordi si torna indietro da soli: non si
    // resta mai bloccati in un angolo.
    if xPugile < 12 { xPugile = 12; verso = 1 }
    if xPugile > Self.xMaestro - 34 { xPugile = Self.xMaestro - 34; verso = -1 }

    if colpitoreAcceso, inMisura() {
      diretto()
      return
    }

    restaCosi -= 1
    guard restaCosi <= 0 else { return }
    if colpitoreAcceso {
      // Si è chiuso senza che ci arrivassi: nessun colpo preso, solo un altro giro.
      colpitoreAcceso = false
      mostra(.ancora)
      d.andataMale()
      suoni.suona(.ancora, a11y: a11y.perIlMotore)
    } else {
      colpitoreAcceso = true
    }
    restaCosi = durata()
  }

  /// Quanto resta aperto o chiuso il colpitore. Aperto dura sempre abbastanza
  /// da poterci camminare dentro, anche al passo più svelto.
  private func durata() -> Int {
    if colpitoreAcceso {
      return max(24, Int(64 / d.velocita) + Sorte.fra(0, 10))
    }
    return max(12, Int(34 / d.velocita) + Sorte.fra(0, 16))
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, ripresaFatta, fine }
}
