import SwiftUI

// MARK: - Le misure dell'app

/// I pochi numeri con cui è disegnata tutta l'app.
///
/// Erano dieci raggi d'angolo diversi (2, 3, 7, 8, 10, 11, 12, 14, 16, 18)
/// scritti a mano dentro le viste. Nessuno se n'era accorto guardando una
/// schermata per volta, ma messe in fila due schermate raccontavano due app.
/// Per chi fatica a interpretare un'interfaccia questo non è un dettaglio
/// estetico: ogni forma nuova è una cosa nuova da imparare, e imparare la
/// stessa cosa quattro volte è il motivo per cui si smette.
///
/// Sono quattro raggi e cinque spazi. Se serve un valore che non è qui,
/// quasi sempre la risposta giusta è usare quello più vicino.
enum Metrica {
  /// Pallini, barrette, cose piccole dentro altre cose.
  static let raggioMinimo: CGFloat = 3
  /// Righe di elenco, campi, pulsanti di servizio.
  static let raggioPiccolo: CGFloat = 10
  /// Carte, riquadri, gruppi di impostazioni.
  static let raggio: CGFloat = 14
  /// Pannelli grandi e pulsanti principali.
  static let raggioGrande: CGFloat = 18

  // La scala delle distanze. Dieci passi, e nessun numero fuori scala.
  //
  // Prima ogni schermata sceglieva le proprie distanze: 10 qui, 14 la', 22
  // nella riga accanto. Nessuna di quelle differenze e' una decisione — sono
  // numeri capitati mentre si guardava una schermata alla volta. Messe
  // insieme fanno pagine che non hanno lo stesso respiro, e chi legge con
  // fatica ci si perde: se lo spazio fra due cose non vuol dire sempre la
  // stessa cosa, non aiuta piu' a capire che cosa sta con che cosa.
  //
  // I passi sono radi apposta: due distanze devono essere o uguali o
  // chiaramente diverse. Due punti di differenza non li decide nessuno.

  /// Due cose attaccate: un'icona e la sua parola.
  static let filo: CGFloat = 2
  /// Quasi attaccate.
  static let briciola: CGFloat = 4
  /// Fra due cose che sono la stessa cosa.
  static let spazioMinimo: CGFloat = 6
  /// Dentro un elemento: il respiro di un pulsante piccolo.
  static let spazioStretto: CGFloat = 8
  /// Fra le righe di un gruppo.
  static let spazioPiccolo: CGFloat = 12
  /// Fra due gruppi vicini.
  static let spazioMedio: CGFloat = 16
  /// Fra un gruppo e l'altro.
  static let spazio: CGFloat = 20
  /// Il respiro dentro un riquadro.
  static let spazioLargo: CGFloat = 24
  /// Fra una sezione e l'altra.
  static let spazioGrande: CGFloat = 32
  /// Attorno alle cose che devono stare da sole.
  static let spazioEnorme: CGFloat = 40
  /// Il margine attorno al contenuto di una pagina.
  static let margine: CGFloat = 26

  /// Il lato minimo di qualunque cosa si possa premere.
  ///
  /// Apple dice 44 punti. Qui è il minimo assoluto, non l'obiettivo: chi ha
  /// paralisi cerebrale colpisce un bersaglio di 44 punti a fatica, e dove
  /// si può il bersaglio è più grande.
  static let bersaglio: CGFloat = 44
}

// MARK: - Il fuoco della tastiera

/// La forma di un pulsante: serve all'anello di fuoco per stare aderente.
enum FormaPulsante {
  case capsula
  case arrotondata(CGFloat)
  case rettangolo
}

/// Lo stile di **tutti** i pulsanti disegnati a mano nell'app.
///
/// Nasce da un difetto vero e diffuso: diciassette pulsanti usavano
/// `.buttonStyle(.plain)`, che toglie di mezzo lo stile di sistema — e con lui
/// l'anello che dice dov'è arrivata la tastiera. Il risultato era un'app
/// percorribile senza mouse in cui **non si vedeva dove si era**: si premeva
/// Invio alla cieca. Per chi usa solo la tastiera, o pochi tasti, è la
/// differenza fra un'app che si usa e una in cui ci si perde.
///
/// L'anello è spesso, sta fuori dal pulsante e ha un distacco chiaro dallo
/// sfondo del pulsante stesso: un filo sottile dello stesso colore del bordo si
/// confonde proprio con chi ha più bisogno di vederlo.
struct StilePulsante: ButtonStyle {
  var forma: FormaPulsante = .rettangolo
  var a11y: EffettiveImpostazioniAccessibilita = EffettiveImpostazioniAccessibilita()

