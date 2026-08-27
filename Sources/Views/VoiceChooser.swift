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

  private var a11y: A11ySettings { store.current.a11y }

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
      VStack(alignment: .leading, spacing: 10) {
        Divider().padding(.vertical, 4)
        Text(ItalianVoices.haUnaVoceBuona
             ? "Su questo Mac si possono aggiungere anche queste"
             : "Le voci di serie vanno bene. Queste si capiscono meglio")
          .font(a11y.typeface.font(size: a11y.size(18), weight: .semibold))
          .foregroundStyle(palette.foreground)

        ForEach(mancanti.prefix(4), id: \.nome) { v in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(palette.muted)
            VStack(alignment: .leading, spacing: 2) {
              Text(v.nome)
                .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
                .foregroundStyle(palette.foreground)
              Text(v.descrizione)
                .font(a11y.typeface.font(size: a11y.size(15)))
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
    VStack(alignment: .leading, spacing: a11y.size(14)) {
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
        VStack(alignment: .leading, spacing: 6) {
          Text("Velocità della voce")
            .font(a11y.typeface.font(size: a11y.size(19), weight: .semibold))
            .foregroundStyle(palette.foreground)
          HStack(spacing: 12) {
            Image(systemName: "tortoise.fill").foregroundStyle(palette.muted)
              .accessibilityHidden(true)
            Slider(value: Binding(get: { a11y.voiceRate },
                                  set: { v in store.update { $0.a11y.voiceRate = v } }),
                   in: 0.30...0.60)
              .accessibilityLabel("Velocita' della voce")
              .accessibilityValue(a11y.voiceRate < 0.40 ? "lenta"
                                  : a11y.voiceRate < 0.50 ? "normale" : "veloce")
            Image(systemName: "hare.fill").foregroundStyle(palette.muted)
              .accessibilityHidden(true)
          }
          Explain(text: "Più a sinistra, più lenta. Per chi legge con fatica, lenta è meglio.",
                  a11y: a11y, size: 16)
        }
        .padding(.top, 6)
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
    HStack(spacing: 14) {
      Button {
        store.update { $0.a11y.voiceIdentifier = voce.identifier }
        prova(voce)
      } label: {
        HStack(spacing: 12) {
          Image(systemName: scelta ? "largecircle.fill.circle" : "circle")
            .font(.system(size: a11y.size(22)))
            .foregroundStyle(scelta ? palette.accent : palette.muted)
          VStack(alignment: .leading, spacing: 2) {
            Text(voce.name)
              .font(a11y.typeface.font(size: a11y.size(21), weight: scelta ? .bold : .regular))
              .foregroundStyle(palette.foreground)
            Text(Speaker.qualityLabel(voce))
              .font(a11y.typeface.font(size: a11y.size(15)))
              .foregroundStyle(palette.muted)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button {
        prova(voce)
      } label: {
        Image(systemName: inProva == voce.identifier ? "speaker.wave.3.fill" : "play.fill")
          .font(.system(size: a11y.size(20)))
          .frame(width: a11y.size(46), height: a11y.size(40))
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Ascolta \(voce.name)")
    }
    .padding(.vertical, 4)
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
