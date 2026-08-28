import SwiftUI

/// Modalità "Scrivi": il Mac detta, si scrive.
///
/// È il rovescio del tachistoscopio e allena la conversione suono → lettera,
/// che è il punto debole tipico nella disortografia.
///
/// La schermata ricalca il palcoscenico di `StageView` — stesso pulsante rosso
/// per smettere in alto a sinistra, stesso riquadro centrale che non si muove,
/// stessa fila di pallini in basso. Il compito è diverso, l'interfaccia no:
/// chi passa da Leggi a Scrivi non deve reimparare dove stanno le cose.
struct TypingView: View {
  @ObservedObject var engine: SessionEngine
  var a11y: A11ySettings
  @Environment(\.palette) private var palette
  @FocusState private var focused: Bool

  /// Quale parola scritta si sta riascoltando: serve a illuminarla mentre
  /// suona, così si vede quale delle pastiglie sta parlando.
  @State private var inAscolto: String?

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()
      // Misurato: 1009 punti di contenuto in una finestra da 700, con i
      // caratteri al massimo ingrandimento. Senza scorrimento il campo dove si
      // scrive finiva sotto il bordo, e non c'era modo di arrivarci: colpiva
      // per primo chi ha ipovisione, cioe' proprio chi aveva usato
      // l'impostazione fatta per lui. `minHeight` tiene tutto centrato quando
      // lo spazio basta, quindi a ingrandimento normale non cambia nulla.
      ScrollView { palcoscenico.frame(maxWidth: .infinity, minHeight: 560) }
      // La barra sta sopra alla scena, come in lettura, e come in lettura
      // sparisce con «togli le distrazioni». Prima era dentro alla colonna:
      // restava sempre, e chi aveva chiesto uno schermo nudo se la trovava lì.
      if !a11y.distractionFree { barra }
      progress
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { focused = true }
    .onChange(of: engine.trialIndex) { _, _ in
      focused = true
      inAscolto = nil
    }
  }

  // MARK: - Il palcoscenico

  private var palcoscenico: some View {
    VStack(spacing: a11y.size(20)) {
      Spacer(minLength: 0)

      orecchio

      Text(engine.config.writingLevel.isSentences
           ? "Scrivi la frase che hai sentito"
           : "Scrivi la parola che hai sentito")
        .font(a11y.typeface.font(size: a11y.size(28), weight: .semibold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      campo

      // La fascia della revisione occupa sempre il suo spazio, come quella
      // dell'ascolto in lettura: se comparisse e sparisse mentre si scrive,
      // tutto il resto scivolerebbe su e giù sotto le dita.
      revisione
        .frame(minHeight: a11y.size(96), alignment: .top)
        .opacity(mostraRevisione ? 1 : 0)
        .accessibilityHidden(!mostraRevisione)

      pulsanti

      Explain(text: engine.config.writingLevel.isSentences
              ? "Puoi farla ripetere quante volte vuoi, e toccare una parola qui sopra per risentire solo quella."
              : "Puoi farla ripetere quante volte vuoi. Se proprio non la sai, lascia vuoto e premi Fatto.",
              a11y: a11y, size: 16)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 560)

      Spacer(minLength: 0)
    }
    .padding(36)
  }

  private var orecchio: some View {
    Image(systemName: engine.speaker.isSpeaking ? "speaker.wave.3.fill" : "ear.fill")
      .font(.system(size: a11y.size(46)))
      .foregroundStyle(palette.accent)
      .accessibilityHidden(true)
  }

  private var campo: some View {
    TextField("", text: $engine.typedAnswer, axis: .vertical)
      .textFieldStyle(.plain)
      .font(a11y.typeface.font(size: a11y.size(engine.config.writingLevel.isSentences ? 30 : 44),
                               weight: .semibold))
      .foregroundStyle(palette.foreground)
      .multilineTextAlignment(.center)
      .lineLimit(1...4)
      .padding(.vertical, a11y.size(14))
      .padding(.horizontal, 20)
      .background(RoundedRectangle(cornerRadius: Metrica.raggio).fill(palette.surface))
      .overlay(RoundedRectangle(cornerRadius: Metrica.raggio).stroke(palette.accent, lineWidth: 3))
      .frame(maxWidth: 620)
      .focused($focused)
      .onSubmit { engine.submitTyped() }
      .accessibilityLabel(engine.config.writingLevel.isSentences
                          ? "scrivi qui la frase" : "scrivi qui la parola")
  }

  // MARK: - La revisione parola per parola

  /// Ha senso solo sulle frasi, e solo quando qualcosa è già stato scritto.
  private var mostraRevisione: Bool {
    engine.config.writingLevel.isSentences && !paroleScritte.isEmpty
  }

  private var paroleScritte: [String] {
    engine.typedAnswer.split(whereSeparator: { $0.isWhitespace }).map(String.init)
  }

  /// Le parole appena scritte, una per pastiglia, ognuna che si può risentire
  /// da sola.
  ///
  /// Su una frase intera "ripeti tutto" non basta: chi sta imparando non
  /// sbaglia la frase, sbaglia *una* parola dentro la frase, e per accorgersene
  /// deve poter sentire quella e basta. Il Mac rilegge quello che c'è scritto
  /// davvero — non quello che avrebbe dovuto esserci — perché il punto è
  /// proprio sentire con le proprie orecchie la differenza fra le due cose.
  private var revisione: some View {
    VStack(spacing: a11y.size(8)) {
      Text("Risentiti: tocca una parola")
        .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
        .foregroundStyle(palette.muted)

      FlowLayout(spacing: a11y.size(8)) {
        ForEach(Array(paroleScritte.enumerated()), id: \.offset) { _, parola in
          Button {
            inAscolto = parola
            engine.sayWord(parola)
          } label: {
            Text(parola)
              .font(a11y.typeface.font(size: a11y.size(19), weight: .medium))
              .foregroundStyle(palette.foreground)
              .padding(.horizontal, a11y.size(14))
              .padding(.vertical, a11y.size(9))
              .background(
                Capsule().fill(inAscolto == parola
                               ? palette.accent.opacity(0.22) : palette.surface))
              .overlay(Capsule().stroke(palette.muted.opacity(0.35), lineWidth: 1.5))
              .frame(minHeight: 44)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("risenti la parola \(parola)")
        }
      }
      .frame(maxWidth: 620)
    }
  }

  // MARK: - I pulsanti

  private var pulsanti: some View {
    VStack(spacing: a11y.size(10)) {
      HStack(spacing: 14) {
        BigButton(title: "Ripeti", symbol: "arrow.clockwise", a11y: a11y, prominent: false) {
          engine.repeatWord()
        }
        BigButton(title: "Fatto", symbol: "checkmark", a11y: a11y) {
          engine.submitTyped()
        }
      }
      if mostraRevisione {
        SmallButton(title: "Rileggimi tutta la frase che ho scritto",
                    symbol: "text.bubble.fill", a11y: a11y) {
          inAscolto = nil
          engine.sayWord(engine.typedAnswer)
        }
      }
    }
    .frame(maxWidth: 620)
  }

  // MARK: - Cornice

  /// La stessa striscia della lettura, con le stesse cose nello stesso ordine.
  ///
  /// Anche gli altoparlanti: qui il Mac detta, e se la voce esce dal posto
  /// sbagliato l'esercizio e impossibile — cercare quel comando fuori
  /// dall'allenamento voleva dire perdere la sessione.
  /// La stessa barra della lettura, con gli stessi argomenti: mancava
  /// `cambioMicrofonoInCorso`, così scrivendo non si vedeva che il Mac stava
  /// cambiando ingresso e sembrava che non fosse successo niente.
  private var barra: some View {
    VStack {
      TrainingBar(
        a11y: a11y,
        palette: palette,
        contatore: engine.totalTrials > 0
          ? "\(nomeDellUnita) \(engine.trialIndex) di \(engine.totalTrials)" : "",
        inizio: engine.sessionStartedAt,
        mostraRiscaldamento: engine.isWarmup && engine.totalTrials > 0,
        cambioMicrofonoInCorso: engine.cambioMicrofonoInCorso,
        scegliIngresso: { engine.cambiaMicrofono($0) },
        onStop: { engine.abort() })
      Spacer()
    }
  }

  /// «parola» o «frase»: una parola sola, usata dalla barra e dai pallini, così
  /// non possono più dire due cose diverse sulla stessa sessione.
  private var nomeDellUnita: String {
    engine.config.writingLevel.isSentences ? "frase" : "parola"
  }

  /// La stessa identica fila di pallini della lettura: stesso pezzo, non una
  /// copia che col tempo diventa diversa.
  private var progress: some View {
    ProgressoPallini(fatte: engine.trials, indice: engine.trialIndex,
                     totale: engine.totalTrials, a11y: a11y,
                     nomeDellUnita: nomeDellUnita)
  }
}

/// Manda a capo le pastiglie quando la riga finisce.
///
/// `HStack` le schiaccerebbe fuori dallo schermo su una frase lunga, e una
/// parola tagliata a metà non si può né leggere né toccare.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let larghezza = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, altezzaRiga: CGFloat = 0
    for v in subviews {
      let d = v.sizeThatFits(.unspecified)
      if x + d.width > larghezza, x > 0 {
        x = 0
        y += altezzaRiga + spacing
        altezzaRiga = 0
      }
      x += d.width + spacing
      altezzaRiga = max(altezzaRiga, d.height)
    }
    return CGSize(width: larghezza == .infinity ? x : larghezza, height: y + altezzaRiga)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                     subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, altezzaRiga: CGFloat = 0
    for v in subviews {
      let d = v.sizeThatFits(.unspecified)
      if x + d.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += altezzaRiga + spacing
        altezzaRiga = 0
      }
      v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(d))
      x += d.width + spacing
      altezzaRiga = max(altezzaRiga, d.height)
    }
  }
}