  func makeBody(configuration: Configuration) -> some View {
    Corpo(configuration: configuration, forma: forma, a11y: a11y)
  }

  private struct Corpo: View {
    let configuration: Configuration
    let forma: FormaPulsante
    let a11y: EffettiveImpostazioniAccessibilita
    // `isFocused` dice se il pulsante che sta usando questo stile ha il fuoco:
    // è il solo modo che uno stile ha di saperlo, perché la configurazione
    // racconta soltanto se è premuto.
    @Environment(\.isFocused) private var aFuoco
    @Environment(\.palette) private var palette

    var body: some View {
      configuration.label
        // Premuto si vede: prima l'unico riscontro era che qualcosa succedeva
        // dopo. Non è un movimento, è un cambio di opacità, quindi resta anche
        // con «meno animazioni».
        .opacity(configuration.isPressed ? 0.55 : 1)
        // Il Tab arriva qui **per costruzione**, non perche' qualcuno si e'
        // ricordato di scriverlo al momento giusto. Sui Mac in cui
        // «Navigazione da tastiera» e' spenta — cioe' quelli appena usciti
        // dalla scatola — un pulsante SwiftUI non e' raggiungibile col Tab se
        // non lo si dichiara. Era dichiarato su 8 pulsanti su 19: gli altri 11
        // (l'elenco laterale delle Impostazioni, le schermate di prova, la
        // scelta della voce) restavano fuori dal giro, mentre il documento
        // prometteva che ogni schermata si percorre senza mouse. Messo qui,
        // vale per chiunque usi lo stile dell'app, anche per chi lo scrivera'
        // domani.
        .focusable()
        .overlay { if aFuoco { bordo(palette.background, spessore: 2, fuori: 2) } }
        .overlay { if aFuoco { bordo(palette.accent, spessore: 3, fuori: 5) } }
        .animation(a11y.animation(0.12), value: aFuoco)
    }

    @ViewBuilder
    private func bordo(_ colore: Color, spessore: CGFloat, fuori: CGFloat) -> some View {
      switch forma {
      case .capsula:
        Capsule().strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      case .arrotondata(let raggio):
        RoundedRectangle(cornerRadius: raggio + fuori)
          .strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      case .rettangolo:
        RoundedRectangle(cornerRadius: Metrica.raggioMinimo + fuori)
          .strokeBorder(colore, lineWidth: spessore).padding(-fuori)
      }
    }
  }
}

// MARK: - Mattoncini condivisi

/// Il pulsante principale di una schermata: enorme, con un'icona e una parola sola.
/// Grande davvero, non "grande per un'app per adulti".
/// Il bottone di servizio: quello che apre una cartella, rifà una prova,
/// cancella dei dati.
///
/// Prima ce n'erano tre stili diversi nella stessa schermata — `.bordered`,
/// `.plain`, e il blu di sistema che sembrava un link. Un link e un bottone
/// chiedono due gesti diversi, e chi fa fatica a interpretare l'interfaccia
/// non deve indovinare quale dei due sia: qui hanno tutti la stessa forma,
/// lo stesso peso, la stessa altezza minima di 44 punti, e si distinguono
/// solo per quello che dicono. `distruttivo` colora il testo di rosso: e
/// l'unica variante, perche cancellare e l'unica cosa che non si annulla.
struct SmallButton: View {
  @Environment(\.palette) private var palette
  let title: String
  var symbol: String? = nil
  var a11y: EffettiveImpostazioniAccessibilita
  var distruttivo = false
  /// Riempito col colore d'accento: per l'azione che sblocca la schermata.
  ///
  /// Serve perché quelle azioni usavano `.borderedProminent`, cioè il blu di
  /// macOS, che **non segue il tema**: con «Altissimo contrasto» il comando
  /// che sblocca l'app restava blu su nero, cioè la cosa meno visibile della
  /// schermata proprio per chi ha scelto quel tema perché vede poco.
  var prominente = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioStretto) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.font(.etichetta, .semibold))
      .padding(.horizontal, a11y.size(Metrica.spazioMedio))
      .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(prominente ? palette.onAccent
                     : (distruttivo ? palette.wrong : palette.foreground))
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
      .fill(prominente ? palette.accent : palette.surface))
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
        .stroke(prominente ? .clear
                : (distruttivo ? palette.wrong.opacity(0.5) : palette.muted.opacity(0.35)),
                lineWidth: 1.5))
    .frame(minHeight: Metrica.bersaglio)
    .fixedSize(horizontal: true, vertical: false)
  }
}

