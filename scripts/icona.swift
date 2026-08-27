// Genera l'icona e il logo di MirrorScopio.
//
//   swift scripts/icona.swift <cartella>
//
// Il segno appartiene alla stessa famiglia di MirrorBuddy: forme piatte,
// contorno scuro spesso, sinistra a sfaccettature calde e destra blu con le
// tracce di un circuito. La differenza e il soggetto — li un cervello, qui un
// occhio, perche il tachistoscopio misura esattamente quello: quanto poco
// basta all'occhio per riconoscere una parola.
//
// La meta calda e l'occhio che guarda, la meta blu e la macchina che conta i
// millesimi. Sono lo stesso occhio, non due cose separate: e il punto
// dell'app.
//
// Vincolo che comanda su tutto il resto: a 32 pixel nel Dock deve restare
// riconoscibile. Per questo la mandorla ha un contorno spesso e la pupilla e
// grande — i dettagli del circuito spariscono, la forma no.

import AppKit

let scuro   = NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
let arancio = NSColor(srgbRed: 0.95, green: 0.42, blue: 0.13, alpha: 1)
let arancio2 = NSColor(srgbRed: 0.97, green: 0.58, blue: 0.12, alpha: 1)
let giallo  = NSColor(srgbRed: 0.99, green: 0.73, blue: 0.08, alpha: 1)
let giallo2 = NSColor(srgbRed: 0.99, green: 0.80, blue: 0.25, alpha: 1)
let azzurro = NSColor(srgbRed: 0.16, green: 0.66, blue: 0.88, alpha: 1)
let blu     = NSColor(srgbRed: 0.11, green: 0.38, blue: 0.69, alpha: 1)
let bluScuro = NSColor(srgbRed: 0.09, green: 0.31, blue: 0.60, alpha: 1)

/// La mandorla dell'occhio: due archi simmetrici.
func mandorla(_ r: CGRect) -> NSBezierPath {
  let p = NSBezierPath()
  let h = r.height * 0.62
  p.move(to: CGPoint(x: r.minX, y: r.midY))
  p.curve(to: CGPoint(x: r.maxX, y: r.midY),
          controlPoint1: CGPoint(x: r.minX + r.width * 0.26, y: r.midY + h),
          controlPoint2: CGPoint(x: r.maxX - r.width * 0.26, y: r.midY + h))
  p.curve(to: CGPoint(x: r.minX, y: r.midY),
          controlPoint1: CGPoint(x: r.maxX - r.width * 0.26, y: r.midY - h),
          controlPoint2: CGPoint(x: r.minX + r.width * 0.26, y: r.midY - h))
  p.close()
  return p
}

func spicchio(centro c: CGPoint, raggio R: CGFloat, da a1: CGFloat, a a2: CGFloat) -> NSBezierPath {
  let p = NSBezierPath()
  p.move(to: c)
  p.line(to: CGPoint(x: c.x + R * cos(a1 * .pi / 180), y: c.y + R * sin(a1 * .pi / 180)))
  p.line(to: CGPoint(x: c.x + R * cos(a2 * .pi / 180), y: c.y + R * sin(a2 * .pi / 180)))
  p.close()
  return p
}

