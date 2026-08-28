import AVFoundation
import AppKit
import SwiftUI

/// Scelta della voce, dentro l'app e con l'orecchio.
///
/// Nessuna app può installare le voci di Apple — non esiste un modo previsto
/// per farlo — ma può fare tutto il resto: mostrare quelle che ci sono, farle
/// ascoltare e lasciar scegliere. Chi usa MirrorScopio sceglie la voce che
/// capisce meglio sentendola, non leggendo il nome di un file.
struct VoiceChooser: View {
  @Environment(\.palette) private var palette
  @ObservedObject var store: Store
  /// Mostra anche la velocità di lettura.
  var showsRate = true

  @State private var voci: [AVSpeechSynthesisVoice] = []
  @State private var inProva: String?
  @State private var synth = AVSpeechSynthesizer()

  @Environment(\.impostazioni) private var a11y

  private var sceltaCorrente: String? {
    a11y.voiceIdentifier ?? Speaker.bestItalianVoice?.identifier
  }

  /// L'elenco delle voci italiane che su questo Mac non ci sono.
  ///
  /// Un elenco corto non dice se e corto perche il Mac ne ha poche o perche
  /// l'app ne mostra poche. Qui si vede l'una e l'altra cosa, con i nomi
  /// esatti che compaiono in Impostazioni di Sistema: senza, aggiungere una
  /// voce vuol dire cercare a tentoni in una lista di duecento nomi.
  @ViewBuilder
  private var vociMancanti: some View {
    let mancanti = ItalianVoices.mancanti()
    if !mancanti.isEmpty {
      VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
        Divider().padding(.vertical, Metrica.briciola)
        Text(ItalianVoices.haUnaVoceBuona
             ? "Su questo Mac si possono aggiungere anche queste"
             : "Le voci di serie vanno bene. Queste si capiscono meglio")
          .font(a11y.font(.corpo, .semibold))
          .foregroundStyle(palette.foreground)

        ForEach(mancanti.prefix(4), id: \.nome) { v in
          HStack(alignment: .firstTextBaseline, spacing: Metrica.spazioStretto) {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(palette.muted)
            VStack(alignment: .leading, spacing: Metrica.filo) {
              Text(v.nome)
                .font(a11y.font(.corpo, .semibold))
                .foregroundStyle(palette.foreground)
              Text(v.descrizione)
                .font(a11y.font(.etichetta))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }

        Explain(text: "macOS non lascia a nessuna app il permesso di scaricarle: una voce pesa centinaia di megabyte e la scelta resta di chi possiede il Mac. Il pulsante qui sotto apre la pagina esatta — **Voce di sistema › Gestisci voci › Italiano** — e quando torni la voce nuova compare qui da sola.", a11y: a11y, size: 15)

        SmallButton(title: "Apri la pagina delle voci", symbol: "arrow.up.forward.app",
                    a11y: a11y) {
          if let u = URL(string: Readiness.urlImpostazioniVoci) { NSWorkspace.shared.open(u) }
        }
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioPiccolo)) {
      SectionTitle(text: "La voce che legge", a11y: a11y)
      Explain(text: "Premi ▶︎ per sentirla. Scegli quella che si capisce meglio.", a11y: a11y)

      if voci.isEmpty {
        Explain(text: "Nessuna voce italiana trovata su questo Mac.", a11y: a11y)
      }

      ForEach(voci, id: \.identifier) { voce in
        riga(voce)
      }

      vociMancanti

      if showsRate {
        VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
          HStack(spacing: Metrica.spazioPiccolo) {
            Image(systemName: "tortoise.fill").foregroundStyle(palette.muted)
              .accessibilityHidden(true)
            CursoreAccessibile(titolo: "Velocità della voce",
                               valore: Binding(get: { a11y.voiceRate },
                                               set: { v in store.update { $0.a11y.voiceRate = v } }),
                               intervallo: 0.30...0.60, passo: 0.01, a11y: a11y) { v in
              v < 0.40 ? "lenta" : v < 0.50 ? "media" : "veloce"
            }
            Image(systemName: "hare.fill").foregroundStyle(palette.muted)
              .accessibilityHidden(true)
          }
          Explain(text: "Più a sinistra, più lenta. Per chi legge con fatica, lenta è meglio.",
                  a11y: a11y, size: 16)
        }
        .padding(.top, Metrica.spazioMinimo)
      }
    }
    // Ricaricate a ogni comparsa: una voce può essere stata scaricata mentre
    // l'app era già aperta.
    .onAppear { carica() }
    // Si esce dall'app per aggiungere una voce e si rientra: se l'elenco non
    // si rilegge, la voce appena scaricata sembra non essere arrivata.
    .onReceive(NotificationCenter.default.publisher(
      for: NSApplication.didBecomeActiveNotification)) { _ in carica() }
  }

  @ViewBuilder
  private func riga(_ voce: AVSpeechSynthesisVoice) -> some View {
    let scelta = voce.identifier == sceltaCorrente
    HStack(spacing: Metrica.spazioPiccolo) {
      Button {
        store.update { $0.a11y.voiceIdentifier = voce.identifier }
        prova(voce)
      } label: {
        HStack(spacing: Metrica.spazioPiccolo) {
          Image(systemName: scelta ? "largecircle.fill.circle" : "circle")
            .font(.system(size: a11y.size(22)))
            .foregroundStyle(scelta ? palette.accent : palette.muted)
          VStack(alignment: .leading, spacing: Metrica.filo) {
            Text(voce.name)
              .font(a11y.font(.guida, scelta ? .bold : .regular))
              .foregroundStyle(palette.foreground)
            Text(Speaker.qualityLabel(voce))
              .font(a11y.font(.etichetta))
              .foregroundStyle(palette.muted)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggio), a11y: a11y))

      // Era alto 40 punti e in stile di sistema. Quaranta e' sotto il minimo
      // di Apple, e questo e' proprio il tasto con cui si sceglie la voce che
      // si capisce meglio: chi ha difficolta' di mira non deve mancarlo.
      SmallButton(title: "Ascolta",
                  symbol: inProva == voce.identifier ? "speaker.wave.3.fill" : "play.fill",
                  a11y: a11y) { prova(voce) }
        .accessibilityLabel("Ascolta \(voce.name)")
    }
    .padding(.vertical, Metrica.briciola)
  }

  private func prova(_ voce: AVSpeechSynthesisVoice) {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    let u = AVSpeechUtterance(string: "Ciao, sono \(voce.name). Leggiamo insieme: farfalla.")
    u.voice = voce
    u.rate = Float(a11y.voiceRate)
    inProva = voce.identifier
    synth.speak(u)
    Task {
      try? await Task.sleep(for: .seconds(3))
      if inProva == voce.identifier { inProva = nil }
    }
  }

  private func carica() {
    voci = Speaker.italianVoices()
  }
}
