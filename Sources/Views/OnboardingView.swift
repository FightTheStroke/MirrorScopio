import SwiftUI

/// Primo avvio: un passo alla volta, una cosa sola per schermata.
///
/// Non è un elenco da leggere: è una guida. Salta da solo i passi già a posto,
/// spiega *perché* serve una cosa prima di chiederla, e non manda mai
/// l'utente nelle Impostazioni di Sistema per qualcosa di necessario — tutto
/// ciò che è obbligatorio (permesso del microfono, modello vocale italiano)
/// si concede e si scarica da qui.
struct OnboardingView: View {
  @Environment(\.palette) private var palette
  @ObservedObject var readiness: Readiness
  @ObservedObject var store: Store
  var onFinish: () -> Void
  var onCalibrate: () -> Void

  @State private var passo = 0

  private var a11y: A11ySettings { store.current.a11y }

  /// I passi da mostrare: benvenuto, poi solo quelli non ancora a posto,
  /// poi la voce, poi il saluto finale.
  private var passi: [Passo] {
    var out: [Passo] = [.benvenuto, .aspetto, .calma]
    for voce in readiness.voci where !voce.isOK && voce.necessaria {
      out.append(.sistema(voce.id))
    }
    out.append(.voce)
    if !Updates.chosen { out.append(.aggiornamenti) }
    out.append(.pronti)
    return out
  }

  private enum Passo: Equatable {
    case benvenuto
    case aspetto
    case calma
    case sistema(String)
    case voce
    case aggiornamenti
    case pronti
  }

