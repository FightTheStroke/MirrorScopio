import SwiftUI

/// I parametri clinici. Stanno dietro un pulsante perché al ragazzo non servono
/// e al logopedista servono tutti.
struct AdvancedSheet: View {
  @ObservedObject var store: Store
  @ObservedObject var engine: SessionEngine
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Parametri clinici").font(.headline)
        Spacer()
        Button("Fine") {
          var l = store.current
          l.config = engine.config
          store.current = l
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding()

      Divider()

      Form {
        Section("Stimoli") {
          Picker("Lista", selection: $engine.config.set) {
            ForEach(StimulusSet.allCases) { Text($0.label).tag($0) }
          }
          if engine.config.set == .personalizzata {
            VStack(alignment: .leading, spacing: 6) {
              Text("Una parola per riga.").font(.callout).foregroundStyle(.secondary)
              TextEditor(text: $engine.config.customList)
                .font(.system(.body, design: .monospaced))
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
    }
    .frame(width: 640, height: 660)
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func slider(_ title: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(title)
        Spacer()
        Text("\(Int(value.wrappedValue)) \(unit)").monospacedDigit().foregroundStyle(.secondary)
      }
      Slider(value: value, in: range)
    }
  }
}
