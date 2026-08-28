import SwiftUI
import AVFoundation

/// Le cuffie si mettono e si tolgono a meta sessione: e la cosa piu banale del
/// mondo e finora costringeva ad aprire una schermata apposta, o peggio le
/// Impostazioni del Mac. Qui ingresso e uscita stanno in barra, sempre, con
/// scritto quale e attivo adesso — cosi si vede se qualcosa e cambiato senza
/// doverlo cercare.
struct AudioMenu: View {
  var a11y: A11ySettings
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

  var body: some View {
    Menu {
      Section("Microfono — da dove ti sento") {
        ForEach(ingressi) { d in
          Button {
            scegliIngresso(d.id)
            leggi()
          } label: {
            Label(d.name, systemImage: d.id == ingressoAttivo ? "checkmark" : "circle")
          }
        }
      }
      Section("Altoparlanti — da dove esce la voce") {
        ForEach(uscite) { d in
          Button {
            _ = AudioDevices.setDefaultOutput(d.id)
            leggi()
          } label: {
            Label(d.name, systemImage: d.id == uscitaAttiva ? "checkmark" : "circle")
          }
        }
      }
      if let openAudioCheck {
        Divider()
        Button("Prova microfono e voce…", systemImage: "waveform.badge.mic", action: openAudioCheck)
      }
    } label: {
      HStack(spacing: 7) {
        Image(systemName: inAttesa ? "hourglass" : "headphones")
        Text(inAttesa ? "cambio microfono…" : etichetta)
          .font(a11y.typeface.font(size: a11y.size(15)))
          .lineLimit(1)
      }
      .frame(minHeight: 44)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .foregroundStyle(palette.muted)
    .help("Scegli microfono e altoparlanti, o fai una prova")
    .accessibilityLabel(inAttesa
      ? "Sto passando all'altro microfono"
      : "Audio. Adesso ti sento da \(etichetta)")
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
