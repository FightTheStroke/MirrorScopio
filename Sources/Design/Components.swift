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
  var a11y: A11ySettings
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
    .buttonStyle(.plain)
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
  var a11y: A11ySettings
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
    .buttonStyle(.plain)
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
  var a11y: A11ySettings
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: Metrica.spazioStretto) {
        if let symbol {
          Image(systemName: symbol).font(.system(size: a11y.size(30)))
        }
        Text(title)
          .font(a11y.font(.guida, .semibold))
          .multilineTextAlignment(.center)
        if let subtitle {
          Text(subtitle)
            .font(a11y.font(.nota))
            .foregroundStyle(palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(Metrica.spazioMedio))
      .padding(.horizontal, Metrica.spazioStretto)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: Metrica.raggio)
        .fill(selected ? palette.accent.opacity(palette.isDark ? 0.32 : 0.16) : palette.surface)
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
  var a11y: A11ySettings

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
  var a11y: A11ySettings
  var size: Double = 17

  var body: some View {
    Text(.init(text))
      .font(a11y.typeface.font(size: a11y.size(size)))
      .foregroundStyle(palette.muted)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Esito di una parola: colore *e* simbolo *e* parola. Mai il colore da solo.
struct Verdict: View {
  @Environment(\.palette) private var palette
  let correct: Bool
  var a11y: A11ySettings
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
  var a11y: A11ySettings
  var titolo = "Basta"
  let action: () -> Void

  private var rosso: Color {
    palette.isDark
      ? Color(red: 1.0, green: 0.36, blue: 0.36)
      : Color(red: 0.85, green: 0.13, blue: 0.16)
  }

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
    .buttonStyle(.plain)
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
  var a11y: A11ySettings
  /// Da 0 a 1: quanti coriandoli. Il minimo non è mai zero.
  var intensita: Double = 1

  @State private var partita = false

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
  var a11y: A11ySettings
  /// «parola» o «frase»: cambia il compito, non la forma.
  var nomeDellUnita: String = "parola"

  var body: some View {
    if totale > 0 {
      VStack {
        Spacer()
        HStack(spacing: Metrica.spazioStretto) {
          ForEach(0..<totale, id: \.self) { i in
            Circle()
              .fill(colore(i))
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
    guard i < fatte.count, i < indice else { return palette.muted.opacity(0.25) }
    // Una parola interrotta dal Mac non è un risultato: resta neutra, come
    // quelle non ancora arrivate. Colorarla di rosso sarebbe dire al ragazzo
    // che ha sbagliato una parola che non ha mai visto.
    guard !fatte[i].interrotto else { return palette.muted.opacity(0.4) }
    guard a11y.showFeedbackPerWord, !a11y.hideScore else {
      return palette.muted.opacity(0.75)
    }
    return fatte[i].correct ? palette.ok.opacity(0.8) : palette.wrong.opacity(0.8)
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
  var a11y: A11ySettings
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
    .buttonStyle(.plain)
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
  var a11y: A11ySettings
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
