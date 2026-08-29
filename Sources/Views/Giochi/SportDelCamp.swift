import SwiftUI

/// Le cose che si vedono negli sport del Fight Camp: prese, fioretti, vele,
/// tricicli, tavole, palloni, guantoni.
///
/// Sono disegnate qui una volta sola perché i sette giochi degli sport
/// condividono lo stesso mondo. Ogni figura è larga abbastanza da riconoscersi
/// da lontano e ha una forma sua: chi non distingue due tinte vicine deve
/// comunque capire al volo che cos'è, e per questo nessuna di queste figure
/// dipende dal colore per essere letta.
enum OggettiSport {

  // MARK: - L'arrampicata

  /// La presa della parete: uno scoglio con un incavo dove entra la mano.
  static let presa = SpritePixel(righe: [
    ".PPPPP.",
    "PPPIIPP",
    "PPIIIPP",
    "PPPIPPP",
    ".PPPPP.",
  ])

  /// La mano che cerca la presa: aperta, con le dita in fuori.
  static let mano = SpritePixel(righe: [
    "D.D.D.D",
    "DDDDDDD",
    "DDDDDDD",
    ".DDDDD.",
    "..DDD..",
  ])

  // MARK: - La scherma

  /// Lo schermidore in carrozzina, di profilo, con il fioretto abbassato.
  /// C capelli · F faccia · O occhio · M maglia · R ruota · L lama
  static let schermaGuardia = SpritePixel(righe: [
    "..........L.......",
    ".........L........",
    "......CCCCL.......",
    ".....CFFFFC.......",
    ".....FOFFFF.......",
    ".....FFFFFF.......",
    "....MMMMMMM.......",
    "...MMMMMMMMM......",
    "..MMMMMMMMMMM.....",
    "..MMMMMMMMM.......",
    "...MMMMMM.........",
    "...MMMMMM.........",
    "...RRRRRR.........",
    "..R..RR..R..RRR...",
    ".R..R..R..R.R.R...",
    ".R.R....R.R.RRR...",
    "..R..RR..R........",
    "...RRRRRR.........",
  ])

  /// Lo stesso, in affondo: il braccio si allunga e la lama va avanti.
  static let schermaAffondo = SpritePixel(righe: [
    "..................",
    "..................",
    "......CCCC........",
    ".....CFFFFC.......",
    ".....FOFFFF.......",
    ".....FFFFFF.......",
    "....MMMMMMM.......",
    "...MMMMMMMMMMMMM..",
    "..MMMMMMMMMLLLLLLL",
    "..MMMMMMMMM.......",
    "...MMMMMM.........",
    "...MMMMMM.........",
    "...RRRRRR.........",
    "..R..RR..R..RRR...",
    ".R..R..R..R.R.R...",
    ".R.R....R.R.RRR...",
    "..R..RR..R........",
    "...RRRRRR.........",
  ])

  // MARK: - La vela

  /// Il brigantino visto di lato, con lo scafo e l'albero.
  static let scafo = SpritePixel(righe: [
    "....A.....",
    "....A.....",
    "....A.....",
    "SSSSASSSSS",
    "SSSSSSSSSS",
    ".SSSSSSSS.",
    "..SSSSSS..",
  ])

  // MARK: - Il triciclo

  /// Il triciclo Ormesa di profilo, con chi ci sta sopra.
  /// C capelli · F faccia · O occhio · M maglia · T telaio · R ruota
  static let triciclo = SpritePixel(righe: [
    ".......CCCC.......",
    "......CFFFFC......",
    "......FOFFFF......",
    "......FFFFFF......",
    ".....MMMMMMM......",
    "....MMMMMMMMMMH...",
    "....MMMMMMM...H...",
    "....TTTTTTT...T...",
    "..TTTTTTTTTTTTT...",
    ".TT..........TT...",
    "RRRR.......RRRR...",
    "RRRR.......RRRR...",
    ".RR.........RR....",
  ])

  /// La bandierina lungo la strada: si prende passandoci sopra con abbastanza
  /// spinta, e allora sventola.
  static let bandierina = SpritePixel(righe: [
    "BBBBB.",
    "BBBBB.",
    "BBBB..",
    "A.....",
    "A.....",
    "A.....",
  ])

  // MARK: - Lo skateboard

  /// La tavola vista di lato.
  static let tavola = SpritePixel(righe: [
    ".TTTTTTTTTT.",
    "TTTTTTTTTTTT",
    "..R......R..",
    ".RRR....RRR.",
    "..R......R..",
  ])

  // MARK: - Il beach volley

