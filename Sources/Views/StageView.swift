import SwiftUI

/// La schermata durante la prova. Deve essere vuota: qualsiasi cosa in più
/// ruba attenzione alla parola che sta per comparire.
struct StageView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: A11ySettings
  @Environment(\.palette) private var palette

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()

      switch engine.phase {
      case .preparing:
        VStack(spacing: 16) {
          ProgressView()
          Text(engine.statusMessage)
            .font(a11y.typeface.font(size: a11y.size(20)))
            .foregroundStyle(palette.muted)
        }

      case .countdown(let n):
        Text("\(n)")
          .font(a11y.typeface.font(size: a11y.size(150), weight: .light))
          .foregroundStyle(palette.muted)
          .contentTransition(.identity)
          .accessibilityLabel("si comincia fra \(n)")

      case .failed(let message):
        failure(message)

      case .feedback(let ok):
        feedback(ok)

      case .listening, .flushing, .scoring:
        listening

      default:
        stimulus
      }

      if !a11y.distractionFree { overlay }
      progress
    }
  }

  /// Avanzamento: una fila di pallini in basso, uno per parola.
  ///
  /// Sparisce mentre la parola è sullo schermo e mentre c'è la maschera: in quei
  /// due momenti qualsiasi cosa che si muove ruba lo sguardo, ed è esattamente
  /// lo sguardo che stiamo misurando.
  @ViewBuilder
  private var progress: some View {
    if engine.totalTrials > 0, showsProgress {
      VStack {
        Spacer()
        HStack(spacing: 8) {
          ForEach(0..<engine.totalTrials, id: \.self) { i in
            Circle()
              .fill(dotColor(i))
              .frame(width: i == engine.trialIndex - 1 ? 12 : 8,
                     height: i == engine.trialIndex - 1 ? 12 : 8)
          }
        }
        .padding(.bottom, 26)
        .animation(a11y.animation(0.2), value: engine.trialIndex)
        .accessibilityElement()
        .accessibilityLabel("parola \(engine.trialIndex) di \(engine.totalTrials)")
      }
      .allowsHitTesting(false)
      .transition(.opacity)
    }
  }

  private var showsProgress: Bool {
    switch engine.phase {
    case .stimulus, .preMask, .postMask, .fixation, .countdown, .preparing: false
    default: true
    }
  }

  /// Il colore del pallino dice com'è andata, ma solo se il feedback per parola
  /// è acceso: con "nascondi i punteggi" resta una fila neutra che dice soltanto
  /// a che punto siamo.
  private func dotColor(_ i: Int) -> Color {
    guard i < engine.trials.count, i < engine.trialIndex else {
      return palette.muted.opacity(0.25)
    }
    guard a11y.showFeedbackPerWord, !a11y.hideScore else {
      return palette.muted.opacity(0.75)
    }
    return engine.trials[i].correct ? palette.ok.opacity(0.8) : palette.wrong.opacity(0.8)
  }

  // MARK: - Lo stimolo

  private var stimulus: some View {
    Text(engine.displayText)
      .font(a11y.typeface.font(size: CGFloat(a11y.stimulusSize), weight: .semibold))
      .tracking(CGFloat(a11y.letterSpacing))
      .foregroundStyle(palette.foreground)
      .monospacedDigit()
      .accessibilityHidden(true)
  }

  private var listening: some View {
    VStack(spacing: a11y.size(20)) {
      Text("Leggi ad alta voce")
        .font(a11y.typeface.font(size: a11y.size(36), weight: .semibold))
        .foregroundStyle(palette.foreground)

      Image(systemName: "waveform")
        .font(.system(size: a11y.size(44)))
        .foregroundStyle(palette.accent)
        .scaleEffect(a11y.reducedMotion ? 1 : 1 + min(CGFloat(engine.micLevel) * 6, 0.6))
        .animation(a11y.animation(0.08), value: engine.micLevel)

      Text(engine.liveTranscript.isEmpty ? "ti ascolto…" : engine.liveTranscript)
        .font(a11y.typeface.font(size: a11y.size(24)))
        .foregroundStyle(palette.muted)
    }
  }

  private func feedback(_ ok: Bool) -> some View {
    VStack(spacing: 14) {
      Image(systemName: ok ? ColorVision.okSymbol : ColorVision.wrongSymbol)
        .font(.system(size: a11y.size(100)))
        .foregroundStyle(ok ? palette.ok : palette.wrong)
      if !a11y.hideScore {
        Text(ok ? (a11y.calmMode ? "Giusta" : "Giusta!") : "Riproviamo")
          .font(a11y.typeface.font(size: a11y.size(28), weight: .semibold))
          .foregroundStyle(palette.foreground)
      }
    }
    .transition(a11y.reducedMotion ? .identity : .opacity)
  }

  private func failure(_ message: String) -> some View {
    VStack(spacing: 18) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: a11y.size(48)))
        .foregroundStyle(palette.wrong)
      Text(message)
        .font(a11y.typeface.font(size: a11y.size(19)))
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
        .foregroundStyle(palette.foreground)
      BigButton(title: "Torna indietro", a11y: a11y, prominent: false) { engine.reset() }
        .frame(maxWidth: 300)
    }
  }

  // MARK: - Bordi

  private var overlay: some View {
    VStack {
      HStack {
        Button { engine.abort() } label: {
          Label("Basta", systemImage: "stop.circle")
            .font(a11y.typeface.font(size: a11y.size(16)))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.muted)
        .keyboardShortcut(.escape, modifiers: [])
        .accessibilityLabel("interrompi la sessione")

        if engine.isWarmup && engine.totalTrials > 0 {
          Text("riscaldamento")
            .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(palette.accent.opacity(0.22)))
            .foregroundStyle(palette.foreground)
        }

        Spacer()

        if engine.totalTrials > 0 {
          Text("parola \(engine.trialIndex) di \(engine.totalTrials)")
            .font(a11y.typeface.font(size: a11y.size(16)))
            .foregroundStyle(palette.muted)
            .monospacedDigit()
        }
      }
      .padding(.horizontal, 22)
      .padding(.top, 16)
      Spacer()
    }
  }
}
