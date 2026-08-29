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
  @ObservedObject var promemoria: Promemoria
  var onFinish: () -> Void
  var onCalibrate: () -> Void

  @State private var passo = 0
  /// Deciso una volta sola all'apertura e non ricalcolato: se sparisse appena
  /// risposto, i passi si rinumererebbero sotto i piedi di chi li sta facendo.
  @State private var chiediPromemoria = false
  /// La tastiera arriva sul pulsante che porta avanti, non sul primo controllo
  /// che capita: qui dentro si sceglie anche il profilo di chi «usa solo la
  /// voce o pochi tasti», e chiedergli il mouse proprio qui sarebbe il modo
  /// peggiore di cominciare.
  @FocusState private var fuoco: Fuoco?
  private enum Fuoco: Hashable { case avanti }

  @Environment(\.impostazioni) private var a11y

  /// I passi da mostrare: benvenuto, poi solo quelli non ancora a posto,
  /// poi la voce, poi il saluto finale.
  private var passi: [Passo] {
    var out: [Passo] = [.benvenuto, .profilo, .aspetto, .calma]
    for voce in readiness.voci where !voce.isOK && voce.necessaria {
      out.append(.sistema(voce.id))
    }
    out.append(.voce)
    if !Updates.chosen { out.append(.aggiornamenti) }
    if chiediPromemoria { out.append(.promemoria) }
    out.append(.pronti)
    return out
  }

  private enum Passo: Equatable {
    case benvenuto
    case profilo
    case aspetto
    case calma
    case sistema(String)
    case voce
    case aggiornamenti
    case promemoria
    case pronti
  }

  /// La parola dell'anteprima dal vivo: corta, comune, facile da riconoscere.
  private let parolaEsempio = "gatto"

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      barraPassi
      ScrollView {
        contenuto
          .padding(.horizontal, a11y.size(Metrica.spazioEnorme))
          .padding(.vertical, a11y.size(Metrica.spazioLargo))
          .frame(maxWidth: a11y.size(820), alignment: .leading)
      }
      .frame(maxWidth: .infinity)
      pulsanti
        .padding(.horizontal, a11y.size(Metrica.spazioEnorme))
        .padding(.bottom, a11y.size(Metrica.spazioLargo))
        .frame(maxWidth: a11y.size(820), alignment: .leading)
    }
    .frame(maxWidth: .infinity)
    .defaultFocus($fuoco, .avanti)
    .task {
      await readiness.controlla()
      // Il permesso delle notifiche si chiede qui, dove c'e' lo spazio per
      // dire a che cosa serve. Chiederlo a freddo la prima volta che si apre
      // l'app e' il modo piu' sicuro per farselo negare per sempre.
      await promemoria.aggiornaPermesso()
      chiediPromemoria = promemoria.permesso == .notDetermined
    }
  }

  // MARK: - Pezzi

  private var passoCorrente: Passo { passi[min(passo, passi.count - 1)] }

  private var barraPassi: some View {
    HStack(spacing: Metrica.spazioStretto) {
      ForEach(0..<passi.count, id: \.self) { i in
        Capsule()
          .fill(i <= passo ? palette.accent : palette.muted.opacity(0.25))
          .frame(height: 8)
      }
    }
    .padding(.horizontal, a11y.size(Metrica.spazioEnorme))
    .padding(.top, a11y.size(Metrica.spazioLargo))
    .accessibilityLabel("Passo \(passo + 1) di \(passi.count)")
  }

  @ViewBuilder
  private var contenuto: some View {
    switch passoCorrente {
    case .benvenuto:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Ciao!")
        Explain(text: "MirrorScopio fa vedere una parola per un istante e ascolta come la leggi. Serve per allenare la lettura, un pezzetto alla volta.", a11y: a11y, size: 21)
        Explain(text: "**Tutto resta su questo Mac.** La tua voce non viene inviata a nessuno: il riconoscimento funziona anche senza internet.", a11y: a11y, size: 21)
        Explain(text: "Sistemiamo insieme come si vede l'app e quel che le serve per ascoltarti: ci vuole un minuto.", a11y: a11y, size: 21)
      }

    case .profilo:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Che cosa succede quando leggi?")
        Explain(text: "Se ti riconosci in una di queste frasi, l'app si sistema da sola: carattere, colori, tempi, pause, grandezza dei comandi. Se non ti riconosci in nessuna, si salta: non cambia niente e si può scegliere anche dopo.", a11y: a11y, size: 21)
        LazyVGrid(columns: a11y.colonneAdattive(minimo: 250, spazio: Metrica.spazioPiccolo),
                  spacing: Metrica.spazioPiccolo) {
          ForEach(A11yProfile.allCases) { p in
            ChoiceCard(title: p.frase, subtitle: p.hint, symbol: p.symbol,
                       selected: a11y.profile == p, a11y: a11y) {
              var l = store.current
              p.apply(to: &l.a11y)
              store.current = l
            }
          }
        }
        notaSiCambia
      }

    case .aspetto:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Si legge bene?")
        Explain(text: "Se chi userà l'app vede poco, o le lettere gli si accavallano, qui si sistema in un attimo. Prova subito: la parola qui sotto cambia mentre scegli.", a11y: a11y, size: 21)
        anteprimaParola
        sliderOnb("Quanto grande", bindDouble(\.stimulusSize), 48...220) { "\(Int($0)) punti" }
        SectionTitle(text: "Il carattere", a11y: a11y)
        LazyVGrid(columns: a11y.colonneAdattive(minimo: 220, spazio: Metrica.spazioPiccolo), spacing: Metrica.spazioPiccolo) {
          ForEach(TypefaceChoice.allCases.filter(\.isAvailable)) { t in
            ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.typeface == t, a11y: a11y) {
              aggiorna { $0.typeface = t }
            }
          }
        }
        SectionTitle(text: "Colori e luce", a11y: a11y)
        LazyVGrid(columns: a11y.colonneAdattive(minimo: 220, spazio: Metrica.spazioPiccolo), spacing: Metrica.spazioPiccolo) {
          ForEach(ThemeChoice.allCases) { t in
            ChoiceCard(title: t.label, subtitle: t.hint, selected: a11y.manopole.theme == t, a11y: a11y) {
              aggiorna { $0.theme = t }
            }
          }
        }
        notaSiCambia
      }

    case .calma:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Quante cose intorno?")
        Explain(text: "C'è chi legge meglio con lo schermo tranquillo: senza colori accesi e senza cose che si muovono. Se serve, si toglie tutto qui.", a11y: a11y, size: 21)
        toggleOnb("Modalità calma", bindBool(\.calmMode),
                  "Niente esclamazioni né festeggiamenti: tono sempre uguale, colori più quieti.")
        toggleOnb("Meno animazioni", bindBool(\.reducedMotion),
                  "Tutto compare e sparisce senza movimento.")
        SectionTitle(text: "Come vedi i colori", a11y: a11y)
        Explain(text: "«Giusta» e «ancora» non si distinguono mai solo dal colore: c'è sempre anche un simbolo e una parola. Qui scegli i colori che si distinguono meglio.", a11y: a11y, size: 16)
        HStack(spacing: Metrica.spazio) {
          Verdict(correct: true, a11y: a11y)
          Verdict(correct: false, a11y: a11y)
        }
        LazyVGrid(columns: a11y.colonneAdattive(minimo: 220, spazio: Metrica.spazioPiccolo), spacing: Metrica.spazioPiccolo) {
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
        VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
          titolo(titoloPasso(voce))
          Explain(text: spiegazionePasso(voce), a11y: a11y, size: 21)
          switch voce.stato {
          case .inCorso(let frazione):
            VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
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
            .frame(maxWidth: a11y.size(380))
          case .ok:
            Verdict(correct: true, a11y: a11y, size: 24)
          }
        }
      }

    case .voce:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Chi ti legge le parole?")
        Explain(text: "In alcune prove è l'app a dire la parola ad alta voce. Scegli la voce che si capisce meglio: sentile e decidi tu.", a11y: a11y, size: 21)
        VoiceChooser(store: store)
        altreVoci
      }

    case .aggiornamenti:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Ti avviso quando esce una versione nuova?")
        Explain(text: "MirrorScopio non manda niente a nessuno: quello che dici o scrivi resta su questo Mac. Questa è l'unica eccezione, e la scegli tu.", a11y: a11y, size: 21)
        Explain(text: "Se dici di sì, una volta al giorno l'app chiede a GitHub qual è l'ultima versione pubblicata. È una domanda su di noi, non su di te: non parte nessun nome, nessuna parola, nessun punteggio. Non scarica niente da sola: se c'è una versione nuova te lo dice, e la installi tu con un pulsante quando vuoi.", a11y: a11y, size: 19)
        HStack(spacing: Metrica.spazioPiccolo) {
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

    case .promemoria:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
        titolo("Ti ricordo di allenarti?")
        Explain(text: "Serve pochissimo, ma serve spesso: dieci minuti al giorno valgono piu' di un'ora una volta a settimana. E la cosa piu' difficile non e' farlo — e' ricordarsene.", a11y: a11y, size: 21)
        Explain(text: "Se dici di si', il Mac fa comparire un invito gentile alle \(promemoria.orarioTesto). Resta tutto qui dentro: e' un avviso di macOS, non un messaggio che parte da qualche parte. E nel giorno in cui ti sei gia' allenato non arriva niente.", a11y: a11y, size: 19)
        HStack(spacing: Metrica.spazioPiccolo) {
          BigButton(title: "Si', ricordamelo", symbol: "bell.fill", a11y: a11y) {
            Task {
              await promemoria.accendi(
                giaFattoOggi: store.current.lastSessionDay == Gamification.dayKey(Date()),
                serieGiorni: store.current.streakCurrent)
              passo = min(passi.count - 1, passo + 1)
            }
          }
          BigButton(title: "No, grazie", a11y: a11y, prominent: false) {
            promemoria.spegni()
            passo = min(passi.count - 1, passo + 1)
          }
        }
        Explain(text: "Si cambia idea quando vuoi, dalle impostazioni: orario, giorni, o spegnerli del tutto.", a11y: a11y, size: 17)
      }

    case .pronti:
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMedio)) {
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
    VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
      Explain(text: "Le voci di serie bastano. Se ne vuoi una più naturale, macOS non permette a nessuna app di scaricarle: si fa una volta sola in Impostazioni di Sistema › Accessibilità › Contenuto letto › Voce di sistema › Gestisci voci.", a11y: a11y, size: 16)
      SmallButton(title: "Apri quella pagina delle Impostazioni",
                  symbol: "arrow.up.forward.app", a11y: a11y) {
        readiness.apriImpostazioniVoci()
      }
    }
    .padding(.top, Metrica.briciola)
  }

  // MARK: - Accessibilità nell'avvio guidato

  /// L'anteprima dal vivo: la parola resa **esattamente** come durante
  /// l'esercizio — stesso carattere, stessa spaziatura, stessi colori — così
  /// chi sceglie non sta configurando un'app, sta capendo se il proprio figlio
  /// riuscirà a leggere.
  private var anteprimaParola: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
      Explain(text: "Così apparirà una parola durante l'esercizio:", a11y: a11y, size: 16)
      Text(parolaEsempio)
        .font(a11y.typeface.font(size: CGFloat(a11y.stimulusSize), weight: .semibold))
        .tracking(CGFloat(a11y.letterSpacing))
        .foregroundStyle(palette.foreground)
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(a11y.stimulusSize) * 1.4)
        .background(RoundedRectangle(cornerRadius: Metrica.raggio).fill(palette.background))
        .overlay(RoundedRectangle(cornerRadius: Metrica.raggio)
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
                         _ format: @escaping (Double) -> String) -> some View {
    CursoreAccessibile(titolo: title, valore: value, intervallo: range,
                       passo: (range.upperBound - range.lowerBound) / 40,
                       a11y: a11y, descrizione: format)
  }

  private func toggleOnb(_ title: String, _ value: Binding<Bool>, _ hint: String) -> some View {
    VStack(alignment: .leading, spacing: Metrica.filo) {
      InterruttoreAccessibile(titolo: title, acceso: value, a11y: a11y)
      Explain(text: hint, a11y: a11y, size: 15)
        .padding(.horizontal, Metrica.spazioStretto)
    }
  }

  /// Le scelte finiscono negli stessi `A11ySettings` che usa tutto il resto
  /// dell'app: non una copia. App.swift tiene in riga il motore da solo quando
  /// `store.current.a11y` cambia.
  private func aggiorna(_ change: (inout A11ySettings) -> Void) {
    var l = store.current
    change(&l.a11y)
    // Come nelle Impostazioni: toccare una manopola a mano vuol dire che il
    // profilo non descrive più esattamente questa persona, e si passa a «su
    // misura». Qui non succedeva, e rifare l'avvio guidato lasciava l'app in
    // uno stato diverso da quello in cui la lasciavano le Impostazioni.
    if l.a11y.profile != .nessuno { l.a11y.profile = .nessuno }
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

  /// Il primo avvio era l'unica schermata dell'app che non si potesse
  /// attraversare a tasti: nessuna scorciatoia, nessuna via d'uscita, e per
  /// andare avanti bisognava per forza prendere il mouse. Ma e' obbligatoria,
  /// viene prima di tutto, e nelle sue stesse pagine si sceglie il profilo di
  /// chi «usa solo la voce o pochi tasti». Chiedere il mouse proprio li'
  /// significa fermare sulla soglia le persone per cui l'app e' stata scritta.
  ///
  /// Invio va avanti, Esc salta. Le due scorciatoie stanno anche scritte sotto
  /// i pulsanti: una scorciatoia che nessuno sa che esiste non aiuta nessuno.
  private var pulsanti: some View {
    VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
      HStack(spacing: Metrica.spazioPiccolo) {
        if passo > 0 {
          BigButton(title: "Indietro", symbol: "chevron.left", a11y: a11y, prominent: false) {
            passo = max(0, passo - 1)
          }
          .frame(maxWidth: a11y.size(220))
        }
        if passoCorrente == .pronti {
          if readiness.puoIniziare {
            BigButton(title: "Facciamo la prova", symbol: "wand.and.stars", a11y: a11y,
                      action: onCalibrate)
              .frame(maxWidth: a11y.size(320))
              .focused($fuoco, equals: .avanti)
              .keyboardShortcut(.defaultAction)
            BigButton(title: "Salta, comincio e basta", symbol: "play.fill", a11y: a11y,
                      prominent: false, action: onFinish)
              .frame(maxWidth: a11y.size(300))
          } else {
            BigButton(title: "Cominciamo", symbol: "play.fill", a11y: a11y, action: onFinish)
              .frame(maxWidth: a11y.size(320))
              .focused($fuoco, equals: .avanti)
              .keyboardShortcut(.defaultAction)
          }
        } else {
          BigButton(title: "Avanti", symbol: "chevron.right", a11y: a11y) {
            Task { await readiness.controlla() }
            passo = min(passi.count - 1, passo + 1)
          }
          .frame(maxWidth: a11y.size(280))
          .focused($fuoco, equals: .avanti)
          .keyboardShortcut(.defaultAction)
        }
        Spacer(minLength: 0)
        Button("Salta") { onFinish() }
          .font(a11y.font(.etichetta))
          .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
          .foregroundStyle(palette.muted)
          .frame(minHeight: Metrica.bersaglio)
          .keyboardShortcut(.escape, modifiers: [])
          .accessibilityHint("Puoi anche premere Esc")
      }
      Explain(text: "Puoi anche premere **Invio** per andare avanti, o **Esc** per saltare tutto.",
              a11y: a11y, size: 14)
    }
  }

  private func titolo(_ t: String) -> some View {
    Text(t)
      .font(a11y.font(.titoloGrande, .bold))
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
