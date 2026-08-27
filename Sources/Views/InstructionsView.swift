import SwiftUI

/// Sta fra "Via!" e la prima parola. Serve a due cose: dire che cosa sta per
/// succedere, e far vedere con i propri occhi che il microfono funziona.
struct InstructionsView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: A11ySettings
  @Environment(\.palette) private var palette
  /// Che fare quando dal microfono non arriva proprio niente: portare la
  /// persona dove si sceglie l'ingresso, invece di lasciarla davanti a una
  /// barra ferma senza spiegazioni.
  var onFixMic: () -> Void = {}

  @State private var heardOnce = false
  @State private var silenzioDa: Date?
  @State private var silenzioLungo = false

  private var isWriting: Bool { engine.config.mode == .scrittura }

  var body: some View {
    VStack(spacing: a11y.size(26)) {
      Spacer(minLength: 0)

      Text(engine.isCalibration ? "Facciamo la prova" : "Pronti?")
        .font(a11y.typeface.font(size: a11y.size(42), weight: .bold))
        .foregroundStyle(palette.foreground)

      if isWriting {
        writingSteps
      } else {
        readingSteps
        micCheck
      }

      // Finché il microfono non ha sentito niente, il pulsante per partire non
      // deve essere la cosa più vistosa dello schermo: lo era, e infatti si
      // partiva sempre senza fare la prova, per poi non essere sentiti.
      BigButton(title: readyTitle, symbol: "play.fill", a11y: a11y,
                prominent: isWriting || heardOnce) {
        engine.beginTrials()
      }
      .frame(maxWidth: 420)
      .keyboardShortcut(.space, modifiers: [])

      Explain(text: "Poi vanno da sole tutte le \(engine.totalTrials) parole. Se vuoi fermarti premi Esc.",
              a11y: a11y, size: 16)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(36)
    .onChange(of: engine.micLevel) { _, level in
      if level > 0.02 {
        heardOnce = true
        silenzioLungo = false
        silenzioDa = nil
      }
    }
    .onAppear { silenzioDa = Date() }
    .task {
      // Sei secondi di silenzio assoluto non sono timidezza: è un microfono
      // che non arriva. Meglio dirlo che lasciar credere di aver parlato piano.
      guard !isWriting else { return }
      try? await Task.sleep(for: .seconds(6))
      if !heardOnce { silenzioLungo = true }
    }
  }

  private var messaggioMicrofono: String {
    if heardOnce { return "Ti sento. Puoi cominciare." }
    if silenzioLungo { return "Non arriva niente dal microfono." }
    return "Di' “ciao”, così controlliamo il microfono."
  }

  private var readyTitle: String {
    if isWriting { return "Comincia" }
    return heardOnce ? "Sono pronto" : "Comincia lo stesso"
  }

  private var readingSteps: some View {
    VStack(alignment: .leading, spacing: a11y.size(14)) {
      step("Guarda il **+** in mezzo allo schermo.")
      step("Compare una parola. Le prime \(engine.config.warmupTrials) restano tanto, poi sempre meno.")
      step("Dilla subito ad alta voce, anche se non sei sicuro.")
    }
    .frame(maxWidth: 520, alignment: .leading)
  }

  private var writingSteps: some View {
    VStack(alignment: .leading, spacing: a11y.size(14)) {
      step("Il Mac dice una parola ad alta voce.")
      step("Tu la scrivi nella casella e premi Invio.")
      step("Se non l'hai sentita bene, premi **Ripeti**: non è un errore.")
    }
    .frame(maxWidth: 520, alignment: .leading)
  }

  private func step(_ markdown: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "circle.fill")
        .font(.system(size: a11y.size(8)))
        .foregroundStyle(palette.accent)
        .padding(.top, a11y.size(9))
      Text(.init(markdown))
        .font(a11y.typeface.font(size: a11y.size(21)))
        .foregroundStyle(palette.foreground)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var micCheck: some View {
    VStack(spacing: 10) {
      Image(systemName: heardOnce ? ColorVision.okSymbol : "mic.fill")
        .font(.system(size: a11y.size(44)))
        .foregroundStyle(heardOnce ? palette.ok : palette.accent)
        .scaleEffect(a11y.reducedMotion ? 1 : 1 + min(CGFloat(engine.micLevel) * 5, 0.5))
        .animation(a11y.animation(0.1), value: engine.micLevel)

      ProgressView(value: Double(min(engine.micLevel * 12, 1)))
        .progressViewStyle(.linear)
        .frame(width: 300)
        .tint(heardOnce ? palette.ok : palette.accent)
        .accessibilityLabel("quanto ti sente il microfono")

      // Era una didascalia grigia sotto una barra, e nessuno capiva che
      // toccasse a lui parlare. Adesso è una richiesta, con la parola da dire
      // scritta grande: si legge e si esegue, senza doverci pensare.
      Group {
        if heardOnce {
          Text("Ti sento. Puoi cominciare.")
            .font(a11y.typeface.font(size: a11y.size(26), weight: .semibold))
            .foregroundStyle(palette.ok)
        } else if silenzioLungo {
          Text("Non arriva niente dal microfono.")
            .font(a11y.typeface.font(size: a11y.size(26), weight: .semibold))
            .foregroundStyle(palette.wrong)
        } else {
          VStack(spacing: a11y.size(6)) {
            Text("Adesso di'")
              .font(a11y.typeface.font(size: a11y.size(24)))
              .foregroundStyle(palette.foreground)
            Text("“ciao”")
              .font(a11y.typeface.font(size: a11y.size(44), weight: .bold))
              .foregroundStyle(palette.accent)
            Text("così vediamo se il Mac ti sente")
              .font(a11y.typeface.font(size: a11y.size(18)))
              .foregroundStyle(palette.muted)
          }
        }
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)

      if silenzioLungo && !heardOnce {
        Button("Scegli il microfono") { onFixMic() }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
        Explain(text: "Succede spesso: il Mac sta ascoltando da un altro ingresso — le cuffie spente, una webcam, un'interfaccia collegata e muta.", a11y: a11y, size: 15)
          .frame(maxWidth: 520)
      }
    }
    .padding(.vertical, 6)
  }
}

/// La pausa proposta ogni N parole. Nessun conto alla rovescia: si riparte
/// quando si è pronti, che è tutto il punto di una pausa.
struct PauseView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: A11ySettings
  @Environment(\.palette) private var palette

  var body: some View {
    VStack(spacing: a11y.size(24)) {
      Spacer()
      Image(systemName: "cup.and.saucer.fill")
        .font(.system(size: a11y.size(60)))
        .foregroundStyle(palette.accent)
      Text("Pausa")
        .font(a11y.typeface.font(size: a11y.size(40), weight: .bold))
        .foregroundStyle(palette.foreground)
      Explain(text: "Respira, guarda fuori dalla finestra, muovi le spalle. Riprendiamo quando vuoi tu: non c'è nessun tempo che scorre.",
              a11y: a11y, size: 19)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)

      BigButton(title: "Riprendi", symbol: "play.fill", a11y: a11y) { engine.resumeFromPause() }
        .frame(maxWidth: 360)
        .keyboardShortcut(.space, modifiers: [])

      Button("Ho finito per oggi") { engine.abort() }
        .buttonStyle(.plain)
        .font(a11y.typeface.font(size: a11y.size(16)))
        .foregroundStyle(palette.muted)
        .frame(minHeight: 44)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(36)
  }
}
