import SwiftUI
import AVFoundation

/// Prova del microfono e dell'audio.
///
/// Nasce da un guasto reale: "non mi riconosce nessuna parola anche se so di
/// dirla bene". Senza un posto dove *vedere* se il microfono sente, non c'è modo
/// di distinguere fra microfono muto, ingresso sbagliato e riconoscimento rotto.
/// Qui si vedono tutti e tre.
@MainActor
final class AudioCheck: ObservableObject {
  @Published var level: Float = 0
  @Published var peak: Float = 0
  @Published var transcript = ""
  /// Il riconoscitore ha già consegnato qualcosa almeno una volta.
  @Published var caldo = false
  @Published var primaRispostaSec: Double?
  /// Ultimo istante di voce per cui è già stata chiesta la consegna: evita di
  /// richiederla cinquanta volte al secondo sullo stesso silenzio.
  private var voceGiaChiesta: CFTimeInterval?
  @Published var heardWords: [String] = []
  @Published var running = false
  @Published var error: String?

  @Published var inputs: [AudioDevice] = []
  @Published var outputs: [AudioDevice] = []
  @Published var selectedInput: AudioDeviceID?
  @Published var selectedOutput: AudioDeviceID?
  @Published var outputWarning: String?

  private let listener = SpeechListener()
  private let speaker = AVSpeechSynthesizer()
  private var poll: Task<Void, Never>?

  /// Le parole di prova: comuni, corte, e polarizzano il riconoscitore.
  static let testWords = ["ciao", "cane", "casa", "sole", "farfalla", "tavolo"]

  func refreshDevices() {
    inputs = AudioDevices.inputs()
    outputs = AudioDevices.outputs()
    if selectedInput == nil { selectedInput = AudioDevices.defaultInput() }
    if selectedOutput == nil { selectedOutput = AudioDevices.defaultOutput() }
    checkOutput()
  }

  func checkOutput() {
    guard let out = selectedOutput ?? AudioDevices.defaultOutput() else {
      outputWarning = "Nessun altoparlante disponibile."
      return
    }
    if AudioDevices.isOutputMuted(out) {
      outputWarning = "L'audio è in muto: alza il volume per sentire le parole."
    } else if let v = AudioDevices.outputVolume(out), v < 0.08 {
      outputWarning = "Il volume è quasi a zero: alzalo per sentire le parole."
    } else {
      outputWarning = nil
    }
  }

  func start() {
    guard !running else { return }
    error = nil
    transcript = ""
    heardWords = []
    caldo = false
    primaRispostaSec = nil
    peak = 0
    refreshDevices()

    Task {
      guard await SpeechListener.requestPermissions() else {
        self.error = "Il permesso per il microfono o per il riconoscimento vocale è negato. Aprilo in Impostazioni di Sistema › Privacy e sicurezza."
        return
      }
      do {
        try await listener.start(locale: Locale(identifier: "it_IT"),
                                 vocabulary: Self.testWords,
                                 preferredInput: selectedInput)
        // Qui non c'è nessuna prova in corso: è la schermata «Mi senti?», che
        // ascolta e basta. Zero è l'identificativo di questa finestra unica,
        // e nessuna prova vera userà mai quel numero.
        listener.beginWindow(trialID: 0)
        self.running = true
        self.startPolling()
      } catch {
        self.error = error.localizedDescription
      }
    }
  }

  func stop() {
    poll?.cancel()
    poll = nil
    running = false
    listener.endWindow()
    Task { await listener.stop() }
  }

  /// Fa dire una parola all'altoparlante: verifica l'uscita senza dover parlare.
  func speakSample() {
    let u = AVSpeechUtterance(string: "Ciao, mi senti?")
    u.voice = AVSpeechSynthesisVoice(language: "it-IT")
    u.rate = 0.44
    u.volume = 1.0
    speaker.speak(u)
  }

  private func startPolling() {
    poll = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(50))
        guard let self, self.running else { continue }
        let snap = self.listener.read()
        self.level = snap.level
        self.caldo = snap.caldo
        self.primaRispostaSec = snap.primaRispostaSec
        self.peak = max(self.peak, snap.level)

