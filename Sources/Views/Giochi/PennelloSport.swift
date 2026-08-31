import SwiftUI

/// Forme vettoriali condivise dalla nuova famiglia dei giochi.
///
/// Le coordinate restano 320 × 200 per non cambiare le regole; il disegno
/// invece scala senza pixel e usa soltanto i ruoli della palette dell'app.
struct PennelloSport {
  let ctx: GraphicsContext
  let u: Double
  let palette: Palette

  var sfondoCampo: Color {
    palette.sfondoCampoSport
  }

  var segnoCampo: Color {
    palette.segnoCampoSport
  }

  var secondoPianoCampo: Color {
    palette.secondoPianoCampoSport
  }

  var accentoCampo: Color { palette.accent }
  var sopraAccento: Color { palette.onAccent }

  func sfondo() {
    rettangolo(0, 0, SchermoRetro.larghezza, SchermoRetro.altezza,
               raggio: 0, tinta: sfondoCampo)
  }

  func rettangolo(_ x: Double, _ y: Double, _ larghezza: Double, _ altezza: Double,
                  raggio: Double, tinta: Color, bordo: Color? = nil,
                  spessore: Double = 1) {
    let forma = Path(roundedRect: CGRect(x: x * u, y: y * u,
                                        width: larghezza * u, height: altezza * u),
                     cornerRadius: raggio * u)
    ctx.fill(forma, with: .color(tinta))
    if let bordo {
      ctx.stroke(forma, with: .color(bordo),
                 style: StrokeStyle(lineWidth: spessore * u, lineJoin: .round))
    }
  }

  func cerchio(_ x: Double, _ y: Double, _ diametro: Double,
               tinta: Color, bordo: Color? = nil, spessore: Double = 1) {
    let forma = Path(ellipseIn: CGRect(x: x * u, y: y * u,
                                      width: diametro * u, height: diametro * u))
    ctx.fill(forma, with: .color(tinta))
    if let bordo {
      ctx.stroke(forma, with: .color(bordo),
                 style: StrokeStyle(lineWidth: spessore * u))
    }
  }

  func linea(_ punti: [CGPoint], tinta: Color, spessore: Double,
             tratteggio: [CGFloat] = []) {
    guard let primo = punti.first else { return }
    var percorso = Path()
    percorso.move(to: CGPoint(x: primo.x * u, y: primo.y * u))
    for punto in punti.dropFirst() {
      percorso.addLine(to: CGPoint(x: punto.x * u, y: punto.y * u))
    }
    ctx.stroke(percorso, with: .color(tinta),
               style: StrokeStyle(lineWidth: spessore * u,
                                  lineCap: .round,
                                  lineJoin: .round,
                                  dash: tratteggio.map { $0 * u }))
  }

  func rombo(x: Double, y: Double, lato: Double) {
    let forma = percorsoRombo(x: x, y: y, lato: lato)
    ctx.fill(forma, with: .color(segnoCampo))
    ctx.stroke(forma, with: .color(palette.premio),
               style: StrokeStyle(lineWidth: 1.5 * u, lineJoin: .round))
    ctx.fill(percorsoRombo(x: x, y: y, lato: lato * 0.48),
             with: .color(accentoCampo))
  }

  func atleta(x: Double, suolo: Double, salto: Double, posa: Int) {
    let y = suolo - salto
    linea([CGPoint(x: x - 9, y: y + 1), CGPoint(x: x + 9, y: y + 1)],
          tinta: secondoPianoCampo, spessore: 2.5)
    cerchio(x - 5.5, y - 38, 11, tinta: accentoCampo,
            bordo: segnoCampo, spessore: 1.5)
    rettangolo(x - 6, y - 27, 12, 17, raggio: 4,
               tinta: accentoCampo, bordo: segnoCampo, spessore: 1.5)

    if posa == 0 {
      linea([CGPoint(x: x - 11, y: y - 18), CGPoint(x: x, y: y - 22),
             CGPoint(x: x + 11, y: y - 18)],
            tinta: segnoCampo, spessore: 4.5)
      linea([CGPoint(x: x - 8, y: y), CGPoint(x: x, y: y - 10),
             CGPoint(x: x + 8, y: y)],
            tinta: segnoCampo, spessore: 5)
    } else {
      linea([CGPoint(x: x - 11, y: y - 13), CGPoint(x: x, y: y - 21),
             CGPoint(x: x + 12, y: y - 25)],
            tinta: segnoCampo, spessore: 4.5)
      linea([CGPoint(x: x - 11, y: y), CGPoint(x: x, y: y - 10),
             CGPoint(x: x + 12, y: y - 4)],
            tinta: segnoCampo, spessore: 5)
    }
  }

  func compagno(x: Double, suolo: Double, guardaADestra: Bool) {
    let verso = guardaADestra ? 1.0 : -1.0
    cerchio(x - 4, suolo - 30, 8, tinta: segnoCampo,
            bordo: palette.ok, spessore: 1.5)
    rettangolo(x - 4, suolo - 21, 8, 12, raggio: 3,
               tinta: palette.ok, bordo: segnoCampo, spessore: 1)
    linea([CGPoint(x: x - 9 * verso, y: suolo - 26),
           CGPoint(x: x, y: suolo - 17),
           CGPoint(x: x + 10 * verso, y: suolo - 28)],
          tinta: segnoCampo, spessore: 3.5)
    linea([CGPoint(x: x - 6, y: suolo),
           CGPoint(x: x, y: suolo - 9),
           CGPoint(x: x + 6, y: suolo)],
          tinta: segnoCampo, spessore: 4)
  }

  private func percorsoRombo(x: Double, y: Double, lato: Double) -> Path {
    var forma = Path()
    forma.move(to: CGPoint(x: x * u, y: (y - lato / 2) * u))
    forma.addLine(to: CGPoint(x: (x + lato / 2) * u, y: y * u))
    forma.addLine(to: CGPoint(x: x * u, y: (y + lato / 2) * u))
    forma.addLine(to: CGPoint(x: (x - lato / 2) * u, y: y * u))
    forma.closeSubpath()
    return forma
  }
}