struct BigButton: View {
  @Environment(\.palette) private var palette
  let title: String
  var symbol: String? = nil
  var a11y: EffettiveImpostazioniAccessibilita
  var prominent = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrica.spazioPiccolo) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.font(.titolo, .bold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(Metrica.spazio))
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggio), a11y: a11y))
    .foregroundStyle(prominent ? palette.onAccent : palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .fill(prominent ? palette.accent : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .stroke(prominent ? .clear : palette.muted.opacity(0.35), lineWidth: 2)
    )
    .frame(minHeight: 56)
  }
}

/// Una scelta fra poche, presentata come una carta cliccabile grande.
struct ChoiceCard: View {
  @Environment(\.palette) private var palette
  let title: String
  var subtitle: String? = nil
  var symbol: String? = nil
  let selected: Bool
  var a11y: EffettiveImpostazioniAccessibilita
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: Metrica.spazioStretto) {
        if let symbol {
          Image(systemName: symbol).font(.system(size: a11y.size(30)))
        }
        Text(title)
          .font(a11y.font(.guida, .semibold))
          .interlinea(a11y)
          .multilineTextAlignment(.center)
          // Senza, con il testo grande il titolo si accorcia invece di andare
          // a capo, e finisce con i puntini proprio nella frase in cui una
          // persona deve riconoscersi.
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle {
          Text(subtitle)
            .font(a11y.font(.nota))
            .interlinea(a11y)
            .foregroundStyle(palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      // Alte uguali, dentro la stessa riga.
      //
      // Le frasi hanno lunghezze diverse — «Le lettere si muovono» sta in una
      // riga, «Il verde e il rosso si somigliano» a testo grande ne prende
      // tre — e senza questo ogni scheda era alta quanto il suo testo: la
      // fila di scelte veniva sfalsata, con i riquadri a scaletta. Chi legge
      // fa fatica proprio a tenere insieme le cose che non sono allineate,
      // e questa e' la prima schermata che vede.
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical, a11y.size(Metrica.spazioMedio))
      .padding(.horizontal, Metrica.spazioStretto)
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggio), a11y: a11y))
    .foregroundStyle(palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .fill(selected ? palette.accent.opacity(a11y.velo(palette.isDark ? 0.32 : 0.16))
                       : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .stroke(selected ? palette.accent : Color.clear, lineWidth: 3)
    )
    // Il bordo da solo non basta: chi non distingue i colori deve poterlo capire lo stesso.
    .overlay(alignment: .topTrailing) {
      if selected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: a11y.size(18)))
          .foregroundStyle(palette.accent)
          .padding(Metrica.spazioStretto)
          // Il segno di spunta è un disegno, non un comando: senza questo
          // VoiceOver annunciava un secondo pulsante chiamato «Selezionato»
          // che non faceva niente, subito prima della carta vera.
          .accessibilityHidden(true)
      }
    }
    .frame(minHeight: 64)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    .accessibilityValue(selected ? "scelto" : "")
  }
}

