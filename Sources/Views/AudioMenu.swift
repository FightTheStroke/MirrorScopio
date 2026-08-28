import SwiftUI
import AVFoundation

/// Le cuffie si mettono e si tolgono a meta sessione: e la cosa piu banale del
/// mondo e finora costringeva ad aprire una schermata apposta, o peggio le
/// Impostazioni del Mac. Qui ingresso e uscita stanno in barra, sempre, con
/// scritto quale e attivo adesso — cosi si vede se qualcosa e cambiato senza
/// doverlo cercare.
struct AudioMenu: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var palette: Palette
  /// Come cambiare microfono. Durante un allenamento non basta cambiare
  /// l'ingresso del Mac: l'ascolto va rifatto, e ci pensa chi ci passa questa
  /// funzione.
  var scegliIngresso: (AudioDeviceID) -> Void = { AudioDevices.setDefaultInput($0) }
  /// Assente durante l'allenamento: li non si esce per fare una prova.
  var openAudioCheck: (() -> Void)? = nil
  /// Vero mentre l'ascolto si sta riavviando su un altro microfono.
  var inAttesa = false

  @State private var ingressi: [AudioDevice] = []
  @State private var uscite: [AudioDevice] = []
  @State private var ingressoAttivo: AudioDeviceID?
  @State private var uscitaAttiva: AudioDeviceID?

  /// Il nome del microfono lo legge `leggi()` ogni tre secondi, non il corpo
  /// della vista: chiedere a CoreAudio a ogni ridisegno era una domanda di
  /// sistema dentro un ciclo di disegno, e la risposta cambia due volte al
  /// giorno.
  private var etichetta: String {
    if let id = ingressoAttivo, let d = ingressi.first(where: { $0.id == id }) { return d.name }
    return "Audio"
  }

  @State private var aperto = false

  var body: some View {
    Button { aperto.toggle() } label: {
      HStack(spacing: Metrica.spazioMinimo) {
        Image(systemName: inAttesa ? "hourglass" : "headphones")
        Text(inAttesa ? "cambio microfono…" : etichetta)
          .font(a11y.font(.etichetta))
          .lineLimit(1)
        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
      }
      .padding(.horizontal, Metrica.spazioPiccolo)
      .frame(minHeight: a11y.bersaglio)
      .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
    }
    // Perche' non e' piu' un `Menu`.
    //
    // Su macOS un `Menu` si fa dare l'altezza dal controllo AppKit che ha
    // sotto, e nessun `frame` scritto in SwiftUI la sposta. Misurato sull'app
    // in esecuzione, non dedotto: 19 punti con lo stile senza bordo, 24 con
    // `.accessoryBar`, di nuovo 19 con `.plain`. I 44 punti promessi non
    // arrivavano da nessuna parte, e le voci **dentro** il menu avevano lo
    // stesso difetto un piano piu' sotto.
    //
    // Un pulsante normale con un pannello a comparsa e' fatto tutto di viste
    // nostre: l'altezza e' quella che scriviamo, qui e in ogni riga dell'elenco.
    .buttonStyle(.plain)
    .foregroundStyle(palette.muted)
    .popover(isPresented: $aperto, arrowEdge: .bottom) {
      PannelloAudio(a11y: a11y, palette: palette,
                    ingressi: ingressi, uscite: uscite,
                    ingressoAttivo: ingressoAttivo, uscitaAttiva: uscitaAttiva,
                    scegliIngresso: { scegliIngresso($0); leggi() },
                    scegliUscita: { _ = AudioDevices.setDefaultOutput($0); leggi() },
                    openAudioCheck: openAudioCheck.map { azione in { aperto = false; azione() } })
    }
    .help("Scegli microfono e altoparlanti, o fai una prova")
    .accessibilityLabel(inAttesa
      ? "Sto passando all'altro microfono"
      : "Audio. Adesso ti sento da \(etichetta)")
    .accessibilityHint("Apre l'elenco dei microfoni e degli altoparlanti")
    .onAppear(perform: leggi)
    // Le cuffie si attaccano mentre l'app e aperta: l'elenco va riletto,
    // altrimenti mostra un mondo che non esiste piu.
    .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in leggi() }
  }

  private func leggi() {
    ingressi = AudioDevices.inputs()
    uscite = AudioDevices.outputs()
    ingressoAttivo = AudioDevices.defaultInput()
    uscitaAttiva = AudioDevices.defaultOutput()
  }
}

/// L'elenco che si apre sotto il pulsante.
///
/// Ogni riga e' alta quanto un bersaglio intero, e dice a parole se e' quella
/// attiva: il segno di spunta da solo e' un simbolo, e un simbolo da solo non
/// basta a chi usa VoiceOver.
private struct PannelloAudio: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var palette: Palette
  var ingressi: [AudioDevice]
  var uscite: [AudioDevice]
  var ingressoAttivo: AudioDeviceID?
  var uscitaAttiva: AudioDeviceID?
  var scegliIngresso: (AudioDeviceID) -> Void
  var scegliUscita: (AudioDeviceID) -> Void
  var openAudioCheck: (() -> Void)?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
        gruppo("Microfono — da dove ti sento", ingressi, attivo: ingressoAttivo, scegli: scegliIngresso)
        gruppo("Altoparlanti — da dove esce la voce", uscite, attivo: uscitaAttiva, scegli: scegliUscita)
        if let openAudioCheck {
          Divider()
          riga(testo: "Prova microfono e voce…", simbolo: "waveform.badge.mic",
               attiva: false, etichettaVoce: "Prova microfono e voce", azione: openAudioCheck)
        }
      }
      .padding(Metrica.spazioMedio)
    }
    .frame(minWidth: 320, maxHeight: 460)
    .background(palette.surface)
  }

  @ViewBuilder
  private func gruppo(_ titolo: String, _ elenco: [AudioDevice],
                      attivo: AudioDeviceID?, scegli: @escaping (AudioDeviceID) -> Void) -> some View {
    VStack(alignment: .leading, spacing: Metrica.briciola) {
      Text(titolo)
        .font(a11y.font(.etichetta, .semibold))
        .foregroundStyle(palette.muted)
        .fixedSize(horizontal: false, vertical: true)
      if elenco.isEmpty {
        // Un elenco vuoto senza una parola sopra sembra un difetto dell'app.
        Text("Nessuno collegato.")
          .font(a11y.font(.etichetta))
          .foregroundStyle(palette.muted)
          .frame(minHeight: a11y.bersaglio, alignment: .leading)
      }
      ForEach(elenco) { d in
        riga(testo: d.name,
             simbolo: d.id == attivo ? "checkmark.circle.fill" : "circle",
             attiva: d.id == attivo,
             etichettaVoce: d.id == attivo ? "\(d.name), in uso adesso" : d.name,
             azione: { scegli(d.id) })
      }
    }
  }

  private func riga(testo: String, simbolo: String, attiva: Bool,
                    etichettaVoce: String, azione: @escaping () -> Void) -> some View {
    Button(action: azione) {
      HStack(spacing: Metrica.spazioStretto) {
        Image(systemName: simbolo)
          .foregroundStyle(attiva ? palette.accent : palette.muted)
        Text(testo)
          .font(a11y.font(.etichetta, attiva ? .semibold : .regular))
          .foregroundStyle(palette.foreground)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, Metrica.spazioStretto)
      .frame(maxWidth: .infinity, minHeight: a11y.bersaglio, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
        .fill(attiva ? palette.accent.opacity(0.12) : .clear))
      .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(etichettaVoce)
  }
}
