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

/// Oggetti condivisi dai giochi rimasti sul motore essenziale.
enum OggettiRetro {
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