/// Titolo di sezione, sempre della stessa taglia in tutta l'app.
struct SectionTitle: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: EffettiveImpostazioniAccessibilita

  var body: some View {
    Text(text)
      .font(a11y.font(.sezione, .bold))
      .foregroundStyle(palette.foreground)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Riga di testo esplicativo. Serve a dire *perché*, mai a riempire.
struct Explain: View {
  @Environment(\.palette) private var palette
  let text: String
  var a11y: EffettiveImpostazioniAccessibilita
  var size: Double = 17

  var body: some View {
    Text(.init(text))
      .font(a11y.typeface.font(size: a11y.size(size)))
      .interlinea(a11y)
      .foregroundStyle(palette.muted)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Esito di una parola: colore *e* simbolo *e* parola. Mai il colore da solo.
struct Verdict: View {
  @Environment(\.palette) private var palette
  let correct: Bool
  var a11y: EffettiveImpostazioniAccessibilita
  var size: Double = 20

  var body: some View {
    HStack(spacing: Metrica.spazioMinimo) {
      Image(systemName: correct ? ColorVision.okSymbol : ColorVision.wrongSymbol)
      Text(correct ? "giusta" : "ancora")
    }
    .font(a11y.typeface.font(size: a11y.size(size), weight: .semibold))
    .foregroundStyle(correct ? palette.ok : palette.wrong)
    .accessibilityLabel(correct ? "risposta giusta" : "questa non è venuta ancora")
  }
}

/// Il pulsante per fermarsi.
///
/// Prima era una scritta grigia di 16 punti in un angolo: per chi ha ipovisione
/// era invisibile, per chi ha difficoltà di controllo del movimento era un
/// bersaglio troppo piccolo da colpire. Fermarsi deve essere la cosa più facile
/// dello schermo, non la più difficile: se l'unica via d'uscita è nascosta, chi
/// è in difficoltà resta intrappolato in un esercizio che non regge più.
///
/// Ha la forma del comando di registrazione che si trova ovunque — cerchio
/// pieno, quadrato dentro — perché quella forma si riconosce senza leggere e
/// senza distinguere i colori. Il rosso è **suo**, diverso dal rosso delle
/// risposte sbagliate: smettere non è sbagliare, e i due gesti non devono
/// somigliarsi.
struct StopButton: View {
  @Environment(\.palette) private var palette
  var a11y: EffettiveImpostazioniAccessibilita
  var titolo = "Basta"
  let action: () -> Void

  private var rosso: Color { palette.stop }

  var body: some View {
    Button(action: action) {
      HStack(spacing: a11y.size(Metrica.spazioStretto)) {
        ZStack {
          Circle().fill(rosso)
          RoundedRectangle(cornerRadius: Metrica.raggioMinimo)
            .fill(Color.white)
            .frame(width: a11y.size(16), height: a11y.size(16))
        }
        .frame(width: a11y.size(38), height: a11y.size(38))

        Text(titolo)
          .font(a11y.font(.guida, .semibold))
      }
      .padding(.horizontal, a11y.size(Metrica.spazioMedio))
      .padding(.vertical, a11y.size(Metrica.spazioStretto))
      // 60 punti: la soglia dei 44 di Apple è il minimo per una mano ferma.
      .frame(minHeight: max(60, a11y.size(56)))
      .contentShape(Capsule())
    }
    .buttonStyle(StilePulsante(forma: .capsula, a11y: a11y))
    .foregroundStyle(palette.foreground)
    .background(Capsule().fill(palette.surface))
    .overlay(Capsule().stroke(rosso.opacity(0.55), lineWidth: 2))
    .accessibilityLabel("interrompi la sessione")
  }
}

/// I coriandoli di fine sessione.
///
/// Non festeggiano il punteggio: festeggiano l'essere arrivati in fondo. Chi
/// prende quattro parole su venti ha fatto la fatica più grande di tutti, e
/// meritarsi una festa non può dipendere dal risultato — altrimenti la festa
/// diventa l'ennesima classifica in cui si perde sempre.
///
/// Si spegne da sola con "meno animazioni" o in modalità calma: per chi ha
/// ipersensibilità sensoriale una pioggia di colori non è un premio, è
/// un'aggressione. In quel caso resta il testo, che dice le stesse cose.
struct Celebrazione: View {
  var a11y: EffettiveImpostazioniAccessibilita
  /// Da 0 a 1: quanti coriandoli. Il minimo non è mai zero.
  var intensita: Double = 1

  @State private var partita = false

  // Decorazione pura: i coriandoli non dicono niente che non sia già scritto
  // sopra a parole, e nessuno deve distinguerli fra loro. Restano fuori dalla
  // palette apposta — colorare di tema una festa la spegne.
  private let colori: [Color] = [
    Color(red: 0.98, green: 0.75, blue: 0.14),
    Color(red: 0.28, green: 0.66, blue: 0.96),
    Color(red: 0.38, green: 0.80, blue: 0.45),
    Color(red: 0.95, green: 0.44, blue: 0.60),
    Color(red: 0.62, green: 0.48, blue: 0.92),
  ]

  private var quanti: Int { max(14, Int(46 * intensita)) }

  var body: some View {
    if a11y.reducedMotion || a11y.calmMode {
      Color.clear.frame(height: 0)
    } else {
      GeometryReader { geo in
        ZStack {
          ForEach(0..<quanti, id: \.self) { i in
            let seme = Double((i * 7919) % 1000) / 1000
            let seme2 = Double((i * 104729) % 1000) / 1000
            RoundedRectangle(cornerRadius: Metrica.raggioMinimo)
              .fill(colori[i % colori.count])
              .frame(width: 9, height: 14)
              .rotationEffect(.degrees(seme * 360))
              .position(x: geo.size.width * seme,
                        y: partita ? geo.size.height + 40 : -40)
              .opacity(partita ? 0 : 1)
              .animation(
                .easeIn(duration: 2.4 + seme2 * 1.6).delay(seme2 * 0.9),
                value: partita)
          }
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear { partita = true }
    }
  }
}

/// La fila di pallini che dice a che punto si è, uno per parola.
///
/// Sta qui, e non dentro le due schermate, perché era scritta due volte: una in
/// `StageView` e una in `TypingView`. Erano già diverse di quattro punti di
/// margine, e sarebbero diventate diverse in tutto — è così che due modalità
/// della stessa app cominciano a sembrare due app. Il compito cambia, la
/// fila di pallini no.
///
/// Il colore dice com'è andata solo se il riscontro per parola è acceso: con
/// «nascondi i punteggi» resta una fila neutra che dice soltanto a che punto si
/// è arrivati, senza giudicare niente.
struct ProgressoPallini: View {
  @Environment(\.palette) private var palette
  let fatte: [Trial]
  let indice: Int
  let totale: Int
  var a11y: EffettiveImpostazioniAccessibilita
  /// «parola» o «frase»: cambia il compito, non la forma.
  var nomeDellUnita: String = "parola"

  var body: some View {
    if totale > 0 {
      VStack {
        Spacer()
        HStack(spacing: Metrica.spazioStretto) {
          ForEach(0..<totale, id: \.self) { i in
            pallino(i)
              .frame(width: i == indice - 1 ? 12 : 8,
                     height: i == indice - 1 ? 12 : 8)
          }
        }
        .padding(.bottom, Metrica.spazioLargo)
        .animation(a11y.animation(0.2), value: indice)
        .accessibilityElement()
        .accessibilityLabel("\(nomeDellUnita) \(indice) di \(totale)")
      }
      .allowsHitTesting(false)
      .transition(.opacity)
    }
  }

  private func colore(_ i: Int) -> Color {
    guard i < fatte.count, i < indice else { return palette.muted.opacity(a11y.velo(0.25)) }
    // Una parola interrotta dal Mac non è un risultato: resta neutra, come
    // quelle non ancora arrivate. Colorarla di rosso sarebbe dire al ragazzo
    // che ha sbagliato una parola che non ha mai visto.
    guard !fatte[i].interrotto else { return palette.muted.opacity(a11y.velo(0.4)) }
    guard a11y.showFeedbackPerWord, !a11y.hideScore else {
      return palette.muted.opacity(a11y.velo(0.75))
    }
    return fatte[i].correct ? palette.ok.opacity(a11y.velo(0.8))
                            : palette.wrong.opacity(a11y.velo(0.8))
  }

  /// Era l'unico posto dell'app in cui il colore portava un'informazione da
  /// solo: pallino verde o pallino rosso, stessa forma. Le parole che non sono
  /// venute ancora sono un anello vuoto — una forma diversa, non una tinta
  /// diversa.
  ///
  /// La forma diversa c'era già, ma **solo se il Mac chiedeva di non
  /// distinguere dal colore**. Chi confonde il verde e il rosso senza aver
  /// acceso quell'impostazione — cioè quasi tutti quelli a cui succede —
  /// vedeva due pallini identici. La regola scritta in AGENTS.md non è
  /// «quando il Mac lo chiede»: è sempre.
  @ViewBuilder
  private func pallino(_ i: Int) -> some View {
    if a11y.showFeedbackPerWord, !a11y.hideScore,
       i < fatte.count, i < indice, !fatte[i].correct {
      Circle().strokeBorder(colore(i), lineWidth: 2.5)
    } else {
      Circle().fill(colore(i))
    }
  }
}

/// L'unico modo di chiudere una schermata.
///
/// Prima erano sei, tutti diversi: un pulsante blu di sistema che diceva
/// «Fine», un rettangolo grigio che diceva «Chiudi», un'etichetta con una
/// crocetta, un pulsantone largo quanto lo schermo, e una scritta da quindici
/// punti in un angolo. Sei forme per un gesto solo. Chi ha imparato che si
/// esce dal riquadro grigio in alto a destra, nella schermata dopo quel
/// riquadro non c'è più — e non sa più come si torna indietro.
///
/// Dice sempre «Chiudi», mai «Fine»: «Fine» somiglia a «conferma», e chi lo
/// legge può credere che, se non lo preme, quello che ha cambiato non valga.
/// Nell'app le impostazioni valgono appena si toccano, quindi «Fine» sarebbe
/// una piccola bugia.
///
/// Usa il colore d'accento del **tema scelto**, non il blu di sistema: con
/// «Altissimo contrasto» il blu di macOS restava blu e vanificava il tema
/// proprio sul comando più importante della schermata.
struct PulsanteChiudi: View {
  @Environment(\.palette) private var palette
  var a11y: EffettiveImpostazioniAccessibilita
  /// Che cosa si sta chiudendo. Serve a VoiceOver, che altrimenti annuncia
  /// quattro pulsanti identici chiamati «Chiudi» in quattro schermate diverse.
  var cosa: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: a11y.size(Metrica.spazioMinimo)) {
        Image(systemName: "xmark")
          .font(a11y.font(.nota, .bold))
        Text("Chiudi")
      }
      .font(a11y.font(.corpo, .semibold))
      .padding(.horizontal, a11y.size(Metrica.spazio))
      .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
      .frame(minWidth: Metrica.bersaglio, minHeight: Metrica.bersaglio)
      .contentShape(Capsule())
    }
    .buttonStyle(StilePulsante(forma: .capsula, a11y: a11y))
    .foregroundStyle(palette.onAccent)
    .background(Capsule().fill(palette.accent))
    .keyboardShortcut(.escape, modifiers: [])
    .accessibilityLabel("Chiudi \(cosa)")
    .accessibilityHint("Puoi anche premere Esc")
  }
}

/// L'intestazione di una pagina che si apre sopra le altre: il titolo a
/// sinistra, il modo per uscire a destra, sempre nello stesso punto.
///
/// Impostazioni, aiuto e progressi la scrivevano ognuna per conto suo, e si
/// erano già allontanate: stesso titolo da 28 punti, ma tre pulsanti diversi
/// e due parole diverse per lo stesso gesto. Da qui in avanti si scrive una
/// volta sola, così restare uguali non richiede che qualcuno se ne ricordi.
struct IntestazionePagina: View {
  @Environment(\.palette) private var palette
  let titolo: String
  /// Una riga sotto il titolo: il nome di chi sta usando l'app, la data.
  var sottotitolo: String? = nil
  var a11y: EffettiveImpostazioniAccessibilita
  let onClose: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: Metrica.filo) {
        Text(titolo)
          .font(a11y.font(.titolo, .bold))
          .foregroundStyle(palette.foreground)
        if let sottotitolo, !sottotitolo.isEmpty {
          Text(.init(sottotitolo))
            .font(a11y.font(.etichetta))
            .foregroundStyle(palette.muted)
        }
      }
      // `combine` unisce titolo e sottotitolo in una frase sola: è come li
      // leggerebbe una persona ad alta voce, invece di due annunci staccati.
      // Il tratto «intestazione» va dopo, su quell'unico elemento con un nome.
      //
      // Avevo scritto qui che senza `combine` il titolo spariva del tutto. Non
      // è vero: l'ho tolto apposta e l'albero mostrava ancora il titolo. La
      // riga resta perché la frase unica è migliore, non perché ripari un
      // guasto.
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      Spacer(minLength: Metrica.spazio)
      PulsanteChiudi(a11y: a11y, cosa: titolo.lowercased(), action: onClose)
    }
    .padding(.horizontal, Metrica.margine)
    .padding(.vertical, Metrica.spazioPiccolo)
  }
}

