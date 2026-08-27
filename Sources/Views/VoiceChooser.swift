import AVFoundation
import SwiftUI

/// Scelta della voce, dentro l'app e con l'orecchio.
///
/// Nessuna app può installare le voci di Apple — non esiste un modo previsto
/// per farlo — ma può fare tutto il resto: mostrare quelle che ci sono, farle
/// ascoltare e lasciar scegliere. Chi usa MirrorScopio sceglie la voce che
/// capisce meglio sentendola, non leggendo il nome di un file.
struct VoiceChooser: View {
  @Environment(\.palette) private var palette
  @ObservedObject var store: Store
  /// Mostra anche la velocità di lettura.
  var showsRate = true

  @State private var voci: [AVSpeechSynthesisVoice] = []
  @State private var inProva: String?
  @State private var synth = AVSpeechSynthesizer()

  private var a11y: A11ySettings { store.current.a11y }

  private var sceltaCorrente: String? {
    a11y.voiceIdentifier ?? Speaker.bestItalianVoice?.identifier
  }

  var body: some View {
    VStack(alignment: .leading, spacing: a11y.size(14)) {
      SectionTitle(text: "La voce che legge", a11y: a11y)
      Explain(text: "Premi ▶︎ per sentirla. Scegli quella che si capisce meglio.", a11y: a11y)

      if voci.isEmpty {
        Explain(text: "Nessuna voce italiana trovata su questo Mac.", a11y: a11y)
      }

      ForEach(voci, id: \.identifier) { voce in
        riga(voce)
      }

      if showsRate {
        VStack(alignment: .leading, spacing: 6) {
          Text("Velocità della voce")
            .font(a11y.typeface.font(size: a11y.size(19), weight: .semibold))
            .foregroundStyle(palette.foreground)
          HStack(spacing: 12) {
            Image(systemName: "tortoise.fill").foregroundStyle(palette.muted)
            Slider(value: Binding(get: { a11y.voiceRate },
                                  set: { v in store.update { $0.a11y.voiceRate = v } }),
                   in: 0.30...0.60)
            Image(systemName: "hare.fill").foregroundStyle(palette.muted)
          }
          Explain(text: "Più a sinistra, più lenta. Per chi legge con fatica, lenta è meglio.",
                  a11y: a11y, size: 16)
        }
        .padding(.top, 6)
      }
    }
    // Ricaricate a ogni comparsa: una voce può essere stata scaricata mentre
    // l'app era già aperta.
    .onAppear { carica() }
  }

  @ViewBuilder
  private func riga(_ voce: AVSpeechSynthesisVoice) -> some View {
    let scelta = voce.identifier == sceltaCorrente
    HStack(spacing: 14) {
      Button {
        store.update { $0.a11y.voiceIdentifier = voce.identifier }
        prova(voce)
      } label: {
        HStack(spacing: 12) {
          Image(systemName: scelta ? "largecircle.fill.circle" : "circle")
            .font(.system(size: a11y.size(22)))
            .foregroundStyle(scelta ? palette.accent : palette.muted)
          VStack(alignment: .leading, spacing: 2) {
            Text(voce.name)
              .font(a11y.typeface.font(size: a11y.size(21), weight: scelta ? .bold : .regular))
              .foregroundStyle(palette.foreground)
            Text(Speaker.qualityLabel(voce))
              .font(a11y.typeface.font(size: a11y.size(15)))
              .foregroundStyle(palette.muted)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button {
        prova(voce)
      } label: {
        Image(systemName: inProva == voce.identifier ? "speaker.wave.3.fill" : "play.fill")
          .font(.system(size: a11y.size(20)))
          .frame(width: a11y.size(46), height: a11y.size(40))
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Ascolta \(voce.name)")
    }
    .padding(.vertical, 4)
  }

  private func prova(_ voce: AVSpeechSynthesisVoice) {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    let u = AVSpeechUtterance(string: "Ciao, sono \(voce.name). Leggiamo insieme: farfalla.")
    u.voice = voce
    u.rate = Float(a11y.voiceRate)
    inProva = voce.identifier
    synth.speak(u)
    Task {
      try? await Task.sleep(for: .seconds(3))
      if inProva == voce.identifier { inProva = nil }
    }
  }

  private func carica() {
    voci = Speaker.italianVoices()
  }
}