        // Qui stava la lentezza di «Mi senti?».
        //
        // L'analizzatore non consegna niente finché non gli si chiede: da solo
        // aspetta molto più audio prima di dire la sua, ed è il guasto che
        // rendeva l'app sorda, già risolto dentro la sessione ma mai qui. In
        // questa schermata nessuno glielo chiedeva mai, quindi le parole
        // comparivano dopo un'attesa lunghissima — e chi provava il microfono
        // concludeva che era il proprio modo di parlare a non andare bene.
        // Adesso si chiede la consegna appena la voce si ferma, come nella
        // sessione vera: ~250 ms di silenzio dopo aver parlato.
        if let ultimaVoce = snap.lastVoice {
          let fermo = CACurrentMediaTime() - ultimaVoce
          if fermo >= 0.25, ultimaVoce != self.voceGiaChiesta {
            self.voceGiaChiesta = ultimaVoce
            await self.listener.flush()
          }
        }

        let text = snap.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, text != self.transcript {
          self.transcript = text
          // Ogni tanto la finestra si chiude e riparte: teniamo la scia.
          if let last = text.split(separator: " ").last.map(String.init),
             self.heardWords.last != last {
            self.heardWords.append(last)
            if self.heardWords.count > 8 { self.heardWords.removeFirst() }
          }
        }
      }
    }
  }

  /// Il giudizio in una frase, senza gergo.
  ///
  /// L'ordine dei casi non è casuale. Finché il modello vocale non si è
  /// caricato, l'app non è in grado di capire niente e deve dirlo: prima
  /// scriveva "ti sento ma non ho capito nessuna parola" anche in quei
  /// secondi, cioè dava la colpa a chi stava parlando di un ritardo tutto suo.
  var verdict: (text: String, symbol: String, good: Bool)? {
    guard running else { return nil }
    if !transcript.isEmpty {
      return ("Ti sento e ti capisco.", "checkmark.circle.fill", true)
    }
    if !caldo {
      return ("Sto ancora preparando l'ascolto. Ci vuole qualche secondo la prima volta.", "hourglass", false)
    }
    if peak > 0.02 {
      return ("Ti sento, ma non ho ancora capito nessuna parola. Prova a dire «ciao».", "ear", false)
    }
    return ("Non sento ancora niente. Parla vicino al Mac.", "waveform", false)
  }

  /// Quanto ci ha messo il modello a svegliarsi, detto solo quando è tanto:
  /// sotto il secondo è un dato da tecnici e non interessa nessuno.
  var notaLentezza: String? {
    guard let t = primaRispostaSec, t >= 1.5 else { return nil }
    return String(format: "L'ascolto si è preparato in %.1f secondi. È il caricamento del modello vocale: succede una volta per sessione, poi le risposte sono immediate.", t)
  }
}

struct AudioCheckView: View {
  @ObservedObject var store: Store
  var onClose: () -> Void

  @StateObject private var check = AudioCheck()
  @Environment(\.palette) private var pal
  @State private var showAdult = false