  /// Il pallone da beach volley: a spicchi, così si vede che gira.
  static let pallone = SpritePixel(righe: [
    "..PPPP..",
    ".PPBBPP.",
    "PPBPPBPP",
    "PBPPPPBP",
    "PBPPPPBP",
    "PPBPPBPP",
    ".PPBBPP.",
    "..PPPP..",
  ])

  /// L'ombra sulla sabbia: dice dove cadrà il pallone prima che ci arrivi.
  static let ombra = SpritePixel(righe: [
    "..OOOO..",
    ".OO..OO.",
    "OO....OO",
    ".OO..OO.",
    "..OOOO..",
  ])

  // MARK: - L'hip hop

  /// Il passo della coreografia: un'impronta. Grande abbastanza da vedersi
  /// mentre scorre, e riconoscibile per la forma anche di sfuggita.
  static let passo = SpritePixel(righe: [
    ".PPPP.",
    "PPPPPP",
    "PPPPPP",
    "PPPPPP",
    ".PPPP.",
    "..PPP.",
    "..PPP.",
    ".PPPP.",
    "PPPPPP",
    ".PPPP.",
  ])

  /// Il passo doppio: due impronte insieme, vale di più. La differenza si vede
  /// nella forma, non nel colore.
  static let passoDoppio = SpritePixel(righe: [
    ".PPPP..PPPP.",
    "PPPPPPPPPPPP",
    "PPPPPPPPPPPP",
    "PPPPPPPPPPPP",
    ".PPPP..PPPP.",
    "..PPP..PPP..",
    "..PPP..PPP..",
    ".PPPP..PPPP.",
    "PPPPPPPPPPPP",
    ".PPPP..PPPP.",
  ])

  // MARK: - La boxe

  /// Il colpitore del maestro: il cuscino tondo su cui si tira il diretto.
  static let colpitore = SpritePixel(righe: [
    ".CCCCCC.",
    "CCCCCCCC",
    "CCCMMCCC",
    "CCCMMCCC",
    "CCCCCCCC",
    ".CCCCCC.",
    "..GGGG..",
  ])

  /// Il maestro che tiene i colpitori, di fronte.
  static let maestro = SpritePixel(righe: [
    "...HHHH...",
    "..HFFFFH..",
    "..FOFFOF..",
    "..FFFFFF..",
    ".MMMMMMMM.",
    "MMMMMMMMMM",
    "MMMMMMMMMM",
    "..MMMMMM..",
    "..GG..GG..",
    "..GG..GG..",
    ".SSS..SSS.",
  ])

  /// Chi tira: di profilo, guardia alta, un braccio pronto.
  static let pugileGuardia = SpritePixel(righe: [
    "..HHHH....",
    ".HFFFFH...",
    ".FFFOFF...",
    ".FFFFFF...",
    "GGMMMMM...",
    "GGMMMMMM..",
    "GGMMMMM...",
    "..MMMMM...",
    "..GG.GG...",
    "..GG..GG..",
    ".SSS..SSS.",
  ])

  /// Lo stesso nell'istante del diretto: il braccio parte.
  static let pugileDiretto = SpritePixel(righe: [
    "..HHHH....",
    ".HFFFFH...",
    ".FFFOFF...",
    ".FFFFFF...",
    ".MMMMMMGG.",
    ".MMMMMMMGG",
    ".MMMMMMGG.",
    "..MMMMM...",
    "..GG.GG...",
    "..GG..GG..",
    ".SSS..SSS.",
  ])
}

/// Gli sfondi degli sport: la parete, la pedana, il mare, la strada, la
/// spiaggia, la palestra. Sono fondali sobri di proposito — quello che conta
/// sta davanti, e uno sfondo affollato lo nasconderebbe.
enum SfondiSport {

