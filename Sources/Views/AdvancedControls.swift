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
  var a11y: A11ySettings

  private var corpo: Font { a11y.font(.etichetta) }

  var body: some View {
      Form {
        Section("Stimoli") {
          Picker("Lista", selection: $engine.config.set) {
            ForEach(StimulusSet.allCases) { Text($0.label).tag($0) }
          }
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
          Toggle("Ordine casuale", isOn: $engine.config.shuffle)
          Toggle("Tutto MAIUSCOLO", isOn: $engine.config.uppercase)
          Stepper("Numero di parole: \(engine.config.trials)", value: $engine.config.trials, in: 1...200)
          Stepper("Parole di riscaldamento: \(engine.config.warmupTrials)",
                  value: $engine.config.warmupTrials, in: 0...10)
        }

        Section("Tempi") {
          slider("Quanto resta visibile la parola", $engine.config.exposureMs, 16...1000, unit: "ms")
          Picker("Come cambia il tempo", selection: $engine.config.staircase) {
            ForEach(Staircase.allCases) { Text($0.label).tag($0) }
          }
          if engine.config.staircase != .fixed {
            slider("Di quanto cambia ogni volta", $engine.config.stepMs, 5...100, unit: "ms")
          }
          slider("Croce prima della parola", $engine.config.fixationMs, 0...2000, unit: "ms")
          slider("Pausa fra una parola e l'altra", $engine.config.interTrialMs, 0...3000, unit: "ms")

          // Se l'app sa che questi tempi faranno lampeggiare lo schermo troppo
          // in fretta, lo dice qui, adesso — non quando il ragazzo preme «Via!»
          // e si trova davanti un rifiuto che non capisce.
          if engine.config.oltreIlLimiteDiLampeggio {
            Label {
              Text("Con questi tempi lo schermo cambierebbe \(engine.config.ritmoDaDireHz, specifier: "%.1f") volte al secondo. Sopra tre volte al secondo un'alternanza così può far male a chi ha un'epilessia fotosensibile: allunga la pausa o la croce finché il giro completo dura almeno \(Int(SessionConfig.durataCicloMinimaMs.rounded())) millesimi.")
            } icon: {
              Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(corpo)
            Toggle("Un adulto consente comunque questo ritmo",
                   isOn: $engine.config.lampeggioVeloceConsentito)
          }
        }

        Section("Maschera") {
          note("La maschera copre la parola subito dopo, così non la si continua a \"vedere\" nella memoria visiva: senza, si misura la memoria e non la lettura.")
          Picker("Maschera", selection: $engine.config.maskMode) {
            ForEach(MaskMode.allCases) { Text($0.label).tag($0) }
          }
          if engine.config.maskMode != .none {
            slider("Durata della maschera", $engine.config.maskMs, 0...1000, unit: "ms")
          }
        }

        Section("Ascolto") {
          slider("Quanto aspetta la risposta", $engine.config.responseTimeoutMs, 1000...10000, unit: "ms")
          slider("Silenzio che chiude la risposta", $engine.config.endpointSilenceMs, 200...2000, unit: "ms")
          Toggle("Analisi degli errori con il modello Apple sul dispositivo",
                 isOn: $engine.config.useAppleIntelligence)
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
    VStack(alignment: .leading, spacing: Metrica.filo) {
      HStack {
        Text(title).font(corpo)
        Spacer()
        Text("\(Int(value.wrappedValue)) \(unit)")
          .font(corpo)
          .monospacedDigit()
          .foregroundStyle(palette.muted)
      }
      Slider(value: value, in: range)
        // Senza nome VoiceOver legge "cursore, 50 per cento": non dice di che
        // cosa, e la percentuale non e' il numero che l'app mostra accanto.
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.wrappedValue)) \(unit)")
    }
  }
}
