import SwiftUI
import CoreAudio

/// La striscia in alto durante l'allenamento, uguale in Leggi e in Scrivi.
///
/// I due esercizi chiedono cose diverse — uno la voce, l'altro le dita — ma i
/// comandi che li circondano devono stare nello stesso posto e chiamarsi allo
/// stesso modo: chi si e appena abituato a una schermata non deve reimparare
/// tutto passando all'altra.
///
/// Qui dentro c'e anche la scelta del microfono, e non e un dettaglio: le
/// cuffie si attaccano e si staccano a meta sessione, e prima bisognava uscire
/// dall'allenamento per accorgersene.
struct TrainingBar: View {
  var a11y: A11ySettings
  var palette: Palette
  /// Testo a destra: "parola 3 di 20". Vuoto se non c'e niente da contare.
  var contatore: String = ""
  /// Da quando e cominciato l'allenamento. `nil` = orologio spento.
  var inizio: Date?
  var mostraRiscaldamento = false
  var cambioMicrofonoInCorso = false
  var scegliIngresso: (AudioDeviceID) -> Void
  var onStop: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      StopButton(a11y: a11y, action: onStop)
        .keyboardShortcut(.escape, modifiers: [])

      if mostraRiscaldamento {
        Text("riscaldamento")
          .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
          .padding(.horizontal, 12).padding(.vertical, 5)
          .background(Capsule().fill(palette.accent.opacity(0.22)))
          .foregroundStyle(palette.foreground)
      }

      Spacer()

      if let inizio, a11y.showTimer {
        Cronometro(a11y: a11y, palette: palette, inizio: inizio)
      }

      AudioMenu(a11y: a11y,
                palette: palette,
                scegliIngresso: scegliIngresso,
                inAttesa: cambioMicrofonoInCorso)

      if !contatore.isEmpty {
        Text(contatore)
          .font(a11y.typeface.font(size: a11y.size(16)))
          .foregroundStyle(palette.muted)
          .monospacedDigit()
      }
    }
    .padding(.horizontal, 22)
    .padding(.top, 16)
  }
}

/// Il tempo passato dall'inizio. Non e un conto alla rovescia, e non scade.
///
/// Sale e basta, come un cronometro: nessun numero che si avvicina allo zero,
/// nessun colore che diventa rosso. Chi ha chiesto di vederlo voleva sapere da
/// quanto sta andando, non sentirsi inseguito.
struct Cronometro: View {
  var a11y: A11ySettings
  var palette: Palette
  var inizio: Date

  var body: some View {
    TimelineView(.periodic(from: inizio, by: 1)) { context in
      let secondi = max(0, Int(context.date.timeIntervalSince(inizio)))
      Label(formatta(secondi), systemImage: "clock")
        .font(a11y.typeface.font(size: a11y.size(16)))
        .foregroundStyle(palette.muted)
        .monospacedDigit()
        .accessibilityLabel(descrizione(secondi))
    }
  }

  private func formatta(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
  }

  /// A voce i due punti non si leggono: vanno dette le parole.
  private func descrizione(_ s: Int) -> String {
    let minuti = s / 60
    if minuti == 0 { return "vai da \(s) secondi" }
    return minuti == 1 ? "vai da un minuto" : "vai da \(minuti) minuti"
  }
}
