// Genera l'icona di MirrorScopio.
//
// L'icona racconta quello che l'app fa: una lettera che emerge dalle barre
// della maschera. Le barre sono lo stesso segno che si vede a schermo fra una
// parola e l'altra, quindi chi ha usato l'app riconosce l'icona senza leggere
// il nome — e chi non l'ha mai usata vede comunque una lettera grande e
// chiara, non un simbolo da decifrare.
//
// Una sola forma, un solo colore forte, nessun dettaglio sottile: a 16 punti
// nel Dock deve restare leggibile.
//
//   swift scripts/icona.swift

import AppKit

let blu = NSColor(srgbRed: 0.13, green: 0.34, blue: 0.85, alpha: 1)
let bluChiaro = NSColor(srgbRed: 0.25, green: 0.55, blue: 1.0, alpha: 1)

func disegna(size S: CGFloat) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext
  ctx.setAllowsAntialiasing(true)
  ctx.interpolationQuality = .high

  // Il riquadro dell'app: margine e raggio delle icone di macOS.
  let m = S * 0.105
  let box = CGRect(x: m, y: m, width: S - 2 * m, height: S - 2 * m)
  let corpo = NSBezierPath(roundedRect: box, xRadius: box.width * 0.2237,
                           yRadius: box.width * 0.2237)

  ctx.saveGState()
  corpo.addClip()
  let grad = NSGradient(colors: [bluChiaro, blu])!
  grad.draw(in: box, angle: -90)

  // Le barre della maschera si diradano salendo: in basso coprono, in alto
  // hanno gia lasciato passare la lettera. E il movimento dell'app — la
  // maschera se ne va e la parola resta.
  let barre = 7
  let passo = box.height / CGFloat(barre * 2 + 1)
  for i in 0..<barre {
    let quota = CGFloat(i) / CGFloat(barre - 1)   // 0 in basso, 1 in alto
    NSColor.white.withAlphaComponent(0.22 * (1 - quota)).setFill()
    let y = box.minY + passo * CGFloat(i * 2 + 1)
    CGRect(x: box.minX, y: y, width: box.width, height: passo).fill()
  }

  // La lettera. "A" perché è la prima che si impara, ed è la stessa in
  // stampatello maiuscolo per chiunque, dislessia compresa.
  let corpoTesto = S * 0.52
  let font = NSFont.systemFont(ofSize: corpoTesto, weight: .heavy)
  let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
  let s = NSAttributedString(string: "A", attributes: attr)
  let d = s.size()
  s.draw(at: CGPoint(x: box.midX - d.width / 2, y: box.midY - d.height / 2 + S * 0.01))

  ctx.restoreGState()
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icona"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for s: CGFloat in [16, 32, 64, 128, 256, 512, 1024] {
  let rep = disegna(size: s)
  let png = rep.representation(using: .png, properties: [:])!
  let n = Int(s)
  let nome = n <= 512 ? "icon_\(n)x\(n).png" : "icon_512x512@2x.png"
  try! png.write(to: URL(fileURLWithPath: "\(out)/\(nome)"))
  if n >= 32 && n <= 512 {
    try! png.write(to: URL(fileURLWithPath: "\(out)/icon_\(n/2)x\(n/2)@2x.png"))
  }
}
print("icone in \(out)")
