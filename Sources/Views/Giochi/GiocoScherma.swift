import SwiftUI

/// **La scherma in carrozzina** — lo sport del Fight Camp 2021, insegnato
/// insieme alla Federazione Scherma.
///
/// In carrozzina le gambe non servono a coprire la distanza: la distanza è
/// fissa, e conta solo *quando* parti. Per questo qui non c'è da inseguire
/// niente. L'avversario tiene la guardia alta, poi bassa, poi per un momento
/// si scopre: quello è l'istante dell'affondo.
///
/// Lo stato della guardia è scritto a parole in mezzo allo schermo, non
/// affidato al colore: «GUARDIA ALTA», «GUARDIA BASSA», «SCOPERTO». Chi non
/// distingue il verde dal rosso gioca esattamente lo stesso gioco.
///
/// **Non si perde mai un assalto.** Un affondo dato sulla guardia viene parato:
/// compare «ANCORA» e si riparte dalla posizione di guardia, senza contare
/// nessuna stoccata all'avversario. L'avversario qui non fa punti: è un
/// compagno che ti fa esercitare.
struct GiocoScherma: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: Fase = .titolo
  @State private var guardia: Guardia = .alta
  @State private var restaCosi = 40
  @State private var affondoFino = 0
  @State private var stoccate = 0
  @State private var assalti = 0
  @State private var punti = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @StateObject private var suoni = Suoni()

  private static let suolo: Double = 168
  private static let stoccatePerAssalto = 5

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _punti = State(initialValue: 1400)
      _stoccate = State(initialValue: 3)
      _assalti = State(initialValue: 1)
      _guardia = State(initialValue: .scoperto)
      _affondoFino = State(initialValue: 10)
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    CabinatoRetro(
      a11y: a11y, titolo: "LA SCHERMA",
      sottotitolo: fase == .titolo ? "AFFONDA QUANDO SI SCOPRE"
        : "\(guardia.scritta) · STOCCATE \(stoccate) DI \(Self.stoccatePerAssalto)",
      punti: punti, statoDestra: "ASSALTI \(assalti)",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, battiti: battiti,
      onPremi: premi, onBattito: battito, onClose: onClose,
      disegna: disegna, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Scherma in carrozzina, come al camp: la distanza è già giusta, conta solo quando parti. Il tuo compagno tiene la guardia alta, poi bassa, poi per un attimo si scopre. In mezzo allo schermo c'è scritto com'è messo: affonda quando dice SCOPERTO."
    case .gioco: "Aspetta la parola SCOPERTO, poi premi."
    case .assaltoFatto: "Assalto vinto. Se ne fa un altro, con i tempi diversi."
    case .fine: "Tre assalti. Hai aspettato il momento giusto ogni volta."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "PREMI SPAZIO PER GIOCARE"
    case .gioco: fermo ? "PREMI SPAZIO: LA GUARDIA CAMBIA, POI AFFONDI" : "PREMI SPAZIO PER AFFONDARE"
    case .assaltoFatto: "PREMI SPAZIO PER CONTINUARE"
    case .fine: "PREMI SPAZIO PER RIGIOCARE"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La scherma. Affonda quando il compagno si scopre. Premi per giocare."
    case .gioco:
      return "Il compagno è \(guardia.detto). "
        + (guardia == .scoperto ? "Affonda adesso. " : "Aspetta. ")
        + "Stoccate \(stoccate) di \(Self.stoccatePerAssalto)."
    case .assaltoFatto: return "Assalto vinto. Premi per continuare."
    case .fine: return "Tre assalti fatti. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private func disegna(_ p: Pennello) {
    SfondiSport.pedana(p, suolo: Self.suolo)

    // Lo striscione del camp sul fondo, e il pubblico: la pedana non sta nel
    // vuoto, e lo schermo non resta mezzo vuoto.
    p.rettangolo(30, 18, 260, 22, C64.rosso)
    p.rettangolo(30, 18, 260, 3, C64.giallo)
    p.rettangolo(30, 37, 260, 3, C64.giallo)
    for i in 0..<13 {
      p.rettangolo(36 + Double(i) * 20, 22, 6, 14, C64.giallo.opacity(0.7))
    }
    // La gradinata: teste piccole dietro una balaustra, non lecca-lecca.
    p.rettangolo(14, 66, 292, 4, C64.grigio)
    for i in 0..<14 {
      let x = 18 + Double(i) * 21
      p.rettangolo(x, 54, 10, 12, i % 3 == 0 ? C64.viola : (i % 3 == 1 ? C64.ciano : C64.verdeChiaro))
      p.rettangolo(x + 2, 48, 6, 6, C64.arancio)
    }

    let inAffondo = affondoFino > 0
    // Tu a sinistra, il compagno a destra e specchiato: si guardano.
    let mio = inAffondo ? OggettiSport.schermaAffondo : OggettiSport.schermaGuardia
    p.appoggia(mio, x: 52, suolo: Self.suolo,
               colori: ["C": C64.giallo, "F": C64.arancio, "O": C64.nero,
                        "M": C64.rosso, "R": C64.grigioChiaro, "L": C64.bianco])

    // Il compagno: in guardia tiene la lama alta, scoperto la abbassa. È la
    // posa a dirlo, non la tinta.
    let suo = guardia == .scoperto ? OggettiSport.schermaAffondo : OggettiSport.schermaGuardia
    p.appoggia(suo.specchiato, x: 190, suolo: Self.suolo,
               colori: ["C": C64.marrone, "F": C64.arancio, "O": C64.nero,
                        "M": C64.verdeChiaro, "R": C64.grigioChiaro, "L": C64.bianco])

    // Il varco: due parentesi che si aprono sul petto del compagno quando è
    // scoperto, con il bersaglio in mezzo. Sono forme che compaiono.
    if guardia == .scoperto {
      p.rettangolo(184, Self.suolo - 30, 5, 24, C64.giallo)
      p.rettangolo(184, Self.suolo - 30, 14, 5, C64.giallo)
      p.rettangolo(184, Self.suolo - 11, 14, 5, C64.giallo)
      p.rettangolo(228, Self.suolo - 30, 5, 24, C64.giallo)
      p.rettangolo(219, Self.suolo - 30, 14, 5, C64.giallo)
      p.rettangolo(219, Self.suolo - 11, 14, 5, C64.giallo)
      p.rettangolo(200, Self.suolo - 24, 16, 12, C64.rosso)
      p.rettangolo(204, Self.suolo - 20, 8, 4, C64.bianco)
    } else {
      // In guardia il petto è coperto da uno scudo pieno: nessun varco.
      p.rettangolo(192, Self.suolo - 28, 34, 20, C64.grigio)
      p.rettangolo(192, Self.suolo - 28, 34, 4, C64.grigioChiaro)
    }

    // Le stoccate segnate, in tacche.
    for i in 0..<Self.stoccatePerAssalto {
      p.rettangolo(12 + Double(i) * 16, SchermoRetro.altezza - 16, 12, 8,
                   i < stoccate ? C64.giallo : C64.grigio)
    }

    if fase == .fine { Sfondi.coriandoli(p, battiti: battiti, fermo: fermo) }
  }

  // MARK: - Le regole

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; stoccate = 0; assalti = 0; cambiaGuardia(); fase = .gioco
    case .gioco:
      if guardia == .scoperto {
        stoccata()
      } else if fermo {
        // Senza movimento niente cambia da solo: il primo tocco muove la
        // guardia, il secondo affonda. Diventa un gioco a turni, e il tempo lo
        // decide chi gioca.
        cambiaGuardia()
      } else {
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
        // Parata: la guardia si richiude e si riprova. Nessuna stoccata tolta.
        guardia = .alta
        restaCosi = durata()
      }
    case .assaltoFatto:
      if assalti >= 3 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        stoccate = 0; cambiaGuardia(); fase = .gioco
      }
    case .fine:
      assalti = 0; punti = 0; stoccate = 0; fase = .titolo
    }
  }

  private func stoccata() {
    affondoFino = 12
    stoccate += 1
    punti += 150
    mostra(.punti(150))
    d.andataBene()
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
    guardia = .alta
    restaCosi = durata()
    if stoccate >= Self.stoccatePerAssalto {
      assalti += 1
      punti += 1000
      fase = .assaltoFatto
    }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    if affondoFino > 0 { affondoFino -= 1 }
    guard !fermo, fase == .gioco else { return }
    restaCosi -= 1
    if restaCosi <= 0 { cambiaGuardia() }
  }

  /// La guardia cambia a caso, ma il varco non arriva mai a sorpresa: prima
  /// passa sempre da alta o bassa, e resta scoperta abbastanza da poterci
  /// arrivare anche senza riflessi pronti.
  private func cambiaGuardia() {
    switch guardia {
    case .scoperto:
      guardia = Sorte.moneta() ? .alta : .bassa
    case .alta, .bassa:
      guardia = Sorte.moneta(0.55) ? .scoperto : (guardia == .alta ? .bassa : .alta)
    }
    restaCosi = durata()
  }

  /// Quanto dura uno stato, in battiti da trenta al secondo. Lo scoperto dura
  /// sempre almeno mezzo secondo abbondante, anche al passo più svelto.
  private func durata() -> Int {
    if guardia == .scoperto {
      return max(18, Int(48 / d.velocita) + Sorte.fra(0, 8))
    }
    return max(14, Int(40 / d.velocita) + Sorte.fra(0, 20))
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  private enum Fase: Equatable { case titolo, gioco, assaltoFatto, fine }

  private enum Guardia: Equatable {
    case alta, bassa, scoperto

    /// Come si legge nella riga sotto il titolo. È l'informazione che non può
    /// mancare a nessuno, quindi sta scritta a parole vere, non affidata a una
    /// tinta o a una figura da interpretare.
    var scritta: String {
      switch self {
      case .alta: "GUARDIA ALTA · ASPETTA"
      case .bassa: "GUARDIA BASSA · ASPETTA"
      case .scoperto: "SCOPERTO · AFFONDA"
      }
    }

    var detto: String {
      switch self {
      case .alta: "in guardia alta"
      case .bassa: "in guardia bassa"
      case .scoperto: "scoperto"
      }
    }
  }
}
