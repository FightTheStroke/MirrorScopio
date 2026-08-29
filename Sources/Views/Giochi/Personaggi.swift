import SwiftUI

/// Le persone del Fight Camp, disegnate una volta sola.
///
/// Hanno gli occhi, e non è un vezzo: una figura con gli occhi si riconosce
/// come *qualcuno*, non come una tessera che si muove. È la differenza fra un
/// gioco in cui corri tu con i tuoi compagni e uno in cui sposti dei quadrati.
enum Personaggi {
  /// H capelli · F faccia · O occhi · M maglia · G gambe · S scarpe
  static let fermo = SpritePixel(righe: [
    "...HHHH...",
    "..HHHHHH..",
    "..HFFFFH..",
    "..FOFFOF..",
    "..FFFFFF..",
    ".MMMMMMMM.",
    "MMMMMMMMMM",
    "M.MMMMMM.M",
    "..MMMMMM..",
    "..GG..GG..",
    "..GG..GG..",
    ".SSS..SSS.",
  ])

  /// In corsa: una gamba avanti, un braccio indietro.
  static let corsa = SpritePixel(righe: [
    "...HHHH...",
    "..HHHHHH..",
    "..HFFFFH..",
    "..FOFFOF..",
    "..FFFFFF..",
    ".MMMMMMM..",
    "MMMMMMMMM.",
    "..MMMMMM.M",
    "..MMMMMM..",
    "..GG.GG...",
    ".GG...GG..",
    "SSS...SSS.",
  ])

  /// In aria: braccia larghe e gambe aperte. Si riconosce a colpo d'occhio che
  /// sta saltando anche senza guardare l'altezza, e questo conta per chi fatica
  /// a seguire un movimento veloce.
  static let salto = SpritePixel(righe: [
    "...HHHH...",
    "..HHHHHH..",
    "..HFFFFH..",
    "..FOFFOF..",
    "..FFFFFF..",
    "MMMMMMMMMM",
    "M.MMMMMM.M",
    "..MMMMMM..",
    ".GG....GG.",
    "SSS....SSS",
    "..........",
    "..........",
  ])

  /// Con le braccia in alto: fa il tifo.
  static let tifo = SpritePixel(righe: [
    "M........M",
    ".M......M.",
    "..HHHHHH..",
    "..HFFFFH..",
    "..FOFFOF..",
    "..FFFFFF..",
    ".MMMMMMMM.",
    "..MMMMMM..",
    "..MMMMMM..",
    "..GG..GG..",
    "..GG..GG..",
    ".SSS..SSS.",
  ])

  /// I colori di chi gioca. Nessuna informazione sta nel colore — ci si
  /// riconosce dalla forma e dalla posizione — così il gioco funziona identico
  /// per chi confonde certe coppie di tinte.
  static let eroe: [Character: Color] = [
    "H": C64.giallo, "F": C64.arancio, "O": C64.nero,
    "M": C64.rosso, "G": C64.ciano, "S": C64.bianco,
  ]

  /// I compagni: stessa forma, maglia diversa. Sono la squadra, non dei nemici.
  static func compagno(_ indice: Int) -> [Character: Color] {
    let maglie = [C64.verdeChiaro, C64.ciano, C64.viola, C64.giallo, C64.grigioChiaro]
    return ["H": C64.marrone, "F": C64.arancio, "O": C64.nero,
            "M": maglie[abs(indice) % maglie.count], "G": C64.bianco, "S": C64.bianco]
  }
}
