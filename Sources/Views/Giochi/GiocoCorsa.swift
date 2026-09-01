import SwiftUI

/// **La corsa** — quattro tappe del Fight Camp, disegnate come un campo
/// sportivo che sale insieme alla squadra.
///
/// Le tappe sono quelle vere del Fight Camp — la piscina, la palestra, la
/// parete, il ballo dell'ultima sera — e a ogni tappa superata un compagno
/// resta lì a fare il tifo. Non si accumulano punti: si accumulano compagni.
///
/// Un tasto solo, nessun tempo che scade, **non si può perdere**: l'ostacolo
/// che ti prende non toglie niente, esce «ANCORA» e si continua da dove si era.
struct GiocoCorsa: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var onClose: () -> Void
  var perFotografia = false

  @State private var d: Difficolta
  @State private var fase: FaseGioco = .titolo
  @State private var livello = 0
  @State private var punti = 0
  @State private var squadra = 0
  @State private var xEroe = Corsa.partenza
  @State private var ostacoli: [Ostacolo] = []
  @State private var gemme: [Gemma] = []
  @State private var salto: Double?
  @State private var salita: Double = 0
  @State private var lampo: LampoRetro?
  @State private var lampoFino = 0
  @State private var battiti = 0
  @State private var prossimo = 40
  @StateObject private var suoni = Suoni()

  init(a11y: EffettiveImpostazioniAccessibilita, difficolta: Difficolta,
       onClose: @escaping () -> Void, perFotografia: Bool = false) {
    self.a11y = a11y
    self.onClose = onClose
    self.perFotografia = perFotografia
    _d = State(initialValue: difficolta)
    if perFotografia {
      _fase = State(initialValue: .gioco)
      _livello = State(initialValue: 1)
      _punti = State(initialValue: 1300)
      _squadra = State(initialValue: 1)
      _xEroe = State(initialValue: 120)
      _ostacoli = State(initialValue: [Ostacolo(x: 186, tipo: 1), Ostacolo(x: 268, tipo: 1)])
      _gemme = State(initialValue: [Gemma(x: 226)])
    }
  }

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }
  private var tappa: TappaCorsa { TappaCorsa.tutte[min(livello, 3)] }

  var body: some View {
    CorniceSport(
      a11y: a11y, titolo: "La Corsa",
      sottotitolo: fase == .titolo ? "La staffetta del Fight Camp"
        : "Tappa \(livello + 1) di 4 · \(tappa.nome)",
      punti: punti, statoDestra: "\(squadra) di 4",
      frase: frase, invito: invito, etichettaVoce: etichettaVoce,
      lampo: lampo, azioneAttiva: fase != .salita,
      onPremi: premi, onBattito: battito, onClose: onClose,
      campo: campoArena, perFotografia: perFotografia)
  }

  // MARK: - Le parole

  private var frase: String {
    switch fase {
    case .titolo:
      "Quattro tappe del camp. A ogni tappa qualcuno resta a fare il tifo per te: qui non si è mai da soli. Un tasto solo, nessuna fretta, non si può perdere."
    case .gioco, .salita: tappa.gesto
    case .tappaFatta: tappa.compagno
    case .fine: "«Now walk it by yourself» — adesso camminaci da solo. E ci sei riuscito, con tutta la tua squadra a guardarti. Non era «non so farlo». Era «non so ANCORA farlo»."
    }
  }

  private var invito: String {
    switch fase {
    case .titolo: "Gioca"
    case .gioco: fermo ? "Salta e avanza" : "Salta"
    case .salita: "Stai salendo"
    case .tappaFatta: "Continua"
    case .fine: "Rigioca"
    }
  }

  private var etichettaVoce: String {
    switch fase {
    case .titolo: return "La corsa del Fight Camp. Quattro tappe, un tasto solo, non si può perdere. Premi per giocare."
    case .gioco:
      let vicino = ostacoli.contains { abs($0.x - xEroe) < 50 }
      return "Tappa \(livello + 1), \(tappa.nome). "
        + (vicino ? "\(tappa.ostacolo) sta arrivando: premi per saltare." : "La strada è libera.")
    case .salita: return "Sali alla tappa successiva."
    case .tappaFatta: return "Tappa superata. \(tappa.compagno) Premi per continuare."
    case .fine: return "Sei arrivato in fondo con tutta la tua squadra. Premi per rigiocare."
    }
  }

  // MARK: - Il disegno

  private var campoArena: some View {
    CampoCorsa3D(a11y: a11y, stato: statoCampo, perFotografia: perFotografia)
  }

  private var statoCampo: StatoCampoCorsa3D {
    let faseCampo: StatoCampoCorsa3D.Fase
    switch fase {
    case .titolo: faseCampo = .titolo
    case .gioco: faseCampo = .gioco
    case .salita: faseCampo = .salita
    case .tappaFatta: faseCampo = .tappaFatta
    case .fine: faseCampo = .fine
    }
    return StatoCampoCorsa3D(
      fase: faseCampo,
      livello: livello,
      xEroe: xEroe,
      squadra: squadra,
      salto: altezzaSalto,
      salita: salita,
      ostacoli: ostacoli.map { .init(x: $0.x, tipo: $0.tipo) },
      gemme: gemme.filter { !$0.presa }.map(\.x),
      battiti: battiti,
      fermo: fermo)
  }

  // MARK: - Le regole

  private var altezzaSalto: Double {
    guard let salto else { return 0 }
    return sin(salto * .pi) * 26
  }

  /// La finestra è larga apposta: non è una prova di riflessi, è un invito a
  /// premere. Chi preme troppo presto è ancora in aria quando l'onda arriva.
  private var inAria: Bool {
    guard let salto else { return false }
    return salto > 0.10 && salto < 0.90
  }

  private func premi() {
    switch fase {
    case .titolo:
      punti = 0; squadra = 0; livello = 0
      preparaTappa(); fase = .gioco
    case .gioco:
      if fermo { passoAvanti() } else if salto == nil { salto = 0 }
    case .salita: break
    case .tappaFatta:
      if livello + 1 >= 4 {
        fase = .fine
        suoni.suona(.fine, a11y: a11y.perIlMotore)
      } else {
        livello += 1; preparaTappa(); fase = .gioco
      }
    case .fine:
      livello = 0; squadra = 0; punti = 0; preparaTappa(); fase = .titolo
    }
  }

  /// Il gioco a turni, per chi ha spento il movimento: ogni pressione è un
  /// salto che va a segno e un passo avanti. Nessun tempo, nessuna mira,
  /// nessuna coincidenza da azzeccare — e la stessa storia identica.
  private func passoAvanti() {
    xEroe = min(Corsa.traguardo, xEroe + 27)
    let superati = ostacoli.filter { $0.x <= xEroe + 20 }
    if !superati.isEmpty {
      punti += 100 * superati.count
      mostra(.punti(100 * superati.count))
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
    }
    ostacoli.removeAll { $0.x <= xEroe + 20 }
    raccogliGemme()
    if xEroe >= Corsa.traguardo { finisciTappa() }
  }

  private func battito() {
    battiti &+= 1
    if lampoFino > 0 { lampoFino -= 1; if lampoFino == 0 { lampo = nil } }
    guard !fermo else { return }
    switch fase {
    case .gioco: avanza()
    case .salita:
      salita = min(1, salita + 1.0 / 24.0)
      if salita >= 1 { finisciTappa() }
    default: break
    }
  }

  private func avanza() {
    if let s = salto {
      let avanti = s + 1.0 / 18.0
      salto = avanti >= 1 ? nil : avanti
    }

    xEroe = min(Corsa.traguardo, xEroe + 1.1)
    for i in ostacoli.indices { ostacoli[i].x -= 1.6 * d.velocita }
    ostacoli.removeAll { $0.x < -24 }

    // Il caso decide quando arriva il prossimo, ma l'ultimo pezzo di strada
    // resta sempre sgombro: a un livello inventato dal caso non è permesso
    // nascere impossibile.
    prossimo -= 1
    if prossimo <= 0 && xEroe < Corsa.traguardo - 80 {
      ostacoli.append(Ostacolo(x: SchermoRetro.larghezza + 12, tipo: Sorte.fra(0, 2)))
      prossimo = Int(Double(Sorte.fra(38, 78)) / max(0.5, d.densita))
    }

    for i in ostacoli.indices where !ostacoli[i].risolto {
      guard abs(ostacoli[i].x - xEroe) < 14 else { continue }
      ostacoli[i].risolto = true
      if inAria {
        punti += 100
        mostra(.punti(100))
        d.andataBene()
        suoni.suona(.giusta, a11y: a11y.perIlMotore)
      } else {
        // Ti ha preso: non si perde una vita, non si torna indietro di un
        // passo, non si ricomincia. L'ostacolo se ne va e si continua.
        ostacoli[i].x = -200
        mostra(.ancora)
        d.andataMale()
        suoni.suona(.ancora, a11y: a11y.perIlMotore)
      }
    }

    raccogliGemme()

    if xEroe >= Corsa.traguardo {
      ostacoli = []
      if livello < 3 { salita = 0; fase = .salita } else { finisciTappa() }
    }
  }

  /// Le gemme stanno in alto: si prendono solo saltando, e valgono di più.
  /// Sono il motivo per cui vale la pena saltare anche quando la strada è
  /// libera — un premio per chi ci prende gusto, mai un obbligo.
  private func raccogliGemme() {
    for i in gemme.indices where !gemme[i].presa {
      guard abs(gemme[i].x - xEroe) < 16, fermo || altezzaSalto > 10 else { continue }
      gemme[i].presa = true
      punti += 250
      mostra(.punti(250))
      suoni.suona(.giusta, a11y: a11y.perIlMotore)
    }
  }

  private func finisciTappa() {
    squadra = min(4, squadra + 1)
    punti += 1000
    fase = .tappaFatta
    suoni.suona(.giusta, a11y: a11y.perIlMotore)
  }

  private func preparaTappa() {
    xEroe = Corsa.partenza
    salto = nil; salita = 0; lampo = nil; lampoFino = 0
    prossimo = 30
    // Ogni tappa è disegnata dal caso: dove stanno gli ostacoli, quanti sono,
    // dove sono appese le gemme. È il motivo per cui si rigioca.
    ostacoli = fermo
      ? stride(from: 64.0, to: 250.0, by: 54).map { Ostacolo(x: $0, tipo: Sorte.fra(0, 2)) }
      : []
    gemme = (0..<Sorte.fra(1, 3)).map { _ in Gemma(x: Sorte.fra(80, 250)) }
  }

  private func mostra(_ l: LampoRetro) {
    lampo = l
    lampoFino = 24
  }

  // MARK: - I pezzi

  private enum FaseGioco: Equatable { case titolo, gioco, salita, tappaFatta, fine }

  private struct Ostacolo {
    var x: Double
    var tipo: Int
    var risolto = false
  }

  private struct Gemma {
    var x: Double
    var presa = false
  }
}

