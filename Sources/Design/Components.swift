import SwiftUI

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