/// - Parameter fondo: disegna il riquadro bianco dell'icona di sistema.
///   Il logo per i documenti lo vuole trasparente.
func disegna(size S: CGFloat, fondo: Bool) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext
  ctx.setAllowsAntialiasing(true)

  if fondo {
    let m = S * 0.055
    let box = CGRect(x: m, y: m, width: S - 2 * m, height: S - 2 * m)
    let corpo = NSBezierPath(roundedRect: box, xRadius: box.width * 0.2237,
                             yRadius: box.width * 0.2237)
    NSColor.white.setFill()
    corpo.fill()
  }

  // L'occhio, centrato e largo quanto la scatola lo consente.
  let w = S * (fondo ? 0.76 : 0.94)
  let occhio = CGRect(x: (S - w) / 2, y: (S - w * 0.66) / 2, width: w, height: w * 0.66)
  let forma = mandorla(occhio)
  let c = CGPoint(x: occhio.midX, y: occhio.midY)
  let R = occhio.height * 0.485       // l'iride tocca quasi le palpebre

  ctx.saveGState()
  forma.addClip()

  // Il bianco dell'occhio.
  NSColor.white.setFill()
  forma.fill()

  // Meta calda: l'occhio che guarda, a sfaccettature come in MirrorBuddy.
  // Le due meta vanno tagliate dallo stesso cerchio, altrimenti una e un
  // mosaico spigoloso e l'altra un disco liscio: l'occhio non torna.
  ctx.saveGState()
  let iride = NSBezierPath(ovalIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
  iride.addClip()
  CGRect(x: c.x - R, y: c.y - R, width: R, height: 2 * R).clip()
  let caldi = [arancio, arancio2, giallo, giallo2, arancio2]
  let n = caldi.count
  for i in 0..<n {
    let a1 = 90 + CGFloat(i) * (180 / CGFloat(n))
    let a2 = 90 + CGFloat(i + 1) * (180 / CGFloat(n))
    let sp = spicchio(centro: c, raggio: R * 1.45, da: a1, a: a2)
    caldi[i].setFill()
    sp.fill()
    // Le sfaccettature di MirrorBuddy hanno il loro contorno scuro: senza,
    // i colori sfumano l'uno nell'altro e il mosaico non si legge.
    if S > 64 {
      sp.lineWidth = S * 0.008
      scuro.withAlphaComponent(0.55).setStroke()
      sp.stroke()
    }
  }
  ctx.restoreGState()

  // Meta fredda: la macchina che conta i millesimi.
  ctx.saveGState()
  let destra = NSBezierPath(ovalIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
  destra.addClip()
  CGRect(x: c.x, y: c.y - R, width: R, height: 2 * R).clip()
  let grad = NSGradient(colors: [azzurro, blu])!
  grad.draw(in: CGRect(x: c.x, y: c.y - R, width: R, height: 2 * R), angle: -60)

  // Le tracce del circuito. Nell'icona piccola diventano un pulviscolo: e per
  // questo che la forma deve reggere da sola.
  // Sotto i 64 pixel le tracce diventano pulviscolo e sporcano la forma:
  // meglio un blu pulito che un dettaglio che non si vede.
  if S > 64 {
  let lw = R * 0.085
  NSColor.white.setStroke()
  let tracce = NSBezierPath()
  tracce.lineWidth = lw
  tracce.lineCapStyle = .round
  tracce.lineJoinStyle = .round
  let nodi: [CGPoint] = [
    CGPoint(x: c.x + R * 0.30, y: c.y + R * 0.52),
    CGPoint(x: c.x + R * 0.62, y: c.y + R * 0.14),
    CGPoint(x: c.x + R * 0.34, y: c.y - R * 0.26),
    CGPoint(x: c.x + R * 0.66, y: c.y - R * 0.56),
  ]
  tracce.move(to: CGPoint(x: c.x, y: c.y + R * 0.52))
  tracce.line(to: nodi[0])
  tracce.line(to: CGPoint(x: nodi[0].x + R * 0.32, y: nodi[0].y))
  tracce.move(to: CGPoint(x: c.x, y: c.y + R * 0.14))
  tracce.line(to: nodi[1])
  tracce.move(to: CGPoint(x: c.x, y: c.y - R * 0.26))
  tracce.line(to: nodi[2])
  tracce.line(to: CGPoint(x: nodi[2].x + R * 0.30, y: nodi[2].y - R * 0.30))
  tracce.line(to: nodi[3])
  tracce.stroke()

  for p in nodi {
    let r = R * 0.14
    let anello = NSBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    NSColor.white.setFill(); anello.fill()
    let interno = R * 0.062
    let buco = NSBezierPath(ovalIn: CGRect(x: p.x - interno, y: p.y - interno,
                                           width: 2 * interno, height: 2 * interno))
    blu.setFill(); buco.fill()
  }
  }
  ctx.restoreGState()

  // La linea che divide le due meta: la stessa di MirrorBuddy.
  let divisione = NSBezierPath()
  divisione.lineWidth = S * 0.022
  divisione.move(to: CGPoint(x: c.x, y: c.y - R))
  divisione.line(to: CGPoint(x: c.x, y: c.y + R))
  NSColor.white.setStroke()
  divisione.stroke()

  // La pupilla: grossa apposta. E l'unica cosa che sopravvive a 16 pixel.
  let rp = R * 0.30
  scuro.setFill()
  NSBezierPath(ovalIn: CGRect(x: c.x - rp, y: c.y - rp, width: 2 * rp, height: 2 * rp)).fill()
  // Il riflesso: senza, l'occhio sembra spento.
  let rr = rp * 0.34
  NSColor.white.withAlphaComponent(0.9).setFill()
  NSBezierPath(ovalIn: CGRect(x: c.x - rp * 0.42, y: c.y + rp * 0.18,
                              width: 2 * rr, height: 2 * rr)).fill()

  ctx.restoreGState()

  // Il contorno, spesso: e quello che tiene in piedi la forma da lontano.
  forma.lineWidth = S * 0.045
  forma.lineJoinStyle = .round
  scuro.setStroke()
  forma.stroke()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func scrivi(_ rep: NSBitmapImageRep, _ path: String) {
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icona"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for s: CGFloat in [16, 32, 128, 256, 512, 1024] {
  let n = Int(s)
  let rep = disegna(size: s, fondo: true)
  scrivi(rep, "\(out)/" + (n <= 512 ? "icon_\(n)x\(n).png" : "icon_512x512@2x.png"))
  if n >= 32 && n <= 512 { scrivi(rep, "\(out)/icon_\(n/2)x\(n/2)@2x.png") }
}
scrivi(disegna(size: 1024, fondo: false), "\(out)/logo.png")
print("icone in \(out)")