// MARK: - I controlli di sistema, portati alla misura promessa

/// I controlli che macOS disegna per conto suo — interruttori, cursori, elenchi
/// a comparsa, frecce su e giù — sono alti fra i 16 e i 26 punti.
///
/// L'app prometteva 44 punti «ovunque», e su ogni pulsante scritto a mano lo
/// manteneva; poi bastava aprire le impostazioni e i comandi veri erano
/// bersagli di venti punti, esattamente lì dove un adulto prepara l'app per un
/// ragazzo con paralisi cerebrale. Un `Toggle` non si può ingrandire: si può
/// però rendere premibile **tutta la riga**, e mettere accanto ai cursori due
/// pulsanti grandi per chi il pallino non riesce a prenderlo.
///
/// Nel profilo «Paralisi cerebrale» il minimo sale a 60 punti: prima quel
/// profilo prometteva bersagli grandi e non ne ingrandiva nemmeno uno.

/// Un interruttore che si accende premendo la riga intera.
struct InterruttoreAccessibile: View {
  @Environment(\.palette) private var palette
  let titolo: String
  @Binding var acceso: Bool
  var a11y: EffettiveImpostazioniAccessibilita

  var body: some View {
    Button { acceso.toggle() } label: {
      HStack(spacing: Metrica.spazioPiccolo) {
        Text(titolo)
          .font(a11y.font(.corpo))
          .interlinea(a11y)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: Metrica.spazioPiccolo)
        // L'interruttore resta quello di sistema — si riconosce a colpo
        // d'occhio — ma non intercetta niente: a rispondere è la riga.
        Toggle("", isOn: $acceso)
          .labelsHidden()
          .allowsHitTesting(false)
      }
      .padding(.horizontal, Metrica.spazioStretto)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: a11y.bersaglio)
      .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(palette.foreground)
    .accessibilityRepresentation { Toggle(titolo, isOn: $acceso) }
  }
}

