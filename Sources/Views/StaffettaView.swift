import SwiftUI

// MARK: - La staffetta del Fight Camp

/// Il minigioco premio che si sblocca a fine sessione.
///
/// Non è un secondo esercizio: è il contrario. La sessione appena finita
/// chiedeva di leggere in fretta, e per il pubblico di questa app quella è già
/// la fatica più grande della giornata. Un premio che chiedesse riflessi, mira
/// o velocità sarebbe la seconda frustrazione di fila, mascherata da regalo.
/// Perciò qui vale una regola sola, e la incarna tutto il codice sotto: si
/// gioca con **un tasto**, non c'è nessun cronometro, e **non si può perdere**.
///
/// Il gioco racconta il Fight Camp vero — la settimana in cui venti bambini con
/// paralisi cerebrale lavorano ai loro obiettivi, ognuno con il suo tutor. Il
/// senso non è accumulare punti: è accumulare **compagni**. A ogni tappa
/// superata qualcuno si affianca e corre con te, perché al camp non si è mai da
/// soli. E l'ultima cosa la fai tu, con tutti gli altri che ti guardano e fanno
/// il tifo: è la frase con cui finisce la canzone del camp — *now walk it by
/// yourself*, adesso camminaci da solo.
struct StaffettaView: View {
  var a11y: A11ySettings
  /// Chi ha aperto il premio lo chiude quando vuole: il premio non trattiene.
  let onClose: () -> Void

  @Environment(\.palette) private var palette

  @State private var fase: Fase = .presentazione
  /// Quanti compagni corrono con te adesso. Non è un punteggio: è la squadra.
  @State private var squadra: Int = 0
  /// Compare "Ancora" quando il salto non prende: non è un errore, è un invito
  /// a riprovare. Non toglie niente, non riporta indietro.
  @State private var ancora = false
  /// L'istante in cui la fascia del salto ha ripreso a scorrere: serve solo a
  /// sapere dov'è il segnalino quando premi, mai a mettere fretta.
  @State private var inizioOscillazione = Date()

  // Le tappe del camp, nell'ordine in cui le si vive davvero: prima l'acqua,
  // dove anche chi fatica a stare in piedi si muove libero; poi la palestra e
  // la parete; infine il ballo dell'ultima sera. Le prime tre costruiscono la
  // squadra; il ballo lo fai da solo.
  private let tappe: [Tappa] = [
    Tappa(nome: "La piscina",
          gesto: "Tuffati e nuota",
          simbolo: "figure.pool.swim",
          etichettaOstacolo: "l'onda",
          simboloOstacolo: "water.waves",
          compagno: "Nuota accanto a te un nuovo compagno."),
    Tappa(nome: "La palestra",
          gesto: "Salta l'ostacolo",
          simbolo: "figure.gymnastics",
          etichettaOstacolo: "l'ostacolo",
          simboloOstacolo: "square.stack.3d.up.fill",
          compagno: "Salta con te un altro compagno."),
    Tappa(nome: "La parete",
          gesto: "Aggrappati e sali",
          simbolo: "figure.climbing",
          etichettaOstacolo: "l'appiglio",
          simboloOstacolo: "mountain.2.fill",
          compagno: "Sale con te un altro compagno."),
  ]

  // Il ballo dell'ultima sera è una tappa a parte: è quella che fai da solo.
  private let ballo = Tappa(nome: "Il ballo dell'ultima sera",
                            gesto: "Fai il tuo passo",
                            simbolo: "figure.dance",
                            etichettaOstacolo: "la musica",
                            simboloOstacolo: "music.note",
                            compagno: "")

  /// Con "meno animazioni" o in modalità calma niente si muove da solo: per chi
  /// ha ipersensibilità un premio che lampeggia è un'aggressione, non un regalo.
  /// Allora il segnalino sta fermo in mezzo alla zona buona e ogni pressione va
  /// a segno: il gioco resta identico, solo senza movimento.
  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()

      // Il tasto che copre tutto: click ovunque, oppure la barra spazio. Sta
      // dietro alle immagini, che non intercettano niente, così qualsiasi punto
      // dello schermo è premibile — chi ha emiparesi non deve prendere la mira.
      Button(action: premi) {
        Color.clear.contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.space, modifiers: [])
      .accessibilityLabel(etichettaVoce)
      .accessibilityHint("Premi la barra spazio, invio, o fai clic ovunque.")

