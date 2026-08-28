import SwiftUI
import AppKit

/// Il riquadro che compare quando c'è una versione nuova da installare.
///
/// Sta in un file suo e non dentro le impostazioni per una ragione pratica: un
/// riquadro che compare solo quando qualcuno pubblica una release è un riquadro
/// che non guarda mai nessuno. Così invece il banco delle schermate lo disegna
/// a ogni verifica, e se un giorno una scritta esce dal bordo o un colore
/// smette di leggersi, si vede prima che lo veda una famiglia.
struct RiquadroAggiornamento: View {
  let release: Updates.Release
  /// Come sta andando l'installazione, se è cominciata.
  let fase: Installazione.Fase
  /// Vero mentre una sessione è in corso: allora non si aggiorna, e si dice
  /// perché. Interrompere una prova a metà per sostituire un programma è la
  /// definizione di un servizio che non ha capito a chi sta servendo.
  let sessioneInCorso: Bool
  /// Vero quando questo Mac può sostituire l'app da solo.
  let puòInstallare: Bool
  let a11y: A11ySettings
  var onAggiorna: () -> Void = {}
  var onPagina: () -> Void = {}

  @Environment(\.palette) private var palette

  private var installabile: Bool { release.packageURL != nil && puòInstallare }

  private var inCorso: Bool {
    switch fase {
    case .scarico, .verifico, .sostituisco: true
    default: false
    }
  }

  @ViewBuilder
  private var pulsanti: some View {
    if installabile {
      SmallButton(title: "Aggiorna e riavvia", symbol: "arrow.down.circle",
                  a11y: a11y, prominente: true, action: onAggiorna)
        .disabled(sessioneInCorso || inCorso)
    }
    SmallButton(title: "Apri la pagina", symbol: "safari", a11y: a11y, action: onPagina)
  }

  var body: some View {    VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) {
      Text("C'è MirrorScopio \(release.version) — tu hai la \(AppVersion.short)")
        .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
        .foregroundStyle(palette.foreground)
        .fixedSize(horizontal: false, vertical: true)

      if !release.notes.isEmpty {
        Text(release.notes)
          .font(a11y.typeface.font(size: a11y.size(14)))
          .foregroundStyle(palette.muted)
          .lineLimit(6)
          .fixedSize(horizontal: false, vertical: true)
      }

      if sessioneInCorso {
        Explain(text: "C'è una sessione in corso: l'aggiornamento aspetta. Sostituire l'app adesso vorrebbe dire interrompere una prova a metà.", a11y: a11y, size: 14)
      } else if release.packageURL == nil {
        Explain(text: "Questa versione non ha un pacchetto che l'app sappia installare da sola: si scarica dalla pagina.", a11y: a11y, size: 14)
      } else if !puòInstallare {
        Explain(text: "MirrorScopio sta in una cartella dove non posso scrivere: per aggiornarsi da solo deve stare nella cartella Applicazioni. Da qui puoi comunque scaricarlo e installarlo a mano.", a11y: a11y, size: 14)
      }

      // A testo ingrandito due pulsanti in riga non ci stanno più, e non è un
      // dettaglio estetico: la riga che non ci sta allarga tutto il riquadro,
      // e allora è il titolo a finire fuori dallo schermo. Quando non entrano
      // si mettono uno sotto l'altro.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Metrica.spazioPiccolo) { pulsanti }
        VStack(alignment: .leading, spacing: Metrica.spazioPiccolo) { pulsanti }
      }

      // Il quanto e il che cosa, sempre e due volte: la barra per chi guarda,
      // la frase per chi ascolta con VoiceOver e per chi da una barra che si
      // riempie non capisce che cosa stia succedendo.
      //
      // La barra è disegnata a mano e non è la `ProgressView` di sistema per
      // due motivi pratici: quella di sistema non compare nelle immagini del
      // banco delle schermate — cioè proprio dove andiamo a guardare se si
      // vede — e non segue i temi, quindi con «Altissimo contrasto» resterebbe
      // del colore di macOS.
      if case .scarico(let quanto) = fase {
        GeometryReader { spazio in
          ZStack(alignment: .leading) {
            Capsule().fill(palette.muted.opacity(0.25))
            Capsule().fill(palette.accent)
              .frame(width: max(4, spazio.size.width * min(1, max(0, quanto))))
          }
        }
        .frame(width: 320, height: a11y.size(10))
        .accessibilityHidden(true)
      }
      if !fase.descrizione.isEmpty {
        Text(fase.descrizione)
          .font(a11y.typeface.font(size: a11y.size(15)))
          .foregroundStyle(palette.muted)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel(fase.descrizione)
      }
    }
    .padding(Metrica.spazio)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: Metrica.raggio)
      .fill(palette.accent.opacity(0.12)))
  }
}