  /// La parola dell'anteprima dal vivo: corta, comune, facile da riconoscere.
  private let parolaEsempio = "gatto"

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      barraPassi
      ScrollView {
        contenuto
          .padding(.horizontal, a11y.size(40))
          .padding(.vertical, a11y.size(28))
          .frame(maxWidth: 820, alignment: .leading)
      }
      .frame(maxWidth: .infinity)
      pulsanti
        .padding(.horizontal, a11y.size(40))
        .padding(.bottom, a11y.size(28))
        .frame(maxWidth: 820, alignment: .leading)
    }
    .frame(maxWidth: .infinity)
    .task { await readiness.controlla() }
  }

  // MARK: - Pezzi

  private var passoCorrente: Passo { passi[min(passo, passi.count - 1)] }

  private var barraPassi: some View {
    HStack(spacing: 8) {
      ForEach(0..<passi.count, id: \.self) { i in
        Capsule()
          .fill(i <= passo ? palette.accent : palette.muted.opacity(0.25))
          .frame(height: 8)
      }
    }
    .padding(.horizontal, a11y.size(40))
    .padding(.top, a11y.size(28))
    .accessibilityLabel("Passo \(passo + 1) di \(passi.count)")
  }

  @ViewBuilder
  private var contenuto: some View {
    switch passoCorrente {
    case .benvenuto:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo("Ciao!")
        Explain(text: "MirrorScopio fa vedere una parola per un istante e ascolta come la leggi. Serve per allenare la lettura, un pezzetto alla volta.", a11y: a11y, size: 21)
        Explain(text: "**Tutto resta su questo Mac.** La tua voce non viene inviata a nessuno: il riconoscimento funziona anche senza internet.", a11y: a11y, size: 21)
        Explain(text: "Sistemiamo insieme come si vede l'app e quel che le serve per ascoltarti: ci vuole un minuto.", a11y: a11y, size: 21)
      }

    case .aspetto:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo("Si legge bene?")
        Explain(text: "Se chi userà l'app vede poco, o le lettere gli si accavallano, qui si sistema in un attimo. Prova subito: la parola qui sotto cambia mentre scegli.", a11y: a11y, size: 21)
        anteprimaParola
        sliderOnb("Quanto grande", bindDouble(\.stimulusSize), 48...220) { "\(Int($0)) punti" }
        SectionTitle(text: "Il carattere", a11y: a11y)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
          ForEach(TypefaceChoice.allCases.filter(\.isAvailable)) { t in
            ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.typeface == t, a11y: a11y) {
              aggiorna { $0.typeface = t }
            }
          }
        }
        SectionTitle(text: "Colori e luce", a11y: a11y)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
          ForEach(ThemeChoice.allCases) { t in
            ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.theme == t, a11y: a11y) {
              aggiorna { $0.theme = t }
            }
          }
        }
        notaSiCambia
      }

    case .calma:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo("Quante cose intorno?")
        Explain(text: "C'è chi legge meglio con lo schermo tranquillo: senza colori accesi e senza cose che si muovono. Se serve, si toglie tutto qui.", a11y: a11y, size: 21)
        toggleOnb("Modalità calma", bindBool(\.calmMode),
                  "Niente esclamazioni né festeggiamenti: tono sempre uguale, colori più quieti.")
        toggleOnb("Meno animazioni", bindBool(\.reducedMotion),
                  "Tutto compare e sparisce senza movimento.")
        SectionTitle(text: "Come vedi i colori", a11y: a11y)
        Explain(text: "«Giusta» e «ancora» non si distinguono mai solo dal colore: c'è sempre anche un simbolo e una parola. Qui scegli i colori che si distinguono meglio.", a11y: a11y, size: 16)
        HStack(spacing: 20) {
          Verdict(correct: true, a11y: a11y)
          Verdict(correct: false, a11y: a11y)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
          ForEach(ColorVision.allCases) { v in
            ChoiceCard(title: v.label, selected: a11y.colorVision == v, a11y: a11y) {
              aggiorna { $0.colorVision = v }
            }
          }
        }
        notaSiCambia
      }

    case .sistema(let id):
      if let voce = readiness.voci.first(where: { $0.id == id }) {
        VStack(alignment: .leading, spacing: a11y.size(16)) {
          titolo(titoloPasso(voce))
          Explain(text: spiegazionePasso(voce), a11y: a11y, size: 21)
          switch voce.stato {
          case .inCorso(let frazione):
            VStack(alignment: .leading, spacing: 8) {
              ProgressView(value: frazione ?? 0, total: 1)
                .progressViewStyle(.linear)
                .tint(palette.accent)
              Explain(text: frazione == nil ? "Sto scaricando…" : "Sto scaricando… \(Int((frazione ?? 0) * 100))%", a11y: a11y)
            }
          case .manca(let dettaglio):
            Explain(text: dettaglio, a11y: a11y, size: 18)
            BigButton(title: etichetta(voce), symbol: simbolo(voce), a11y: a11y) {
              Task { await readiness.applica(voce) }
            }
            .frame(maxWidth: 380)
          case .ok:
            Verdict(correct: true, a11y: a11y, size: 24)
          }
        }
      }

    case .voce:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo("Chi ti legge le parole?")
        Explain(text: "In alcune prove è l'app a dire la parola ad alta voce. Scegli la voce che si capisce meglio: sentile e decidi tu.", a11y: a11y, size: 21)
        VoiceChooser(store: store)
        altreVoci
      }

    case .aggiornamenti:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo("Ti avviso quando esce una versione nuova?")
        Explain(text: "MirrorScopio non manda niente a nessuno: quello che dici o scrivi resta su questo Mac. Questa è l'unica eccezione, e la scegli tu.", a11y: a11y, size: 21)
        Explain(text: "Se dici di sì, una volta al giorno l'app chiede a GitHub qual è l'ultima versione pubblicata. È una domanda su di noi, non su di te: non parte nessun nome, nessuna parola, nessun punteggio. E non scarica niente da sola — se c'è una versione nuova te lo dice e basta.", a11y: a11y, size: 19)
        HStack(spacing: 12) {
          BigButton(title: "Sì, avvisami", symbol: "checkmark", a11y: a11y) {
            Updates.enabled = true
            passo = min(passi.count - 1, passo + 1)
          }
          BigButton(title: "No, grazie", a11y: a11y, prominent: false) {
            Updates.enabled = false
            passo = min(passi.count - 1, passo + 1)
          }
        }
        Explain(text: "Si cambia idea quando vuoi, dalle impostazioni.", a11y: a11y, size: 17)
      }

    case .pronti:
      VStack(alignment: .leading, spacing: a11y.size(16)) {
        titolo(readiness.puoIniziare ? "Facciamo una prova insieme" : "Manca ancora qualcosa")
        Explain(text: readiness.puoIniziare
                ? "Otto parole, meno di un minuto. Servono al Mac per capire da che velocità partire con te: né troppo facile da annoiarti, né troppo difficile da scoraggiarti. Non è un esame e non viene contata: se una parola non viene ancora, si tira dritto."
                : "Manca ancora qualcosa di necessario: torna indietro e sistemalo, altrimenti l'app non riesce ad ascoltarti.",
                a11y: a11y, size: 21)
        Explain(text: "Il microfono e gli altoparlanti si cambiano quando vuoi dalla barra in alto, anche a metà: se attacchi le cuffie, lo dici lì.", a11y: a11y, size: 17)
      }
    }
  }

  /// L'unica cosa che il Mac non lascia fare a un'app: scaricare altre voci.
  /// Va detto chiaramente, e solo qui, dove non blocca nessuno.
  private var altreVoci: some View {
    VStack(alignment: .leading, spacing: 8) {
      Explain(text: "Le voci di serie bastano. Se ne vuoi una più naturale, macOS non permette a nessuna app di scaricarle: si fa una volta sola in Impostazioni di Sistema › Accessibilità › Contenuto letto › Voce di sistema › Gestisci voci.", a11y: a11y, size: 16)
      Button("Apri quella pagina delle Impostazioni") {
        readiness.apriImpostazioniVoci()
      }
      .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
      .buttonStyle(.bordered)
    }
    .padding(.top, 4)
  }

  // MARK: - Accessibilità nell'avvio guidato

  /// L'anteprima dal vivo: la parola resa **esattamente** come durante
  /// l'esercizio — stesso carattere, stessa spaziatura, stessi colori — così
  /// chi sceglie non sta configurando un'app, sta capendo se il proprio figlio
  /// riuscirà a leggere.
  private var anteprimaParola: some View {
    VStack(alignment: .leading, spacing: 8) {
      Explain(text: "Così apparirà una parola durante l'esercizio:", a11y: a11y, size: 16)
      Text(parolaEsempio)
        .font(a11y.typeface.font(size: CGFloat(a11y.stimulusSize), weight: .semibold))
        .tracking(CGFloat(a11y.letterSpacing))
        .foregroundStyle(palette.foreground)
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(a11y.stimulusSize) * 1.4)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.background))
        .overlay(RoundedRectangle(cornerRadius: 16)
          .stroke(palette.muted.opacity(0.3), lineWidth: 1.5))
        .animation(a11y.animation(0.15), value: a11y.stimulusSize)
        .accessibilityLabel("Parola di esempio, grande \(Int(a11y.stimulusSize)) punti")
    }
  }

  private var notaSiCambia: some View {
    Explain(text: "Non devi decidere adesso: questi valori vanno bene per molti, e si cambiano quando vuoi dalle Impostazioni (l'ingranaggio in alto).", a11y: a11y, size: 16)
  }

  private func sliderOnb(_ title: String, _ value: Binding<Double>,
                         _ range: ClosedRange<Double>,
                         _ format: (Double) -> String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
          .font(a11y.typeface.font(size: a11y.size(17)))
          .foregroundStyle(palette.foreground)
        Spacer()
        Text(format(value.wrappedValue))
          .font(a11y.typeface.font(size: a11y.size(15)))
          .foregroundStyle(palette.muted)
          .monospacedDigit()
      }
      Slider(value: value, in: range).frame(maxWidth: 460)
    }
  }

  private func toggleOnb(_ title: String, _ value: Binding<Bool>, _ hint: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Toggle(title, isOn: value)
        .font(a11y.typeface.font(size: a11y.size(19)))
        .foregroundStyle(palette.foreground)
      Explain(text: hint, a11y: a11y, size: 15)
    }
  }

  /// Le scelte finiscono negli stessi `A11ySettings` che usa tutto il resto
  /// dell'app: non una copia. App.swift tiene in riga il motore da solo quando
  /// `store.current.a11y` cambia.
  private func aggiorna(_ change: (inout A11ySettings) -> Void) {
    var l = store.current
    change(&l.a11y)
    store.current = l
  }

  private func bindDouble(_ key: WritableKeyPath<A11ySettings, Double>) -> Binding<Double> {
    Binding(get: { store.current.a11y[keyPath: key] },
            set: { v in aggiorna { $0[keyPath: key] = v } })
  }

  private func bindBool(_ key: WritableKeyPath<A11ySettings, Bool>) -> Binding<Bool> {
    Binding(get: { store.current.a11y[keyPath: key] },
            set: { v in aggiorna { $0[keyPath: key] = v } })
  }

  private var pulsanti: some View {
    HStack(spacing: 14) {
      if passo > 0 {
        BigButton(title: "Indietro", symbol: "chevron.left", a11y: a11y, prominent: false) {
          passo = max(0, passo - 1)
        }
        .frame(maxWidth: 220)
      }
      if passoCorrente == .pronti {
        if readiness.puoIniziare {
          BigButton(title: "Facciamo la prova", symbol: "wand.and.stars", a11y: a11y,
                    action: onCalibrate)
            .frame(maxWidth: 320)
          BigButton(title: "Salta, comincio e basta", symbol: "play.fill", a11y: a11y,
                    prominent: false, action: onFinish)
            .frame(maxWidth: 300)
        } else {
          BigButton(title: "Cominciamo", symbol: "play.fill", a11y: a11y, action: onFinish)
            .frame(maxWidth: 320)
        }
      } else {
        BigButton(title: "Avanti", symbol: "chevron.right", a11y: a11y) {
          Task { await readiness.controlla() }
          passo = min(passi.count - 1, passo + 1)
        }
        .frame(maxWidth: 280)
      }
      Spacer(minLength: 0)
      Button("Salta") { onFinish() }
        .font(a11y.typeface.font(size: a11y.size(16)))
        .buttonStyle(.plain)
        .foregroundStyle(palette.muted)
    }
  }

  private func titolo(_ t: String) -> some View {
    Text(t)
      .font(a11y.typeface.font(size: a11y.size(40), weight: .bold))
      .foregroundStyle(palette.foreground)
  }

  // MARK: - Testi per passo

  private func titoloPasso(_ voce: Readiness.Voce) -> String {
    switch voce.id {
    case "microfono": return "Posso ascoltarti?"
    case "ingresso": return "Manca il microfono"
    case "modello": return "Scarico l'italiano"
    case "voce": return "Manca una voce italiana"
    default: return voce.titolo
    }
  }

  private func spiegazionePasso(_ voce: Readiness.Voce) -> String {
    switch voce.id {
    case "microfono":
      return "Per capire se hai letto giusto devo sentirti. **L'audio resta su questo Mac**: non viene registrato né inviato a nessuno. Premi il pulsante e poi «Consenti» nella finestra che compare."
    case "ingresso":
      return "Non trovo nessun microfono collegato. Attacca le cuffie o un microfono, oppure controlla che il microfono del Mac non sia disattivato."
    case "modello":
      return "Il riconoscimento dell'italiano si scarica una volta sola, poi funziona **senza internet** e senza mandare niente fuori da qui. Sono pochi minuti."
    default:
      return voce.titolo
    }
  }

  private func etichetta(_ voce: Readiness.Voce) -> String {
    switch voce.rimedio {
    case .chiediMicrofono: return "Sì, ascoltami"
    case .scaricaModello: return "Scarica l'italiano"
    case .apriImpostazioni: return "Apri le Impostazioni"
    case .nessuno: return "Ricontrolla"
    }
  }

  private func simbolo(_ voce: Readiness.Voce) -> String {
    switch voce.rimedio {
    case .chiediMicrofono: return "mic.fill"
    case .scaricaModello: return "arrow.down.circle.fill"
    case .apriImpostazioni: return "gearshape.fill"
    case .nessuno: return "arrow.clockwise"
    }
  }
}
