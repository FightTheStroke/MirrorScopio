import SwiftUI
import AppKit
import QuartzCore

/// Vista invisibile che espone il display link della finestra: dà un impulso per
/// ogni frame effettivamente disegnato, che è l'unica base di tempo affidabile
/// per un tachistoscopio.
final class TickView: NSView {
  var onTick: ((CFTimeInterval) -> Void)?
  private var link: CADisplayLink?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    link?.invalidate()
    guard window != nil else { link = nil; return }
    let l = displayLink(target: self, selector: #selector(step(_:)))
    l.add(to: .main, forMode: .common)
    link = l
  }

  @objc private func step(_ sender: CADisplayLink) {
    onTick?(sender.targetTimestamp)
  }
}

struct FrameClock: NSViewRepresentable {
  let onTick: (CFTimeInterval) -> Void

  func makeNSView(context: Context) -> TickView {
    let v = TickView()
    v.onTick = onTick
    return v
  }

  func updateNSView(_ nsView: TickView, context: Context) {
    nsView.onTick = onTick
  }
}
