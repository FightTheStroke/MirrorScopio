import AppKit
import SwiftUI
import Testing
@testable import MirrorScopio

@Suite("Colori e cornice dell'arena 3D")
@MainActor
struct AccessibilitaArena3D {
  @Test("Le figure staccano dalle superfici", arguments: combinazioniDiTemaEVista)
  func figureVisibili(tema: ThemeChoice, vista: ColorVision) {
    let arena = palette(tema, vista)
    let figure = [
      ("eroe", arena.eroe),
      ("compagno", arena.squadra),
      ("ostacolo", arena.ostacolo),
      ("premio", arena.premio),
    ]
    for (nome, colore) in figure {
      for (superficie, fondo) in [("pista", arena.pista), ("terra", arena.terra)] {
        let rapporto = contrasto(colore, fondo)
        #expect(
          rapporto >= 3,
          "\(tema.label) · \(vista.label) · \(nome) sulla \(superficie): \(String(format: "%.2f", rapporto)) a 1, serve almeno 3,00"
        )
      }
    }
    for (nome, colore) in [("eroe", arena.eroe), ("ostacolo", arena.ostacolo)] {
      for (superficie, fondo) in [
        ("cielo alto", arena.cieloAlto), ("cielo basso", arena.cieloBasso),
      ] {
        let rapporto = contrasto(colore, fondo)
        #expect(
          rapporto >= 3,
          "\(tema.label) · \(vista.label) · \(nome) sul \(superficie): \(String(format: "%.2f", rapporto)) a 1, serve almeno 3,00"
        )
      }
    }
  }

  @Test("Il tema automatico percorre chiaro e scuro")
  func temaAutomatico() {
    for sistema in [ColorScheme.light, .dark] {
      let arena = palette(.auto, .standard, sistema: sistema)
      #expect(contrasto(arena.eroe, arena.pista) >= 3)
      #expect(contrasto(arena.ostacolo, arena.pista) >= 3)
      #expect(contrasto(arena.squadra, arena.terra) >= 3)
    }
  }

  @Test("Il modo di vedere i colori cambia le figure dell'arena")
  func modoDiVedereIColori() {
    let standard = palette(.chiaro, .standard)
    let deuteranopia = palette(.chiaro, .deuteranopia)
    #expect(componenti(standard.ostacolo) != componenti(deuteranopia.ostacolo))
    #expect(componenti(standard.squadra) != componenti(deuteranopia.squadra))
  }

  @Test("In monocromia squadra, ostacolo e pubblico non collassano nello stesso valore")
  func ruoliDistintiInMonocromia() {
    let arena = palette(.altoContrasto, .monocromia)
    #expect(contrasto(arena.squadra, arena.ostacolo) >= 1.5)
    #expect(componenti(arena.squadra) != componenti(arena.decorazione))
    #expect(componenti(arena.ostacolo) != componenti(arena.dettaglioOstacolo))
  }

  @Test("Il traguardo resta visibile sulle superfici", arguments: combinazioniDiTemaEVista)
  func traguardoVisibile(tema: ThemeChoice, vista: ColorVision) {
    let arena = palette(tema, vista)
    #expect(contrasto(arena.traguardo, arena.pista) >= 3)
    #expect(contrasto(arena.traguardo, arena.terra) >= 3)
  }

  @Test("La cornice nasconde numeri e lampi di punteggio insieme")
  func punteggioNascosto() {
    let stato = StatoCorniceSport(
      nascondePunti: true, azioneAttiva: true, lampo: .punti(100))
    #expect(!stato.mostraPunti)
    #expect(stato.testoLampo == nil)
    #expect(stato.simboloLampo == nil)
  }

  @Test("«Ancora» resta anche senza punteggio e usa la freccia")
  func ancoraAccessibile() {
    let stato = StatoCorniceSport(
      nascondePunti: true, azioneAttiva: true, lampo: .ancora)
    #expect(stato.testoLampo == "Ancora")
    #expect(stato.simboloLampo == ColorVision.wrongSymbol)
  }

  @Test("Durante la salita il comando della cornice è spento")
  func comandoSpento() {
    let stato = StatoCorniceSport(
      nascondePunti: false, azioneAttiva: false, lampo: nil)
    #expect(!stato.azioneAttiva)
    #expect(stato.mostraPunti)
  }

  private func palette(_ tema: ThemeChoice, _ vista: ColorVision,
                       sistema: ColorScheme = .light) -> PaletteArena {
    let base = Palette.resolve(theme: tema, vision: vista, system: sistema)
    return PaletteArena.resolve(theme: tema, palette: base, vision: vista)
  }

  private func componenti(_ colore: Color) -> [Int] {
    guard let c = NSColor(colore).usingColorSpace(.sRGB) else { return [] }
    return [c.redComponent, c.greenComponent, c.blueComponent]
      .map { Int(($0 * 255).rounded()) }
  }
}
