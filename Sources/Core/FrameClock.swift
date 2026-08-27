import SwiftUI
import AppKit
import QuartzCore

/// Vista invisibile che espone il display link della finestra: dà un impulso per
/// ogni frame effettivamente disegnato, che è l'unica base di tempo affidabile
/// per un tachistoscopio.
final class TickView: NSView {
  var onTick: ((CFTimeInterval) -> Void)?
  /// Il battito serve solo quando c'è qualcosa da cronometrare o da far vedere
  /// muoversi. Restando acceso sempre, teneva l'app a disegnare sessanta volte
  /// al secondo anche ferma in home: mezzo core sempre occupato, la batteria
  /// che se ne va, le ventole di un Mac vecchio che partono per niente — e
  /// l'albero di accessibilità così affollato di aggiornamenti da non riuscire
  /// più a essere letto da fuori.
  var attivo = true { didSet { link?.isPaused = !attivo } }
  private var link: CADisplayLink?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    link?.invalidate()
    guard window != nil else { link = nil; return }
    let l = displayLink(target: self, selector: #selector(step(_:)))
    l.add(to: .main, forMode: .common)
    l.isPaused = !attivo
    link = l
  }

  @objc private func step(_ sender: CADisplayLink) {
    onTick?(sender.targetTimestamp)
  }
}

struct FrameClock: NSViewRepresentable {
  var attivo = true
  let onTick: (CFTimeInterval) -> Void

  func makeNSView(context: Context) -> TickView {
    let v = TickView()
    v.onTick = onTick
    v.attivo = attivo
    return v
  }

  func updateNSView(_ nsView: TickView, context: Context) {
    nsView.onTick = onTick
    if nsView.attivo != attivo { nsView.attivo = attivo }
  }
}

