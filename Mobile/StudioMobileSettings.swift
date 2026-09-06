import SwiftUI

/// Gli stessi comandi del Mac, in una colonna che resta leggibile anche sul telefono.
struct StudioMobileSettings: View {
  @Binding var scelte: A11ySettings
  var errore: String?
  var onClose: () -> Void
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var speaker = Speaker()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Metrica.spazioLargo) {
        SectionTitle(text: "Impostazioni", a11y: a11y)
          .accessibilityAddTraits(.isHeader)
        if let errore {
          Label("Preferenze da controllare", systemImage: "exclamationmark.triangle")
            .font(a11y.font(.corpo, .semibold))
            .fixedSize(horizontal: false, vertical: true)
          Explain(text: errore, a11y: a11y)
        }
        Explain(text: "Le scelte valgono subito e restano su questo dispositivo.", a11y: a11y)
        if let frase = a11y.mac.frase { Explain(text: frase, a11y: a11y) }
        lettura
        colori
        voce
        ritmo
      }
      .padding(Metrica.spazio)
      .frame(maxWidth: a11y.size(640))
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .safeAreaInset(edge: .top, alignment: .trailing) {
      SmallButton(title: "Chiudi", a11y: a11y, prominente: true, action: onClose)
        .accessibilityLabel("Chiudi impostazioni")
        .accessibilityIdentifier("studio.settings.close")
        .keyboardShortcut(.escape, modifiers: [])
        .padding(Metrica.spazioMedio)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(palette.background)
    }
    .font(a11y.font(.corpo))
    .foregroundStyle(palette.foreground)
    .tint(palette.accent)
    .background(palette.background.ignoresSafeArea())
    .onDisappear { speaker.stop() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { speaker.stop() }
    }
  }

  private var lettura: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      titolo("Come si legge")
      ForEach(TypefaceChoice.allCases.filter(\.isAvailable)) { carattere in
        ChoiceCard(title: carattere.label, subtitle: carattere.hint,
                   selected: scelte.typeface == carattere, a11y: a11y) {
          aggiorna { $0.typeface = carattere }
        }
      }
      let mancanti = TypefaceChoice.allCases.filter { !$0.isAvailable }
      if !mancanti.isEmpty {
        Explain(text: "Caratteri non disponibili in questa copia: "
                + mancanti.map(\.label).joined(separator: ", ")
                + ". Puoi scegliere uno degli altri caratteri.", a11y: a11y)
      }
      Text("Una pagina, un passo alla volta.")
        .font(a11y.font(.guida))
        .interlinea(a11y)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Metrica.spazioMedio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggio))
      titolo("Dimensione di tutto")
      PassoAccessibile(titolo: "Dimensione di tutto", valore: bind(\.textScale),
                       intervallo: 0.8...2, passo: 0.03, a11y: a11y) {
        String(format: "×%.2f", $0)
      }
      interruttore("Più aria fra le righe", \.righeDistanziate,
                   "Righe più distanti, per ritrovare più facilmente quella che stai leggendo.")
      interruttore("Comandi più grandi", \.bersagliGrandi,
                   "Tutto quello che si preme diventa più alto, per prenderlo più facilmente.")
    }
  }

  private var colori: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      titolo("Colori e luce")
      ForEach(ThemeChoice.allCases) { tema in
        ChoiceCard(title: tema.label, subtitle: tema.hint,
                   selected: scelte.theme == tema, a11y: a11y) {
          aggiorna { $0.theme = tema }
        }
      }
      titolo("Come vedi i colori")
      Explain(text: "Ogni esito ha sempre anche un simbolo e una parola, mai soltanto un colore.",
              a11y: a11y)
      ForEach(ColorVision.allCases) { visione in
        ChoiceCard(title: visione.label, selected: scelte.colorVision == visione, a11y: a11y) {
          aggiorna { $0.colorVision = visione }
        }
      }
    }
  }

  private var ritmo: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      titolo("Ritmo e calma")
      InterruttoreAccessibile(
        titolo: "Niente animazioni",
        acceso: a11y.mac.menoMovimento ? .constant(true) : bind(\.reducedMotion),
        a11y: a11y)
        .disabled(a11y.mac.menoMovimento)
      Explain(text: a11y.mac.menoMovimento
              ? "Il dispositivo lo sta già chiedendo. Per cambiare questa scelta usa le sue Impostazioni."
              : "Tutto compare e sparisce senza movimento.", a11y: a11y)
      interruttore("Modalità calma", \.calmMode,
                   "Niente esclamazioni, niente festeggiamenti, tono sempre uguale.")
    }
  }

  private var voce: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      titolo("Voce e ascolto")
      Picker("Voce italiana installata", selection: Binding(
        get: { scelte.voiceIdentifier ?? "" },
        set: { valore in aggiorna { $0.voiceIdentifier = valore.isEmpty ? nil : valore } }
      )) {
        Text("Scegli automaticamente").tag("")
        ForEach(Speaker.italianVoices(), id: \.identifier) { voce in
          Text("\(voce.name), \(Speaker.qualityLabel(voce))").tag(voce.identifier)
        }
        if let scelta = scelte.voiceIdentifier,
           !Speaker.italianVoices().contains(where: { $0.identifier == scelta }) {
          Text("Voce scelta non più disponibile").tag(scelta)
        }
      }.frame(minHeight: a11y.bersaglio)
      PassoAccessibile(titolo: "Velocità della voce", valore: bind(\.voiceRate),
                       intervallo: 0.2...0.6, passo: 0.05, a11y: a11y) {
        String(format: "%.2f", $0)
      }
      Explain(text: "Voce e velocità valgono dalla prossima lettura. Si usano solo le voci già installate.",
              a11y: a11y)
      SmallButton(title: speaker.isSpeaking ? "Ferma la voce" : "Prova la voce",
                  symbol: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2", a11y: a11y) {
        if speaker.isSpeaking { speaker.stop() }
        else {
          speaker.voiceIdentifier = scelte.voiceIdentifier
          speaker.say("Puoi ascoltare una parte del testo e fermarti quando vuoi.",
                      rate: Float(scelte.voiceRate))
        }
      }
    }
  }

  private func titolo(_ testo: String) -> some View {
    SectionTitle(text: testo, a11y: a11y).accessibilityAddTraits(.isHeader)
  }

  private func interruttore(_ testo: String, _ chiave: WritableKeyPath<A11ySettings, Bool>,
                           _ spiegazione: String) -> some View {
    VStack(alignment: .leading, spacing: Metrica.filo) {
      InterruttoreAccessibile(titolo: testo, acceso: bind(chiave), a11y: a11y)
      Explain(text: spiegazione, a11y: a11y)
    }
  }

  private func bind<T>(_ chiave: WritableKeyPath<A11ySettings, T>) -> Binding<T> {
    Binding(get: { scelte[keyPath: chiave] },
            set: { valore in aggiorna { $0[keyPath: chiave] = valore } })
  }

  private func aggiorna(_ modifica: (inout A11ySettings) -> Void) {
    var nuove = scelte
    modifica(&nuove)
    nuove.profile = .nessuno
    scelte = nuove
  }
}