  private var a11y: A11ySettings { store.current.a11y }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Metrica.margine) {
        header
        meter
        heard
        if let e = check.error { problem(e) }
        if let w = check.outputWarning { problem(w) }
        // Questa e' la schermata dove uno viene a capire perche' l'app non lo
        // capisce. Se il picco resta sotto la soglia in cui il riconoscitore
        // consegna qualcosa, dirlo qui evita mezz'ora di prove.
        if check.peak > 0.004, check.peak < 0.04, check.transcript.isEmpty {
          problem("Ti sento, ma pianissimo: a questo volume il Mac non arriva a capire le parole. Avvicinati al microfono, o scegline un altro qui sopra.")
        }
        speakerTest
        adultSection
      }
      .padding(Metrica.spazioGrande)
      .frame(maxWidth: 820)
      .frame(maxWidth: .infinity)
    }
    .background(pal.background)
    .foregroundStyle(pal.foreground)
    .onAppear { check.refreshDevices(); check.start() }
    .onDisappear { check.stop() }
  }

  private var header: some View {
    IntestazionePagina(titolo: "Mi senti?",
                       sottotitolo: "Di' **ciao** ad alta voce e guarda la barra qui sotto.",
                       a11y: a11y) {
      check.stop()
      onClose()
    }
  }

  /// La barra del livello: grande, e con una tacca che segna il punto in cui
  /// il riconoscimento comincia a funzionare, così "abbastanza forte" è visibile.
  private var meter: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: Metrica.raggio).fill(pal.surface)
          RoundedRectangle(cornerRadius: Metrica.raggio)
            .fill(check.level > 0.02 ? pal.ok : pal.accent)
            .frame(width: max(8, min(1, CGFloat(check.level) * 14) * geo.size.width))
            .animation(a11y.animation(0.08), value: check.level)
          Rectangle()
            .fill(pal.foreground.opacity(0.35))
            .frame(width: 3)
            .offset(x: geo.size.width * 0.14)
        }
      }
      .frame(height: 74)
      .accessibilityElement()
      .accessibilityLabel("Livello del microfono")
      .accessibilityValue(check.level > 0.02 ? "ti sento" : "silenzio")

      if let v = check.verdict {
        HStack(spacing: Metrica.spazioPiccolo) {
          Image(systemName: v.symbol)
            .font(.system(size: a11y.size(26)))
            .foregroundStyle(v.good ? pal.ok : pal.muted)
          Text(v.text)
            .font(a11y.font(.guida, .semibold))
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if let nota = check.notaLentezza {
        Text(nota)
          .font(a11y.font(.etichetta))
          .foregroundStyle(pal.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var heard: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
      Text("Quello che ho capito")
        .font(a11y.font(.etichetta))
        .foregroundStyle(pal.muted)
      Text(check.transcript.isEmpty ? "…" : check.transcript)
        .font(a11y.font(.titolo, .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrica.spazio)
        .background(pal.surface, in: .rect(cornerRadius: Metrica.raggio))
        .animation(a11y.animation(), value: check.transcript)
    }
  }

  private var speakerTest: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
      Text("E gli altoparlanti?")
        .font(a11y.font(.guida, .semibold))
      Button(action: { check.speakSample() }) {
        Label("Fammi dire una frase", systemImage: "speaker.wave.2.fill")
          .font(a11y.font(.corpo, .semibold))
          .padding(.horizontal, Metrica.spazio).padding(.vertical, Metrica.spazioMedio)
      }
      .buttonStyle(.plain)
      .background(pal.surface, in: .rect(cornerRadius: Metrica.raggio))
      .frame(minHeight: 44)
      Text("Serve per la modalità Scrivi, dove è il Mac a dire la parola.")
        .font(a11y.font(.nota))
        .foregroundStyle(pal.muted)
    }
  }

  private func problem(_ text: String) -> some View {
    HStack(alignment: .top, spacing: Metrica.spazioPiccolo) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: a11y.size(20)))
        .foregroundStyle(pal.wrong)
        .accessibilityHidden(true)
      Text(text)
        .font(a11y.font(.etichetta))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(Metrica.spazioMedio)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(pal.wrong.opacity(0.12), in: .rect(cornerRadius: Metrica.raggio))
  }

  private var adultSection: some View {
    DisclosureGroup(isExpanded: $showAdult) {
      VStack(alignment: .leading, spacing: Metrica.spazioMedio) {
        Picker("Microfono", selection: Binding(
          get: { check.selectedInput ?? AudioDeviceID(0) },
          set: { check.selectedInput = $0; check.stop(); check.start() })) {
          ForEach(check.inputs) { d in Text(d.name).tag(d.id) }
        }

        Picker("Altoparlanti", selection: Binding(
          get: { check.selectedOutput ?? AudioDeviceID(0) },
          set: { check.selectedOutput = $0; check.checkOutput() })) {
          ForEach(check.outputs) { d in Text(d.name).tag(d.id) }
        }

        HStack(spacing: Metrica.spazio) {
          Text("livello ora: \(String(format: "%.4f", check.level))")
          Text("picco: \(String(format: "%.4f", check.peak))")
        }
        .font(.system(size: a11y.size(12)).monospacedDigit())
        .foregroundStyle(pal.muted)

        SmallButton(title: "Aggiorna l'elenco dei dispositivi",
                    symbol: "arrow.clockwise", a11y: a11y) { check.refreshDevices() }

        Text("La scelta del microfono vale per questa app. Il riconoscimento avviene interamente su questo Mac.")
          .font(a11y.font(.nota))
          .foregroundStyle(pal.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, Metrica.spazioPiccolo)
    } label: {
      Label("Scegli microfono e altoparlanti", systemImage: "slider.horizontal.3")
        .font(a11y.font(.corpo, .semibold))
    }
    .padding(Metrica.spazio)
    .background(pal.surface, in: .rect(cornerRadius: Metrica.raggioGrande))
  }
}