      // Invio fa esattamente come lo spazio: un secondo tasto, stesso gesto.
      Button("", action: premi)
        .keyboardShortcut(.return, modifiers: [])
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)

      scena
        .allowsHitTesting(false)

      // Chiudere resta la cosa più facile dello schermo. Ma qui non è un
      // «interrompi»: è un premio, e il rosso di allarme del resto dell'app
      // sopra a una festa suonava come uno sgridamento. Sta in alto a destra,
      // dove nessun titolo lo tampona, e resta discreto.
      VStack {
        HStack {
          Spacer()
          Button(action: onClose) {
            HStack(spacing: 7) {
              Image(systemName: "xmark.circle.fill")
              Text("Chiudi").font(a11y.typeface.font(size: a11y.size(15)))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(palette.muted)
          .keyboardShortcut(.escape, modifiers: [])
          .accessibilityLabel("chiudi il gioco e torna al riepilogo")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        Spacer()
      }

      if case .fine = fase {
        Celebrazione(a11y: a11y, intensita: 1)
          .allowsHitTesting(false)
      }
    }
  }

  // MARK: - La scena, fase per fase

  @ViewBuilder
  private var scena: some View {
    switch fase {
    case .presentazione: presentazione
    case .tappa(let i): tappaScena(tappe[i], solo: false)
    case .superata(let i): superataScena(tappe[i])
    case .finale: tappaScena(ballo, solo: true)
    case .fine: fineScena
    }
  }

  private var presentazione: some View {
    VStack(spacing: a11y.size(22)) {
      Spacer(minLength: 0)

      Image(systemName: "figure.run")
        .font(.system(size: a11y.size(90)))
        .foregroundStyle(palette.accent)

      Text("La staffetta del Fight Camp")
        .font(a11y.typeface.font(size: a11y.size(40), weight: .bold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      Text("Attraversa le tappe del camp. A ogni tappa qualcuno viene a correre con te: qui non si è mai da soli.")
        .font(a11y.typeface.font(size: a11y.size(21)))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 560)
        .fixedSize(horizontal: false, vertical: true)

      Text("Un tasto solo. Nessuna fretta: parti quando vuoi.")
        .font(a11y.typeface.font(size: a11y.size(18), weight: .medium))
        .foregroundStyle(palette.accent)
        .multilineTextAlignment(.center)

      invitoAPremere(testo: "Premi per partire")

      Spacer(minLength: 0)
    }
    .padding(36)
  }

  private func tappaScena(_ tappa: Tappa, solo: Bool) -> some View {
    VStack(spacing: a11y.size(18)) {
      // In alto: dove siamo e cosa fare. Poche parole, sempre nello stesso posto.
      VStack(spacing: 6) {
        Text(tappa.nome)
          .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
          .foregroundStyle(palette.foreground)
        Text(solo ? "Adesso l'ultimo pezzo lo fai tu. Loro ti guardano." : tappa.gesto)
          .font(a11y.typeface.font(size: a11y.size(20), weight: .medium))
          .foregroundStyle(solo ? palette.accent : palette.muted)
          .multilineTextAlignment(.center)
      }
      .padding(.top, a11y.size(56))

      Spacer(minLength: 0)

      pista(tappa: tappa, solo: solo)

      // "Ancora": occupa sempre il suo spazio, così la scena non sobbalza
      // quando compare. Se il salto non prende non succede nulla di brutto,
      // esce solo questa parola gentile e si riprova.
      Text(ancora ? "Ancora" : " ")
        .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
        .foregroundStyle(palette.accent)
        .accessibilityHidden(!ancora)

      Spacer(minLength: 0)

      // La fascia del salto: una zona buona larghissima. Non è una barra del
      // tempo — non scade mai. Se non premi, il segnalino continua ad andare
      // avanti e indietro all'infinito e non perdi niente.
      fasciaSalto

      invitoAPremere(testo: solo ? "Premi: fai il tuo passo" : "Premi per superare \(tappa.etichettaOstacolo)")
        .padding(.bottom, a11y.size(30))
    }
    .padding(.horizontal, 36)
  }

  /// La pista con l'avatar, la squadra e l'ostacolo.
  private func pista(tappa: Tappa, solo: Bool) -> some View {
    VStack(spacing: a11y.size(14)) {
      HStack(alignment: .bottom, spacing: a11y.size(10)) {
        // Nel finale i compagni si mettono di lato a fare il tifo; nelle altre
        // tappe corrono insieme a te.
        if solo {
          tifoDellaSquadra
          Spacer(minLength: 0)
          corridore(simbolo: tappa.simbolo, indice: -1, grande: true)
          Spacer(minLength: 0)
          ostacolo(tappa)
        } else {
          corridore(simbolo: tappa.simbolo, indice: -1, grande: true)
          ForEach(0..<squadra, id: \.self) { i in
            corridore(simbolo: simboloCompagno(i), indice: i, grande: false)
          }
          Spacer(minLength: 0)
          ostacolo(tappa)
        }
      }
      .frame(height: a11y.size(120))

      // Il terreno: una riga sola, ferma. Dà il senso della corsa senza rubare
      // lo sguardo con un movimento.
      Capsule()
        .fill(palette.muted.opacity(0.35))
        .frame(height: a11y.size(6))
    }
    .frame(maxWidth: 640)
  }

  /// I compagni schierati che guardano il passo finale.
  private var tifoDellaSquadra: some View {
    HStack(spacing: a11y.size(6)) {
      ForEach(0..<max(1, squadra), id: \.self) { i in
        Image(systemName: simboloCompagno(i))
          .font(.system(size: a11y.size(40)))
          .foregroundStyle(coloreCompagno(i))
      }
    }
    .accessibilityElement()
    .accessibilityLabel(squadra == 1 ? "Un compagno ti guarda e fa il tifo" : "\(squadra) compagni ti guardano e fanno il tifo")
  }

  private func corridore(simbolo: String, indice: Int, grande: Bool) -> some View {
    Image(systemName: simbolo)
      .font(.system(size: grande ? a11y.size(72) : a11y.size(48)))
      .foregroundStyle(indice < 0 ? palette.accent : coloreCompagno(indice))
      // Altezze leggermente diverse: una fila perfettamente dritta sembra una
      // tabella. Con "meno animazioni" si allinea tutto e non si muove niente.
      .offset(y: fermo ? 0 : -passo(indice))
      .accessibilityHidden(true)
  }

  private func ostacolo(_ tappa: Tappa) -> some View {
    Image(systemName: tappa.simboloOstacolo)
      .font(.system(size: a11y.size(56)))
      .foregroundStyle(palette.foreground.opacity(0.7))
      .accessibilityHidden(true)
  }

  /// La fascia del salto. La zona buona (accento) è larghissima: prenderla è
  /// facile. Il segnalino la percorre lentamente; fuori dalla modalità calma si
  /// muove, dentro sta fermo in mezzo alla zona e ogni pressione va a segno.
  private var fasciaSalto: some View {
    GeometryReader { geo in
      let larghezza = geo.size.width
      ZStack(alignment: .leading) {
        Capsule()
          .fill(palette.surface)
        // La zona buona, disegnata: chi guarda vede quant'è grande il margine.
        Capsule()
          .fill(palette.accent.opacity(0.30))
          .frame(width: larghezza * (zonaBuona.upperBound - zonaBuona.lowerBound))
          .offset(x: larghezza * zonaBuona.lowerBound)

        if fermo {
          segnalino
            .offset(x: larghezza * 0.5 - a11y.size(11))
        } else {
          TimelineView(.animation) { contesto in
            let p = posizione(a: contesto.date)
            segnalino
              .offset(x: larghezza * p - a11y.size(11))
          }
        }
      }
    }
    .frame(maxWidth: 640)
    .frame(height: a11y.size(22))
    .accessibilityHidden(true)
  }

  private var segnalino: some View {
    Circle()
      .fill(palette.accent)
      .frame(width: a11y.size(22), height: a11y.size(22))
      .overlay(Circle().stroke(palette.background, lineWidth: 2))
  }

  private func superataScena(_ tappa: Tappa) -> some View {
    VStack(spacing: a11y.size(20)) {
      Spacer(minLength: 0)

      Image(systemName: ColorVision.okSymbol)
        .font(.system(size: a11y.size(92)))
        .foregroundStyle(palette.ok)

      Text("Ce l'hai fatta!")
        .font(a11y.typeface.font(size: a11y.size(38), weight: .bold))
        .foregroundStyle(palette.foreground)

      Text(tappa.compagno)
        .font(a11y.typeface.font(size: a11y.size(24), weight: .medium))
        .foregroundStyle(palette.accent)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)

      // La squadra che cresce, mostrata: sono loro il premio, non un numero.
      HStack(spacing: a11y.size(10)) {
        Image(systemName: "figure.run")
          .font(.system(size: a11y.size(46)))
          .foregroundStyle(palette.accent)
        ForEach(0..<squadra, id: \.self) { i in
          Image(systemName: simboloCompagno(i))
            .font(.system(size: a11y.size(46)))
            .foregroundStyle(coloreCompagno(i))
        }
      }
      .accessibilityElement()
      .accessibilityLabel(squadra == 1 ? "Adesso siete in due" : "Adesso siete in \(squadra + 1)")

      invitoAPremere(testo: "Premi per continuare")

      Spacer(minLength: 0)
    }
    .padding(36)
  }

  private var fineScena: some View {
    VStack(spacing: a11y.size(20)) {
      Spacer(minLength: 0)

      // Tutta la squadra insieme a te: chi ha corso, chi ha fatto il tifo.
      HStack(spacing: a11y.size(8)) {
        Image(systemName: "figure.dance")
          .font(.system(size: a11y.size(56)))
          .foregroundStyle(palette.accent)
        ForEach(0..<squadra, id: \.self) { i in
          Image(systemName: simboloCompagno(i))
            .font(.system(size: a11y.size(52)))
            .foregroundStyle(coloreCompagno(i))
        }
      }
      .accessibilityElement()
      .accessibilityLabel("Sei arrivato in fondo, con tutta la tua squadra")

      Text("L'hai fatto da solo.")
        .font(a11y.typeface.font(size: a11y.size(40), weight: .bold))
        .foregroundStyle(palette.foreground)
        .multilineTextAlignment(.center)

      // La frase della canzone del camp, tradotta accanto perché si capisca.
      Text("«Now walk it by yourself» — adesso camminaci da solo. E ci sei riuscito.")
        .font(a11y.typeface.font(size: a11y.size(22)))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 560)
        .fixedSize(horizontal: false, vertical: true)

      // Il principio della fondazione, detto al ragazzo.
      Text("Non era «non so farlo». Era «non so ANCORA farlo».")
        .font(a11y.typeface.font(size: a11y.size(20), weight: .medium))
        .foregroundStyle(palette.accent)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 14) {
        BigButton(title: "Di nuovo", symbol: "arrow.clockwise", a11y: a11y, prominent: false) {
          ricomincia()
        }
        BigButton(title: "Torna al report", symbol: "checkmark", a11y: a11y) {
          onClose()
        }
      }
      .frame(maxWidth: 520)

      Spacer(minLength: 0)
    }
    .padding(36)
  }

  /// L'invito a premere, uguale in ogni scena: una parola e un simbolo, senza
  /// mai un conto alla rovescia.
  private func invitoAPremere(testo: String) -> some View {
    HStack(spacing: a11y.size(10)) {
      Image(systemName: "hand.tap.fill")
        .font(.system(size: a11y.size(22)))
      Text(testo)
        .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
    }
    .foregroundStyle(palette.foreground)
    .padding(.horizontal, a11y.size(18))
    .padding(.vertical, a11y.size(12))
    .background(Capsule().fill(palette.surface))
    .overlay(Capsule().stroke(palette.accent.opacity(0.4), lineWidth: 2))
    // Respira piano, per invitare senza incalzare. Ferma con "meno animazioni".
    .modifier(RespiroDolce(attivo: !fermo, a11y: a11y))
    .accessibilityHidden(true)
  }

  // MARK: - Il gesto: un tasto solo decide tutto

  private func premi() {
    switch fase {
    case .presentazione:
      vaiA(.tappa(0))

    case .tappa(let i):
      if colpito() {
        vaiA(.superata(i))
      } else {
        // Niente di brutto: solo "Ancora", e si riprova subito.
        mostraAncora()
      }

    case .superata(let i):
      squadra += 1
      if i + 1 < tappe.count {
        vaiA(.tappa(i + 1))
      } else {
        vaiA(.finale)
      }

    case .finale:
      if colpito() {
        vaiA(.fine)
      } else {
        mostraAncora()
      }

    case .fine:
      // Da qui il tasto non fa più nulla: si sceglie con i due pulsanti, così
      // non si esce per sbaglio dalla festa con una pressione di troppo.
      break
    }
  }

  /// Vero se la pressione è caduta nella zona buona. Con il movimento fermo il
  /// segnalino è sempre in mezzo alla zona, quindi è sempre vero: in modalità
  /// calma non si può mancare.
  private func colpito() -> Bool {
    guard !fermo else { return true }
    return zonaBuona.contains(posizione(a: Date()))
  }

  private func mostraAncora() {
    ancora = true
    // La scritta se ne va da sola dopo un attimo; il segnalino non si è fermato
    // e non è tornato indietro, quindi basta ripremere.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
      ancora = false
    }
  }

  private func vaiA(_ nuova: Fase) {
    ancora = false
    inizioOscillazione = Date()
    withAnimation(a11y.animation(0.3)) {
      fase = nuova
    }
  }

  private func ricomincia() {
    squadra = 0
    vaiA(.presentazione)
  }

  // MARK: - Il segnalino che va avanti e indietro

  /// Larga il 70% della fascia: mancarla è difficile, prenderla è la norma.
  private var zonaBuona: ClosedRange<Double> { 0.15...0.85 }

  /// Dove si trova il segnalino a un certo istante: un'onda triangolare lenta,
  /// che rimbalza fra un bordo e l'altro senza mai fermarsi. Non c'è inizio né
  /// fine: aspettare non costa nulla.
  private func posizione(a data: Date) -> Double {
    let periodo = 2.8
    let t = data.timeIntervalSince(inizioOscillazione)
    let fase = (t.truncatingRemainder(dividingBy: periodo)) / periodo
    return fase < 0.5 ? fase * 2 : 2 - fase * 2
  }

  /// Di quanto sta su ciascun compagno.
  ///
  /// Altezze diverse, sempre le stesse: una fila perfettamente allineata sembra
  /// una tabella, una fila irregolare sembra gente. Non si muove nel tempo — un
  /// movimento continuo ai bordi dello schermo e esattamente cio che disturba
  /// chi fa fatica a stare sul compito.
  private func passo(_ indice: Int) -> CGFloat {
    let altezze: [Double] = [0, 6, 3, 8, 2, 5]
    let i = indice < 0 ? 0 : indice % altezze.count
    return a11y.size(altezze[i])
  }

  // MARK: - I compagni

  // I simboli dei corridori includono chi va in carrozzina, perché è la squadra
  // vera del camp: definire qualcuno per la carrozzina sarebbe sbagliato, ma
  // toglierla del tutto vorrebbe dire cancellare i bambini che ci sono.
  private let simboliCompagni = [
    "figure.roll", "figure.walk", "figure.run", "figure.and.child.holdinghands",
  ]
  private let coloriCompagni: [Color] = [
    Color(red: 0.98, green: 0.75, blue: 0.14),
    Color(red: 0.38, green: 0.80, blue: 0.45),
    Color(red: 0.95, green: 0.44, blue: 0.60),
    Color(red: 0.62, green: 0.48, blue: 0.92),
  ]

  private func simboloCompagno(_ i: Int) -> String { simboliCompagni[i % simboliCompagni.count] }
  private func coloreCompagno(_ i: Int) -> Color { coloriCompagni[i % coloriCompagni.count] }

  // MARK: - Voce

  /// L'etichetta che VoiceOver legge sul tasto grande: da sola deve bastare a
  /// capire dove siamo e cosa succede premendo, così il gioco si segue anche
  /// solo ascoltando.
  private var etichettaVoce: String {
    switch fase {
    case .presentazione:
      "La staffetta del Fight Camp. Premi per partire."
    case .tappa(let i):
      "\(tappe[i].nome). \(tappe[i].gesto). Premi per superare \(tappe[i].etichettaOstacolo). Corrono con te \(squadra) compagni."
    case .superata(let i):
      "Superata: \(tappe[i].nome). \(tappe[i].compagno) Premi per continuare."
    case .finale:
      "\(ballo.nome). Adesso l'ultimo passo lo fai da solo, mentre la squadra fa il tifo. Premi per farlo."
    case .fine:
      "L'hai fatto da solo. Sei arrivato in fondo con tutta la tua squadra."
    }
  }
}

// MARK: - Dati di una tappa

private struct Tappa {
  let nome: String
  let gesto: String
  let simbolo: String
  let etichettaOstacolo: String
  let simboloOstacolo: String
  /// La frase che annuncia il compagno che si aggiunge. Vuota per il ballo.
  let compagno: String
}

// MARK: - Fasi del gioco

private enum Fase: Equatable {
  case presentazione
  case tappa(Int)
  case superata(Int)
  case finale
  case fine
}

// MARK: - Un respiro, non un lampeggio

/// Fa pulsare piano un elemento per invitare a premere. È un respiro lento, non
/// un allarme: si spegne del tutto quando il movimento va evitato.
private struct RespiroDolce: ViewModifier {
  let attivo: Bool
  let a11y: A11ySettings
  @State private var grande = false

  func body(content: Content) -> some View {
    if attivo {
      content
        .scaleEffect(grande ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: grande)
        .onAppear { grande = true }
    } else {
      content
    }
  }
}
