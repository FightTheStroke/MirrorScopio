import SceneKit
import SwiftUI

struct StatoCampoCorsa3D: Equatable {
  enum Fase: Equatable { case titolo, gioco, salita, tappaFatta, fine }
  struct Ostacolo: Equatable { var x: Double; var tipo: Int }

  var fase: Fase
  var livello: Int
  var xEroe: Double
  var squadra: Int
  var salto: Double
  var salita: Double
  var ostacoli: [Ostacolo]
  var gemme: [Double]
  var battiti: Int
  var fermo: Bool

  static func == (lhs: StatoCampoCorsa3D, rhs: StatoCampoCorsa3D) -> Bool {
    lhs.fase == rhs.fase
      && lhs.livello == rhs.livello
      && lhs.xEroe == rhs.xEroe
      && lhs.squadra == rhs.squadra
      && lhs.salto == rhs.salto
      && lhs.salita == rhs.salita
      && lhs.ostacoli == rhs.ostacoli
      && lhs.gemme == rhs.gemme
      && lhs.fermo == rhs.fermo
      && ((lhs.fermo && rhs.fermo) || lhs.battiti == rhs.battiti)
  }
}

struct CampoCorsa3D: View {
  @Environment(\.palette) private var palette

  var a11y: EffettiveImpostazioniAccessibilita
  var stato: StatoCampoCorsa3D
  var perFotografia: Bool

  var body: some View {
    let colori = PaletteArena.resolve(
      theme: a11y.theme, palette: palette, vision: a11y.colorVision)
    if perFotografia {
      Image(nsImage: ScenaCorsa3D.fotografia(
        stato: stato, colori: colori, dimensione: CGSize(width: 1600, height: 1000)))
        .resizable()
        .interpolation(.high)
    } else {
      VistaCorsaSceneKit(stato: stato, colori: colori,
                         chiaveTema: "\(a11y.theme.rawValue)-\(a11y.colorVision.rawValue)-\(palette.isDark)")
    }
  }
}

enum PoliticaAggiornamentoScena3D {
  static func ricostruisce(mondoPresente: Bool, chiaveAttuale: String,
                           chiaveNuova: String) -> Bool {
    !mondoPresente || chiaveAttuale != chiaveNuova
  }

  static func ridisegna(ultimo: StatoCampoCorsa3D?,
                        nuovo: StatoCampoCorsa3D) -> Bool {
    ultimo != nuovo
  }
}

private struct VistaCorsaSceneKit: NSViewRepresentable {
  var stato: StatoCampoCorsa3D
  var colori: PaletteArena
  var chiaveTema: String

  func makeCoordinator() -> Coordinatore {
    Coordinatore()
  }

  func makeNSView(context: Context) -> SCNView {
    let vista = SCNView()
    vista.antialiasingMode = .multisampling2X
    vista.autoenablesDefaultLighting = false
    vista.allowsCameraControl = false
    vista.preferredFramesPerSecond = 30
    vista.rendersContinuously = false
    vista.backgroundColor = .clear
    context.coordinator.aggiorna(vista, stato: stato, colori: colori,
                                 chiaveTema: chiaveTema)
    return vista
  }

  func updateNSView(_ vista: SCNView, context: Context) {
    context.coordinator.aggiorna(vista, stato: stato, colori: colori,
                                 chiaveTema: chiaveTema)
  }

  @MainActor
  final class Coordinatore {
    private var mondo: ScenaCorsa3D?
    private var chiave = ""
    private var ultimoStato: StatoCampoCorsa3D?

    func aggiorna(_ vista: SCNView, stato: StatoCampoCorsa3D,
                  colori: PaletteArena, chiaveTema: String) {
      if PoliticaAggiornamentoScena3D.ricostruisce(
        mondoPresente: mondo != nil, chiaveAttuale: chiave, chiaveNuova: chiaveTema) {
        let nuovo = ScenaCorsa3D(colori: colori)
        mondo = nuovo
        chiave = chiaveTema
        ultimoStato = nil
        vista.scene = nuovo.scena
        vista.pointOfView = nuovo.camera
      }
      if PoliticaAggiornamentoScena3D.ridisegna(ultimo: ultimoStato, nuovo: stato) {
        mondo?.aggiorna(stato)
        ultimoStato = stato
        vista.setNeedsDisplay(vista.bounds)
      }
    }
  }
}
