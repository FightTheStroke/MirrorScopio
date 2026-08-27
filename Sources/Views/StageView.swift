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

      case .listening, .flushing, .scoring, .fixation, .preMask, .stimulus,
           .postMask, .interTrial:
        palcoscenico

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
    if showsProgress {
      ProgressoPallini(fatte: engine.trials, indice: engine.trialIndex,
                       totale: engine.totalTrials, a11y: a11y)
    }
  }

  private var showsProgress: Bool {
    switch engine.phase {
    case .stimulus, .preMask, .postMask, .fixation, .countdown, .preparing: false
    default: true
    }
  }

  // MARK: - Il palcoscenico

  /// Una scena sola, che non cambia mai.
  ///
  /// Prima ogni momento aveva il suo schermo: il `+`, la parola, la maschera,
  /// poi di colpo un'altra pagina con scritto "Leggi ad alta voce". Il salto
  /// costringeva l'occhio a ricercare ogni volta dove guardare — e l'occhio è
  /// esattamente ciò che stiamo misurando. Adesso il riquadro centrale sta
  /// fermo e cambia solo il suo contenuto; la fascia dell'ascolto occupa
  /// sempre il suo spazio, anche quando è invisibile, così niente scivola.
  private var palcoscenico: some View {
    VStack(spacing: a11y.size(28)) {
      Spacer(minLength: 0)

      ZStack {
        Color.clear
        switch engine.phase {
        case .fixation: puntoDiPartenza
        case .preMask, .postMask: maschera
        case .listening, .flushing, .scoring: maschera.opacity(0.35)
        default: stimulus
        }
      }
      .frame(height: CGFloat(a11y.stimulusSize) * 1.6)

      ascolto
        .frame(height: a11y.size(120))
        // Invisibile non basta: se restasse leggibile da VoiceOver mentre la
        // parola è sullo schermo, la direbbe ad alta voce.
        .accessibilityHidden(!mostraAscolto)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 36)
  }

  private var mostraAscolto: Bool {
    switch engine.phase {
    case .listening, .flushing, .scoring: true
    default: false
    }
  }

  /// Il punto dove guardare, prima che la parola arrivi.
  ///
  /// Era un `+`, ed era un errore che nessuno vedeva perché a noi il `+` non
  /// sembra una lettera. A chi sta imparando a leggere sì: è un segno nero al
  /// centro dello schermo, nel punto esatto in cui gli abbiamo appena detto di
  /// aspettarsi qualcosa da leggere, e più d'uno provava a dirlo. La funzione
  /// clinica — portare l'occhio al centro prima dello stimolo — resta
  /// identica, ma un cerchietto non si legge e non si pronuncia.
  private var puntoDiPartenza: some View {
    Circle()
      .fill(palette.muted.opacity(0.55))
      .frame(width: CGFloat(a11y.stimulusSize) * 0.14,
             height: CGFloat(a11y.stimulusSize) * 0.14)
      .accessibilityHidden(true)
  }

  /// La maschera non è più una fila di cancelletti.
  ///
  /// Serve a interrompere l'immagine che resta nell'occhio dopo la parola:
  /// senza, l'esposizione dura più dei millesimi che dichiariamo e la misura
  /// non vale. Ma `####` è fatto di caratteri, e a un ragazzo che sta faticando
  /// a decifrare viene naturale provare a leggerli. Delle barre non si leggono:
  /// fanno lo stesso lavoro senza chiedere niente.
  private var maschera: some View {
    HStack(spacing: CGFloat(a11y.letterSpacing) + 4) {
      ForEach(0..<max(3, engine.displayText.count), id: \.self) { _ in
        RoundedRectangle(cornerRadius: 2)
          .fill(palette.foreground.opacity(0.55))
          .frame(width: CGFloat(a11y.stimulusSize) * 0.42,
                 height: CGFloat(a11y.stimulusSize) * 0.72)
      }
    }
    .accessibilityHidden(true)
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

  /// L'invito a parlare: sempre nello stesso punto, dall'inizio alla fine.
  ///
  /// Non compare e non scompare — si accende. Prima era un blocco che spuntava
  /// dal nulla a parola finita, e il salto costringeva a ricercare ogni volta
  /// dove guardare. Adesso occupa il suo spazio anche mentre la parola e sullo
  /// schermo, spento e immobile, cosi niente si sposta e niente distrae.
  private var ascolto: some View {
    VStack(spacing: a11y.size(12)) {
      Text(mostraAscolto ? "Leggi ad alta voce" : "Guarda qui sopra")
        .font(a11y.typeface.font(size: a11y.size(30), weight: .semibold))
        .foregroundStyle(mostraAscolto ? palette.foreground : palette.muted.opacity(0.45))

      Image(systemName: "waveform")
        .font(.system(size: a11y.size(44)))
        .foregroundStyle(mostraAscolto ? palette.accent : palette.muted.opacity(0.3))
        // Il livello del microfono muove l'onda solo quando tocca parlare:
        // mentre la parola e sullo schermo qualsiasi movimento ruba lo sguardo,
        // ed e lo sguardo che stiamo misurando.
        .scaleEffect(a11y.reducedMotion || !mostraAscolto
                     ? 1 : 1 + min(CGFloat(engine.micLevel) * 6, 0.6))
        .animation(a11y.animation(0.08), value: engine.micLevel)
        .accessibilityHidden(true)

      Text(sottotitoloAscolto)
        .font(a11y.typeface.font(size: a11y.size(24)))
        .foregroundStyle(palette.muted.opacity(mostraAscolto ? 1 : 0.4))
        .lineLimit(1)
    }
  }

  private var sottotitoloAscolto: String {
    guard mostraAscolto else { return " " }
    if !engine.liveTranscript.isEmpty { return engine.liveTranscript }
    // Dire "ti ascolto" mentre il microfono non riceve niente e una bugia
    // gentile, e le bugie gentili fanno perdere mezz'ora a cercare un guasto
    // che non c'e — o peggio, fanno credere a un ragazzo di non essere capace.
    return engine.voceInCorso ? "ti sento…" : "parla pure"
  }

  private func feedback(_ ok: Bool) -> some View {
    VStack(spacing: 14) {
      Image(systemName: ok ? ColorVision.okSymbol : ColorVision.wrongSymbol)
        .font(.system(size: a11y.size(100)))
        .foregroundStyle(ok ? palette.ok : palette.wrong)
        .accessibilityHidden(!a11y.hideScore)
        .accessibilityLabel(ok ? "Giusta" : "Ancora")
      if !a11y.hideScore {
        // "Ancora" e non "sbagliato": la parola non è venuta *ancora*, e la
        // differenza fra le due parole è tutta la differenza fra un difetto e
        // un percorso.
        Text(ok ? (a11y.calmMode ? "Giusta" : "Giusta!") : "Ancora")
          .font(a11y.typeface.font(size: a11y.size(28), weight: .semibold))
          .foregroundStyle(palette.foreground)
      }
      // Un turno vuoto ha due cause opposte, e confonderle e crudele: se il
      // microfono non ha ricevuto niente, non c'e nessuna parola da riprovare
      // e nessuna colpa da attribuire a chi sta leggendo.
      if let avviso = engine.ascoltoAvviso {
        Text(avviso)
          .font(a11y.typeface.font(size: a11y.size(18)))
          .foregroundStyle(palette.muted)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 460)
      }
    }
    .transition(a11y.reducedMotion ? .identity : .opacity)
  }

  private func failure(_ message: String) -> some View {
    VStack(spacing: 18) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: a11y.size(48)))
        .foregroundStyle(palette.wrong)
        .accessibilityHidden(true)
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
      TrainingBar(
        a11y: a11y,
        palette: palette,
        contatore: engine.totalTrials > 0
          ? "parola \(engine.trialIndex) di \(engine.totalTrials)" : "",
        inizio: engine.sessionStartedAt,
        mostraRiscaldamento: engine.isWarmup && engine.totalTrials > 0,
        cambioMicrofonoInCorso: engine.cambioMicrofonoInCorso,
        scegliIngresso: { engine.cambiaMicrofono($0) },
        onStop: { engine.abort() })
      Spacer()
    }
  }
}