  /// Il cielo con il sole e qualche nuvola. Serve a non lasciare mezzo schermo
  /// vuoto: uno sfondo piatto fa sembrare che manchi qualcosa, e a chi guarda
  /// da lontano toglie i riferimenti per capire dove finisce il campo.
  static func cieloAperto(_ p: Pennello, orizzonte: Double) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, orizzonte, C64.ciano.opacity(0.30))
    p.rettangolo(262, 14, 24, 24, C64.giallo)
    p.rettangolo(258, 18, 32, 16, C64.giallo)
    for (x, y, largo) in [(24.0, 26.0, 40.0), (120.0, 16.0, 52.0), (188.0, 44.0, 34.0)] {
      guard y + 14 < orizzonte else { continue }
      p.rettangolo(x, y, largo, 8, C64.bianco.opacity(0.75))
      p.rettangolo(x + 8, y - 6, largo - 20, 8, C64.bianco.opacity(0.75))
      p.rettangolo(x + 4, y + 6, largo - 8, 5, C64.bianco.opacity(0.55))
    }
  }

  /// La parete d'arrampicata: pannelli grigi con la venatura, come quella vera
  /// del Politecnico usata al camp.
  static func parete(_ p: Pennello, scorrimento: Double) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.bluScuro)
    var y: Double = -40 + scorrimento.truncatingRemainder(dividingBy: 40)
    while y < SchermoRetro.altezza {
      p.rettangolo(0, y, SchermoRetro.larghezza, 2, C64.blu)
      y += 40
    }
    var x: Double = 0
    while x < SchermoRetro.larghezza {
      p.rettangolo(x, 0, 2, SchermoRetro.altezza, C64.blu)
      x += 52
    }
  }

  /// La pedana della scherma: il tappeto e la linea di mezzo.
  static func pedana(_ p: Pennello, suolo: Double) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.bluScuro)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, SchermoRetro.altezza - suolo, C64.grigio)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, 3, C64.grigioChiaro)
    p.rettangolo(SchermoRetro.larghezza / 2 - 1, suolo, 3, 12, C64.bianco)
  }

  /// Il mare aperto: cielo, orizzonte e onde che passano.
  static func mare(_ p: Pennello, orizzonte: Double, battiti: Int, fermo: Bool) {
    cieloAperto(p, orizzonte: orizzonte)
    p.rettangolo(0, orizzonte, SchermoRetro.larghezza, SchermoRetro.altezza - orizzonte, C64.blu)
    p.rettangolo(0, orizzonte, SchermoRetro.larghezza, 2, C64.bluChiaro)
    let passo = fermo ? 0.0 : Double(battiti)
    for fila in 0..<4 {
      let y = orizzonte + 12 + Double(fila) * 16
      // Ogni fila ha il suo sfasamento e la sua lunghezza: file identiche
      // formano un reticolo, e un reticolo sembra una scala, non il mare.
      let sfasa = (passo * (0.5 + Double(fila) * 0.3)).truncatingRemainder(dividingBy: 96)
      var x = -96 + sfasa + Double(fila) * 17
      while x < SchermoRetro.larghezza {
        p.rettangolo(x, y, 30 + Double(fila) * 6, 3, C64.bluChiaro)
        x += 96
      }
    }
  }

  /// La strada del triciclo: asfalto, righe che scorrono, prato sopra.
  static func strada(_ p: Pennello, suolo: Double, avanzamento: Double) {
    cieloAperto(p, orizzonte: suolo)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, SchermoRetro.altezza - suolo, C64.grigio)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, 3, C64.verde)
    var x = -40 + avanzamento.truncatingRemainder(dividingBy: 40)
    while x < SchermoRetro.larghezza {
      p.rettangolo(x, suolo + 22, 22, 3, C64.grigioChiaro)
      x += 40
    }
  }

  /// La sabbia della spiaggia, con i granelli fermi al loro posto.
  static func sabbia(_ p: Pennello, suolo: Double) {
    cieloAperto(p, orizzonte: suolo)
    // Una striscia di mare in fondo: dice che è una spiaggia senza scriverlo.
    p.rettangolo(0, suolo - 26, SchermoRetro.larghezza, 26, C64.blu)
    for fila in 0..<2 {
      var x = Double(fila) * 40
      while x < SchermoRetro.larghezza {
        p.rettangolo(x, suolo - 20 + Double(fila) * 10, 22, 3, C64.bluChiaro)
        x += 84
      }
    }
    p.rettangolo(0, suolo, SchermoRetro.larghezza, SchermoRetro.altezza - suolo, C64.giallo.opacity(0.55))
    for i in 0..<70 {
      // Due moltiplicatori primi diversi più un termine al quadrato: senza,
      // i granelli si mettono in fila e si vede una diagonale che non c'è.
      let x = Double((i * 37 + i * i * 11) % 320)
      let y = suolo + 6 + Double((i * 23) % 34)
      p.rettangolo(x, y, 2, 2, C64.marrone.opacity(0.7))
    }
  }

  /// Il pavimento della palestra, con le assi del parquet.
  static func palestra(_ p: Pennello, suolo: Double) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, suolo, C64.bluScuro)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, SchermoRetro.altezza - suolo, C64.marrone)
    p.rettangolo(0, suolo, SchermoRetro.larghezza, 3, C64.arancio)
    var x: Double = 0
    while x < SchermoRetro.larghezza {
      p.rettangolo(x, suolo + 4, 2, SchermoRetro.altezza - suolo - 4, C64.marrone.opacity(0.5))
      x += 26
    }
  }
}