/// Le misure del campo della corsa.
enum Corsa {
  static let partenza: Double = 14
  static let traguardo: Double = 280
  /// L'altezza della trave di una tappa. Si sale: la prima è in basso.
  static func pavimento(_ livello: Int) -> Double { 184 - Double(livello) * 42 }
}

/// Le tappe del camp, nell'ordine in cui si vivono davvero: prima l'acqua, dove
/// anche chi fatica a stare in piedi si muove libero; poi la palestra e la
/// parete; infine il ballo dell'ultima sera.
struct TappaCorsa {
  let nome: String
  let gesto: String
  let ostacolo: String
  let compagno: String

  static let tutte: [TappaCorsa] = [
    TappaCorsa(nome: "La piscina",
               gesto: "Salta l'onda e nuota.",
               ostacolo: "L'onda",
               compagno: "Adesso nuota accanto a te un compagno."),
    TappaCorsa(nome: "La palestra",
               gesto: "Salta l'ostacolo.",
               ostacolo: "L'ostacolo",
               compagno: "Un altro compagno salta insieme a te."),
    TappaCorsa(nome: "La parete",
               gesto: "Scavalca il masso e sali.",
               ostacolo: "Il masso",
               compagno: "Un altro compagno sale con te."),
    TappaCorsa(nome: "Il ballo dell'ultima sera",
               gesto: "Vai a tempo con la musica.",
               ostacolo: "La musica",
               compagno: "Ci sono tutti, e ti guardano."),
  ]
}