/// Un numero che si alza e si abbassa con due pulsanti grandi.
struct PassoAccessibile: View {
  @Environment(\.palette) private var palette
  let titolo: String
  @Binding var valore: Double
  var intervallo: ClosedRange<Double>
  var passo: Double = 1
  var a11y: EffettiveImpostazioniAccessibilita
  /// Come si dice il valore a voce e a schermo: mai un numero nudo.
  var descrizione: (Double) -> String

  var body: some View {
    HStack(spacing: Metrica.spazioPiccolo) {
      Text(descrizione(valore))
        .font(a11y.font(.corpo))
        .interlinea(a11y)
        .foregroundStyle(palette.foreground)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Metrica.spazioPiccolo)
      pulsante("minus", "meno", -passo)
      pulsante("plus", "più", passo)
    }
    .frame(minHeight: a11y.bersaglio)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(titolo)
    .accessibilityValue(descrizione(valore))
  }

  private func pulsante(_ simbolo: String, _ nome: String, _ delta: Double) -> some View {
    Button {
      valore = min(max(valore + delta, intervallo.lowerBound), intervallo.upperBound)
    } label: {
      Image(systemName: simbolo)
        .font(a11y.font(.corpo, .bold))
        .frame(width: a11y.bersaglio, height: a11y.bersaglio)
        .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(palette.foreground)
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
    .disabled(delta < 0 ? valore <= intervallo.lowerBound : valore >= intervallo.upperBound)
    .accessibilityLabel("\(nome): \(titolo)")
  }
}

