import SwiftUI

/// Schermata di preparazione: dice, in una riga per cosa, se il Mac ha quello
/// che serve — e quando può, lo sistema da qui.
///
/// Compare da sola al primo avvio e ogni volta che manca qualcosa di
/// necessario. Non è un elenco di specifiche tecniche: ogni riga dice a che
/// cosa serve quella cosa e che cosa fare se manca.
struct ReadinessView: View {
  @Environment(\.palette) private var palette
  @ObservedObject var readiness: Readiness
  var a11y: A11ySettings
  /// Mostrata come schermata d'avvio (niente "Chiudi") o aperta dalle impostazioni.
  var onClose: (() -> Void)?
  var onContinue: (() -> Void)?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazio)) {
        VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
          Text("Prepariamo il Mac")
            .font(a11y.font(.titoloGrande, .bold))
            .foregroundStyle(palette.foreground)
          Explain(text: "MirrorScopio ascolta e parla usando solo questo Mac. Un Mac nuovo non ha sempre tutto installato: qui controlliamo, una cosa alla volta.",
                  a11y: a11y, size: 19)
        }

        ForEach(readiness.voci) { voce in
          riga(voce)
        }

        HStack(spacing: Metrica.spazioPiccolo) {
          if readiness.puoIniziare, let onContinue {
            BigButton(title: "Vai", symbol: "arrow.right", a11y: a11y, action: onContinue)
              .frame(maxWidth: 260)
          }
          BigButton(title: "Ricontrolla", symbol: "arrow.clockwise", a11y: a11y, prominent: false) {
            Task { await readiness.controlla() }
          }
          .frame(maxWidth: 260)
          if let onClose {
            BigButton(title: "Chiudi", symbol: "xmark", a11y: a11y, prominent: false, action: onClose)
              .frame(maxWidth: 200)
              .keyboardShortcut(.escape, modifiers: [])
          }
        }
        .padding(.top, Metrica.spazioMinimo)

        if !readiness.puoIniziare {
          Explain(text: "Le voci con il punto esclamativo vanno sistemate prima di iniziare: senza microfono o senza il riconoscimento italiano l'app non può sentire chi legge.",
                  a11y: a11y)
        }
      }
      .padding(a11y.size(Metrica.spazioGrande))
      .frame(maxWidth: 900, alignment: .leading)
    }
    .frame(maxWidth: .infinity)
    .task { await readiness.controlla() }
  }

  @ViewBuilder
  private func riga(_ voce: Readiness.Voce) -> some View {
    HStack(alignment: .top, spacing: Metrica.spazioMedio) {
      simbolo(voce)
        .font(.system(size: a11y.size(28), weight: .bold))
        .frame(width: a11y.size(38))

      VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
        Text(voce.titolo)
          .font(a11y.font(.guida, .semibold))
          .foregroundStyle(palette.foreground)

        switch voce.stato {
        case .ok(let d), .manca(let d):
          Explain(text: d, a11y: a11y)
        case .inCorso(let frazione):
          VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
            ProgressView(value: frazione ?? 0, total: 1)
              .progressViewStyle(.linear)
              .tint(palette.accent)
            Explain(text: frazione == nil ? "Sto scaricando…"
                     : "Sto scaricando… \(Int((frazione ?? 0) * 100))%", a11y: a11y)
          }
        }
      }

      Spacer(minLength: 8)

      if !voce.isOK, !voce.isInCorso, let etichetta = etichettaRimedio(voce.rimedio) {
        SmallButton(title: etichetta, a11y: a11y, prominente: true) {
          Task { await readiness.applica(voce) }
        }
      }
    }
    .padding(a11y.size(Metrica.spazioMedio))
    .background(RoundedRectangle(cornerRadius: Metrica.raggio).fill(palette.surface))
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .stroke(bordo(voce), lineWidth: voce.isOK ? 0 : 2)
    )
  }

  /// Colore *e* simbolo: chi non distingue i colori legge comunque l'esito.
  private func simbolo(_ voce: Readiness.Voce) -> some View {
    let (nome, colore): (String, Color) = {
      if voce.isOK { return (ColorVision.okSymbol, palette.ok) }
      if voce.isInCorso { return ("arrow.down.circle", palette.accent) }
      return voce.necessaria
        ? ("exclamationmark.triangle.fill", palette.wrong)
        : ("info.circle.fill", palette.muted)
    }()
    return Image(systemName: nome).foregroundStyle(colore)
  }

  private func bordo(_ voce: Readiness.Voce) -> Color {
    if voce.isOK || voce.isInCorso { return .clear }
    return voce.necessaria ? palette.wrong.opacity(0.6) : palette.muted.opacity(0.35)
  }

  private func etichettaRimedio(_ rimedio: Readiness.Rimedio) -> String? {
    switch rimedio {
    case .chiediMicrofono: return "Consenti"
    case .scaricaModello: return "Scarica"
    case .apriImpostazioni: return "Apri Impostazioni"
    case .nessuno: return nil
    }
  }
}
