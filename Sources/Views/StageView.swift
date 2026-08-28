import SwiftUI

/// La schermata durante la prova. Deve essere vuota: qualsiasi cosa in più
/// ruba attenzione alla parola che sta per comparire.
struct StageView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: EffettiveImpostazioniAccessibilita
  @Environment(\.palette) private var palette

  /// L'ultima cosa detta a voce, per non ripetersi.
  ///
  /// `@Published` avvisa a ogni assegnazione, anche quando il valore non è
  /// cambiato: senza questo guardiano VoiceOver direbbe «ti ascolto» tre volte
  /// di fila e coprirebbe quello che viene dopo.
  @State private var ultimaVoce = ""

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()

      switch engine.phase {
      case .preparing:
        VStack(spacing: Metrica.spazioMedio) {
          ProgressView()
          Text(engine.statusMessage)
            .font(a11y.font(.guida))
            .foregroundStyle(palette.muted)
        }

      case .countdown(let n):
        Text("\(n)")
          .font(a11y.font(.titoloGrande, .light))
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
    // Chi usa VoiceOver seguiva l'esercizio alla cieca: lo schermo cambiava —
    // conto alla rovescia, ascolto aperto, esito del turno — e non lo diceva
    // nessuno. Restava il silenzio, e non c'era modo di distinguere «sto
    // aspettando che parli» da «si è piantato».
    //
    // Qui si annuncia che cosa sta succedendo, mai la parola da leggere: dirla
    // sarebbe suggerire la risposta.
    .onChange(of: engine.phase) { _, nuova in annuncia(fraseDellaFase(nuova)) }
    // Un turno vuoto e un microfono muto sono due cose opposte, e a voce si
    // somigliavano entrambe al silenzio.
    .onChange(of: engine.ascoltoAvviso) { _, avviso in annuncia(avviso ?? "") }
    .onChange(of: engine.statusMessage) { _, messaggio in
      if case .preparing = engine.phase { annuncia(messaggio) }
    }
    .onChange(of: engine.voceInCorso) { _, sente in
      if sente, mostraAscolto { annuncia("Ti sento") }
    }
    // Un microfono muto, a schermo, si vede dal cerchio che non pulsa. Chi non
    // guarda lo schermo aveva solo il silenzio, uguale identico al silenzio di
    // «sto aspettando che parli»: due secondi bastano a distinguerli.
    .task(id: mostraAscolto) {
      guard mostraAscolto else { return }
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled, mostraAscolto,
            !engine.voceInCorso, engine.liveTranscript.isEmpty else { return }
      annuncia("Non sento niente dal microfono")
    }
  }

  // MARK: - Quello che l'app dice a voce

  private func annuncia(_ frase: String) {
    guard !frase.isEmpty, frase != ultimaVoce else { return }
    ultimaVoce = frase
    AccessibilityNotification.Announcement(frase).post()
  }

  /// Che cosa sta succedendo, detto a chi non guarda lo schermo.
  ///
  /// La parola dello stimolo non compare mai qui dentro: l'esercizio misura se
  /// si riesce a leggerla in un lampo, e annunciarla sarebbe barare.
  private func fraseDellaFase(_ fase: Phase) -> String {
    switch fase {
    case .preparing: "Sto preparando"
    case .countdown(let n): n == 1 ? "Si comincia" : ""
    case .fixation: "Guarda al centro"
    case .stimulus: "Parola \(engine.trialIndex + 1) di \(engine.totalTrials)"
    case .listening: "Adesso parla"
    case .flushing, .scoring: "Sto ascoltando quello che hai detto"
    case .typing: "Scrivi la parola"
    case .feedback(let ok): a11y.hideScore ? "Turno finito" : (ok ? "Giusta" : "Ancora")
    case .pausa: "Pausa"
    case .finished: "Sessione finita"
    case .failed(let messaggio): messaggio
    default: ""
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
    VStack(spacing: a11y.size(Metrica.spazioLargo)) {
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
    .padding(.horizontal, Metrica.spazioGrande)
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
        RoundedRectangle(cornerRadius: Metrica.raggioMinimo)
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
    VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
      Text(mostraAscolto ? "Leggi ad alta voce" : "Guarda qui sopra")
        .font(a11y.font(.titolo, .semibold))
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
        .font(a11y.font(.sezione))
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
    VStack(spacing: Metrica.spazioPiccolo) {
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
          .font(a11y.font(.titolo, .semibold))
          .foregroundStyle(palette.foreground)
      }
      // Un turno vuoto ha due cause opposte, e confonderle e crudele: se il
      // microfono non ha ricevuto niente, non c'e nessuna parola da riprovare
      // e nessuna colpa da attribuire a chi sta leggendo.
      if let avviso = engine.ascoltoAvviso {
        Text(avviso)
          .font(a11y.font(.corpo))
          .foregroundStyle(palette.muted)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 460)
      }
    }
    .transition(a11y.reducedMotion ? .identity : .opacity)
  }

  private func failure(_ message: String) -> some View {
    VStack(spacing: Metrica.spazioMedio) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: a11y.size(48)))
        .foregroundStyle(palette.wrong)
        .accessibilityHidden(true)
      Text(message)
        .font(a11y.font(.guida))
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