/// Un cursore con accanto due pulsanti grandi.
///
/// Il pallino di un cursore è largo una quindicina di punti e va preso al volo:
/// per una mano che trema è il comando più difficile dell'app. I due pulsanti
/// fanno la stessa cosa senza chiedere la mira, e il cursore resta per chi lo
/// preferisce.
struct CursoreAccessibile: View {
  @Environment(\.palette) private var palette
  let titolo: String
  @Binding var valore: Double
  var intervallo: ClosedRange<Double>
  var passo: Double
  var a11y: EffettiveImpostazioniAccessibilita
  var descrizione: (Double) -> String

  var body: some View {
    VStack(alignment: .leading, spacing: Metrica.briciola) {
      HStack {
        Text(titolo)
          .font(a11y.font(.corpo))
          .interlinea(a11y)
          .foregroundStyle(palette.foreground)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: Metrica.spazioStretto)
        Text(descrizione(valore))
          .font(a11y.font(.etichetta))
          .foregroundStyle(palette.muted)
          .monospacedDigit()
      }
      HStack(spacing: Metrica.spazioPiccolo) {
        pulsante("minus", "meno", -passo)
        Slider(value: $valore, in: intervallo, step: passo)
          .controlSize(.large)
          .frame(maxWidth: a11y.size(400), minHeight: a11y.bersaglio)
          .accessibilityLabel(titolo)
          .accessibilityValue(descrizione(valore))
        pulsante("plus", "più", passo)
        Spacer(minLength: 0)
      }
    }
  }

  private func pulsante(_ simbolo: String, _ nome: String, _ delta: Double) -> some View {
    Button {
      valore = min(max(valore + delta, intervallo.lowerBound), intervallo.upperBound)
    } label: {
      Image(systemName: simbolo)
        .font(a11y.font(.corpo, .bold))
        .frame(width: a11y.bersaglio, height: a11y.bersaglio)
        .contentShape(Rectangle())
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .foregroundStyle(palette.foreground)
    .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
    .disabled(delta < 0 ? valore <= intervallo.lowerBound : valore >= intervallo.upperBound)
    .accessibilityLabel("\(nome): \(titolo)")
  }
}

