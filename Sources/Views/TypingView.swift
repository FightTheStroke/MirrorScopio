import SwiftUI

/// Modalità "Scrivi": il Mac detta, si scrive. È il rovescio del tachistoscopio
/// e allena la conversione suono → lettera, che è il punto debole tipico
/// nella disortografia.
struct TypingView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: A11ySettings
  @Environment(\.palette) private var palette
  @FocusState private var focused: Bool

  var body: some View {
    VStack(spacing: a11y.size(24)) {
      header

      Spacer(minLength: 0)

      Image(systemName: engine.speaker.isSpeaking ? "speaker.wave.3.fill" : "ear.fill")
        .font(.system(size: a11y.size(52)))
        .foregroundStyle(palette.accent)
        .accessibilityHidden(true)

      Text("Scrivi la parola che hai sentito")
        .font(a11y.typeface.font(size: a11y.size(28), weight: .semibold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      TextField("", text: $engine.typedAnswer)
        .textFieldStyle(.plain)
        .font(a11y.typeface.font(size: a11y.size(44), weight: .semibold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)
        .padding(.vertical, a11y.size(14))
        .padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.accent, lineWidth: 3))
        .frame(maxWidth: 560)
        .focused($focused)
        .onSubmit { engine.submitTyped() }
        .accessibilityLabel("scrivi qui la parola")

      HStack(spacing: 14) {
        BigButton(title: "Ripeti", symbol: "arrow.clockwise", a11y: a11y, prominent: false) {
          engine.repeatWord()
        }
        BigButton(title: "Fatto", symbol: "checkmark", a11y: a11y) {
          engine.submitTyped()
        }
      }
      .frame(maxWidth: 560)

      Explain(text: "Puoi farla ripetere quante volte vuoi. Se proprio non la sai, lascia vuoto e premi Fatto.",
              a11y: a11y, size: 16)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(36)
    .onAppear { focused = true }
    .onChange(of: engine.trialIndex) { _, _ in focused = true }
  }

  private var header: some View {
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

      Spacer()

      if engine.totalTrials > 0 {
        Text("parola \(engine.trialIndex) di \(engine.totalTrials)")
          .font(a11y.typeface.font(size: a11y.size(16)))
          .foregroundStyle(palette.muted)
          .monospacedDigit()
      }
    }
  }
}
