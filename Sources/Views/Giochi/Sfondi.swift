import SwiftUI

/// Gli sfondi comuni a tutti i giochi.
///
/// Sono deliberatamente poveri di dettagli: quello che si muove deve staccarsi
/// dal fondo al primo sguardo. Su uno sfondo affollato la figura che conta si
/// perde, e chi fatica a leggere fatica anche a cercare.
enum Sfondi {
  /// Il cielo notturno con le stelle. Le stelle stanno sempre nello stesso
  /// posto — sono calcolate, non estratte a sorte a ogni fotogramma — così non
  /// tremolano davanti agli occhi.
  static func cielo(_ p: Pennello) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.bluScuro)
    // Le posizioni sono calcolate da due passi primi diversi: sparse davvero,
    // non allineate in diagonale come succede con un passo solo.
    for i in 0..<30 {
      let x = Double((i &* 97 &+ (i &* i &* 13)) % 314)
      let y = Double((i &* 43 &+ (i &* i &* 7)) % 150)
      p.rettangolo(x, y, 2, 2, i % 4 == 0 ? C64.bianco : C64.grigio)
    }
  }

  /// Il fondo di una grotta: pietra scura, senza stelle.
  static func roccia(_ p: Pennello) {
    p.rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza, C64.nero)
    for i in 0..<44 {
      let x = Double((i &* 89 &+ (i &* i &* 11)) % 312)
      let y = Double((i &* 47 &+ (i &* i &* 5)) % 168)
      p.rettangolo(x, y, 4, 3, C64.marrone.opacity(0.55))
    }
  }

  /// Una trave su cui si corre: bordo chiaro e mattoni, come le piattaforme
  /// dei giochi da sala.
  static func trave(_ p: Pennello, y: Double) {
    p.rettangolo(0, y, SchermoRetro.larghezza, 8, C64.marrone)
    p.rettangolo(0, y, SchermoRetro.larghezza, 2, C64.arancio)
    for x in stride(from: 0.0, to: SchermoRetro.larghezza, by: 16) {
      p.rettangolo(x, y + 3, 2, 5, C64.nero.opacity(0.5))
    }
  }

  /// La scala che porta alla trave di sopra.
  static func scala(_ p: Pennello, da: Double, a: Double) {
    let x = SchermoRetro.larghezza - 34
    p.rettangolo(x, a, 4, da - a + 8, C64.grigioChiaro)
    p.rettangolo(x + 16, a, 4, da - a + 8, C64.grigioChiaro)
    for y in stride(from: a + 4, to: da + 6, by: 8) {
      p.rettangolo(x, y, 20, 2, C64.bianco)
    }
  }

  /// I coriandoli della festa finale. Con il movimento spento restano fermi in
  /// aria: la festa si vede lo stesso, semplicemente non si agita.
  static func coriandoli(_ p: Pennello, battiti: Int, fermo: Bool) {
    let colori = [C64.giallo, C64.ciano, C64.verdeChiaro, C64.rosso, C64.viola, C64.bianco]
    for i in 0..<34 {
      let x = Double((i &* 47) % 312)
      let base = Double((i &* 29) % 150)
      let y = fermo ? base : (base + Double(battiti % 90) * 1.6).truncatingRemainder(dividingBy: 170)
      p.rettangolo(x, y, 4, 4, colori[i % colori.count])
    }
  }
}

/// Le cose da scavalcare nella *Corsa*, una per tappa.
///
/// O = il corpo dell'ostacolo (prende il colore della tappa), B = il riflesso
/// chiaro che gli dà volume. Sono tutte alte al massimo dieci pixel: si devono
/// poter saltare, e si deve *vedere* che si possono saltare.
enum OggettiCorsa {
  static let onda = SpritePixel(righe: [
    "..BBB...BB..",
    ".BOOOB.BOOB.",
    "BOOOOOBOOOOB",
    "OOOOOOOOOOOO",
    "OOOOOOOOOOOO",
  ])

  static let ondaAlta = SpritePixel(righe: [
    "...BB.......",
    "..BOOB..BB..",
    ".BOOOOB.BOB.",
    "BOOOOOOBOOOB",
    "OOOOOOOOOOOO",
    "OOOOOOOOOOOO",
  ])

  static let salvagente = SpritePixel(righe: [
    "..BBBB..",
    ".BOOOOB.",
    "BOO..OOB",
    "BO....OB",
    "BOO..OOB",
    ".BOOOOB.",
    "..BBBB..",
  ])

  static let ostacolo = SpritePixel(righe: [
    "BBBBBBBB",
    "OOOOOOOO",
    "O......O",
    "O......O",
    "OOOOOOOO",
    ".O....O.",
    ".O....O.",
  ])

  static let panca = SpritePixel(righe: [
    "BBBBBBBBBB",
    "OOOOOOOOOO",
    ".O......O.",
    ".O......O.",
    ".O......O.",
  ])

  static let palla = SpritePixel(righe: [
    ".BBBB.",
    "BOOOOB",
    "OOOOOO",
    "OOOOOO",
    "BOOOOB",
    ".BBBB.",
  ])

  static let masso = SpritePixel(righe: [
    "..BBBB..",
    ".BOOOOB.",
    "BOOOOOOB",
    "OOOOOOOO",
    "OOOOOOOO",
    ".OOOOOO.",
  ])

  static let massoAlto = SpritePixel(righe: [
    "..BB..",
    ".BOOB.",
    "BOOOOB",
    "OOOOOO",
    "OOOOOO",
    "OOOOOO",
    ".OOOO.",
  ])

  static let nota = SpritePixel(righe: [
    "...BBB",
    "...OOO",
    "...O..",
    "...O..",
    "...O..",
    "BOOO..",
    "OOOO..",
    ".OO...",
  ])

  static let notaDoppia = SpritePixel(righe: [
    "..BBBBBB",
    "..OOOOOO",
    "..O....O",
    "..O....O",
    "BOO..BOO",
    "OOO..OOO",
    ".O....O.",
  ])

  /// La gemma: grande abbastanza da vedersi, con la sfaccettatura chiara che
  /// la fa sembrare un cristallo e non un puntino.
  static let gemma = SpritePixel(righe: [
    "..LLLL..",
    ".LLGGLL.",
    "LLGGGGGL",
    "LGGGGGGL",
    "LGGGGGGL",
    ".LGGGGL.",
    "..LGGL..",
    "...LL...",
  ])
}