/// Una scelta fra molte: l'elenco a comparsa, ma con un bersaglio vero.
struct SceltaAccessibile<T: Hashable>: View {
  @Environment(\.palette) private var palette
  let titolo: String
  @Binding var scelta: T
  let opzioni: [T]
  var a11y: EffettiveImpostazioniAccessibilita
  let etichetta: (T) -> String

  @State private var aperto = false

  var body: some View {
    HStack(spacing: Metrica.spazioPiccolo) {
      Text(titolo)
        .font(a11y.font(.corpo))
        .interlinea(a11y)
        .foregroundStyle(palette.foreground)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Metrica.spazioStretto)
      // Perche' non e' un `Menu`.
      //
      // Su macOS un `Menu` si fa dare l'altezza dal controllo AppKit che ha
      // sotto, e nessun `frame` scritto in SwiftUI la sposta: qui c'era gia'
      // `.frame(minHeight: a11y.bersaglio)` due volte, e l'area davvero
      // premibile restava di 19 punti sui 44 promessi. Misurato sull'app in
      // esecuzione. La prova in `Verifiche/Bersagli.swift` non se ne accorgeva
      // perche' misurava la riga esterna, che il frame allargava davvero.
      // Le voci **dentro** il menu avevano lo stesso difetto un piano sotto.
      //
      // Un pulsante normale con un pannello a comparsa e' fatto di viste
      // nostre: l'altezza e' quella che scriviamo, qui e in ogni riga.
      Button { aperto.toggle() } label: {
        HStack(spacing: Metrica.spazioMinimo) {
          Text(etichetta(scelta))
            .font(a11y.font(.corpo))
            .lineLimit(1)
          Image(systemName: "chevron.up.chevron.down")
            .font(a11y.font(.nota, .semibold))
        }
        .padding(.horizontal, Metrica.spazioPiccolo)
        .frame(minHeight: a11y.bersaglio)
        .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo).fill(palette.surface))
        .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
      }
      // `StilePulsante` e non `.plain`: lo stile dell'app non mette sfondi né
      // cornici, aggiunge solo l'anello di fuoco e la dichiarazione che rende
      // il pulsante raggiungibile col Tab. Con `.plain` queste righe erano
      // premibili e larghe 44 punti, ma **invisibili alla tastiera**: un
      // elenco che si apre e non si può percorrere senza mouse è una trappola,
      // ed è esattamente il difetto che questo elenco era nato per togliere.
      .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
      .focusable()
      .foregroundStyle(palette.foreground)
      .popover(isPresented: $aperto, arrowEdge: .bottom) {
        ScrollView {
          VStack(alignment: .leading, spacing: Metrica.briciola) {
            ForEach(opzioni, id: \.self) { o in
              Button {
                scelta = o
                aperto = false
              } label: {
                HStack(spacing: Metrica.spazioStretto) {
                  // Mai il colore da solo: il segno di spunta c'e' anche a
                  // parole per chi ascolta con VoiceOver.
                  Image(systemName: o == scelta ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(o == scelta ? palette.accent : palette.muted)
                  Text(etichetta(o))
                    .font(a11y.font(.corpo, o == scelta ? .semibold : .regular))
                    .foregroundStyle(palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                  Spacer(minLength: 0)
                }
                .padding(.horizontal, Metrica.spazioStretto)
                .frame(maxWidth: .infinity, minHeight: a11y.bersaglio, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
                  .fill(o == scelta ? palette.accent.opacity(0.12) : .clear))
                .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
              }
              // `StilePulsante` e non `.plain`: lo stile dell'app non mette sfondi né
              // cornici, aggiunge solo l'anello di fuoco e la dichiarazione che rende
              // il pulsante raggiungibile col Tab. Con `.plain` queste righe erano
              // premibili e larghe 44 punti, ma **invisibili alla tastiera**: un
              // elenco che si apre e non si può percorrere senza mouse è una trappola,
              // ed è esattamente il difetto che questo elenco era nato per togliere.
              .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
              .accessibilityLabel(o == scelta ? "\(etichetta(o)), scelto adesso" : etichetta(o))
            }
          }
          .padding(Metrica.spazioPiccolo)
        }
        .frame(minWidth: a11y.size(260), maxHeight: 460)
        .background(palette.surface)
      }
      .accessibilityLabel(titolo)
      .accessibilityValue(etichetta(scelta))
    }
    .frame(minHeight: a11y.bersaglio)
  }
}
