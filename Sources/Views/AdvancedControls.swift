import SwiftUI

/// I parametri clinici: millesimi di secondo, maschera, scala adattiva.
///
/// Stavano dietro un pulsante in home, accanto a "Via!", dove il ragazzo li
/// trovava prima del logopedista. Adesso sono l'ultima pagina delle
/// Impostazioni, insieme a tutto il resto che si regola una volta e non si
/// tocca piu: due porte diverse per la stessa cosa erano solo un modo per
/// perdersi.
/// Questa pagina la guarda un adulto, e per un po' e' stata l'unica a non
/// rispettare il tema, il carattere e l'ingrandimento scelti nelle
/// impostazioni: testo di sistema, grigio `.secondary`, taglia fissa. Ma il
/// genitore o il logopedista che alza «Dimensione di tutto» a 1,8 lo fa
/// perche' vede poco lui, non perche' vede poco il ragazzo — e proprio qui
/// non gli veniva applicato niente. Chi accompagna ha le stesse esigenze di
/// chi e' accompagnato.
struct AdvancedControls: View {
  @Environment(\.palette) private var palette
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  var a11y: EffettiveImpostazioniAccessibilita

  private var corpo: Font { a11y.font(.etichetta) }

  var body: some View {
      Form {
        Section("Stimoli") {
          SceltaAccessibile(titolo: "Lista", scelta: $engine.config.set,
                            opzioni: StimulusSet.allCases, a11y: a11y) { $0.label }
          if engine.config.set == .personalizzata {
            VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
              Text("Una parola per riga.").font(corpo).foregroundStyle(palette.muted)
              TextEditor(text: $engine.config.customList)
                .font(.system(size: a11y.size(14), design: .monospaced))
                .frame(height: 110)
            }
          }
          if !engine.config.set.isReliableForASR {
            note("Le non-parole non esistono nel vocabolario del riconoscitore: su questa lista il punteggio automatico è indicativo. In modalità Scrivi invece è affidabile.")
          }
          InterruttoreAccessibile(titolo: "Ordine casuale", acceso: $engine.config.shuffle, a11y: a11y)
          InterruttoreAccessibile(titolo: "Tutto MAIUSCOLO", acceso: $engine.config.uppercase, a11y: a11y)
          PassoAccessibile(titolo: "Numero di parole",
                           valore: Binding(get: { Double(engine.config.trials) },
                                           set: { engine.config.trials = Int($0) }),
                           intervallo: 1...200, a11y: a11y) { "Numero di parole: \(Int($0))" }
          PassoAccessibile(titolo: "Parole di riscaldamento",
                           valore: Binding(get: { Double(engine.config.warmupTrials) },
                                           set: { engine.config.warmupTrials = Int($0) }),
                           intervallo: 0...10, a11y: a11y) { "Parole di riscaldamento: \(Int($0))" }
        }

        Section("Tempi") {
          slider("Quanto resta visibile la parola", $engine.config.exposureMs, 16...1000, unit: "ms")
          SceltaAccessibile(titolo: "Come cambia il tempo", scelta: $engine.config.staircase,
                            opzioni: Staircase.allCases, a11y: a11y) { $0.label }
          if engine.config.staircase != .fixed {
            slider("Di quanto cambia ogni volta", $engine.config.stepMs, 5...100, unit: "ms")
          }
          slider("Croce prima della parola", $engine.config.fixationMs, 0...2000, unit: "ms")
          slider("Pausa fra una parola e l'altra", $engine.config.interTrialMs, 0...3000, unit: "ms")
        }

        Section("Maschera") {
          note("La maschera copre la parola subito dopo, così non la si continua a \"vedere\" nella memoria visiva: senza, si misura la memoria e non la lettura.")
          SceltaAccessibile(titolo: "Maschera", scelta: $engine.config.maskMode,
                            opzioni: MaskMode.allCases, a11y: a11y) { $0.label }
          if engine.config.maskMode != .none {
            slider("Durata della maschera", $engine.config.maskMs, 0...1000, unit: "ms")
          }
        }

        Section("Ascolto") {
          slider("Quanto aspetta la risposta", $engine.config.responseTimeoutMs, 1000...10000, unit: "ms")
          slider("Silenzio che chiude la risposta", $engine.config.endpointSilenceMs, 200...2000, unit: "ms")
          InterruttoreAccessibile(titolo: "Analisi degli errori con il modello Apple sul dispositivo",
                                  acceso: $engine.config.useAppleIntelligence, a11y: a11y)
          if case .unavailable(let reason) = Intelligence.state { note(reason) }
        }
      }
      .formStyle(.grouped)
      .font(corpo)
      .foregroundStyle(palette.foreground)
      .frame(minHeight: 620)
      .onDisappear {
        var l = store.current
        l.config = engine.config
        store.current = l
      }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(a11y.font(.nota))
      .foregroundStyle(palette.muted)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func slider(_ title: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>, unit: String) -> some View {
    // Il nome e il valore letti a voce sono quelli che l'app mostra accanto:
    // senza, VoiceOver direbbe "cursore, 50 per cento", che non e' ne' di che
    // cosa si tratta ne' il numero scritto sullo schermo.
    CursoreAccessibile(titolo: title, valore: value, intervallo: range,
                       passo: max(1, (range.upperBound - range.lowerBound) / 40),
                       a11y: a11y) { "\(Int($0)) \(unit)" }
  }
}
