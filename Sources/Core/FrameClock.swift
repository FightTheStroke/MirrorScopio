import SwiftUI
import AppKit
import QuartzCore

/// Vista invisibile che espone il display link della finestra: dà un impulso per
/// ogni frame effettivamente disegnato, che è l'unica base di tempo affidabile
/// per un tachistoscopio.
final class TickView: NSView {
  /// Il momento del prossimo frame e **quanto dura un frame su questo
  /// schermo**. La durata arriva da qui e non da `NSScreen.main` perché
  /// `NSScreen.main` è lo schermo dove c'è il fuoco della tastiera, non quello
  /// dove sta la finestra: con un portatile a 120 Hz aperto accanto a un
  /// monitor a 60 Hz, i due numeri sono diversi e la parola resta esposta il
  /// doppio o la metà di quanto dice il referto. Il display link, invece, è
  /// quello della finestra: sa per forza la verità.
  var onTick: ((CFTimeInterval, CFTimeInterval) -> Void)?
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
    // `duration` è la durata nominale del frame su questo schermo. Su un
    // display a frequenza variabile può oscillare: si prende la distanza vera
    // fra il frame di adesso e quello atteso, che è la stessa cosa quando la
    // frequenza è fissa e più onesta quando non lo è.
    let durata = sender.targetTimestamp - sender.timestamp
    onTick?(sender.targetTimestamp, durata > 0 ? durata : sender.duration)
  }
}

struct FrameClock: NSViewRepresentable {
  var attivo = true
  let onTick: (CFTimeInterval, CFTimeInterval) -> Void

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

