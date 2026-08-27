import SwiftUI

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
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.typeface.font(size: a11y.size(16), weight: .semibold))
      .padding(.horizontal, a11y.size(18))
      .padding(.vertical, a11y.size(11))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(distruttivo ? palette.wrong : palette.foreground)
    .background(RoundedRectangle(cornerRadius: 11).fill(palette.surface))
    .overlay(
      RoundedRectangle(cornerRadius: 11)
        .stroke(distruttivo ? palette.wrong.opacity(0.5) : palette.muted.opacity(0.35),
                lineWidth: 1.5))
    .frame(minHeight: 44)
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
      HStack(spacing: 14) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(20))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(prominent ? Color.white : palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(prominent ? palette.accent : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
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
      VStack(spacing: 8) {
        if let symbol {
          Image(systemName: symbol).font(.system(size: a11y.size(30)))
        }
        Text(title)
          .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
          .multilineTextAlignment(.center)
        if let subtitle {
          Text(subtitle)
            .font(a11y.typeface.font(size: a11y.size(13)))
            .foregroundStyle(palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, a11y.size(18))
      .padding(.horizontal, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(palette.foreground)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(selected ? palette.accent.opacity(palette.isDark ? 0.32 : 0.16) : palette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(selected ? palette.accent : Color.clear, lineWidth: 3)
    )
    // Il bordo da solo non basta: chi non distingue i colori deve poterlo capire lo stesso.
    .overlay(alignment: .topTrailing) {
      if selected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: a11y.size(18)))
          .foregroundStyle(palette.accent)
          .padding(8)
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
      .font(a11y.typeface.font(size: a11y.size(24), weight: .bold))
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
    HStack(spacing: 6) {
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
      HStack(spacing: a11y.size(10)) {
        ZStack {
          Circle().fill(rosso)
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.white)
            .frame(width: a11y.size(16), height: a11y.size(16))
        }
        .frame(width: a11y.size(38), height: a11y.size(38))

        Text(titolo)
          .font(a11y.typeface.font(size: a11y.size(20), weight: .semibold))
      }
      .padding(.horizontal, a11y.size(16))
      .padding(.vertical, a11y.size(8))
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
            RoundedRectangle(cornerRadius: 2)
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
        HStack(spacing: 8) {
          ForEach(0..<totale, id: \.self) { i in
            Circle()
              .fill(colore(i))
              .frame(width: i == indice - 1 ? 12 : 8,
                     height: i == indice - 1 ? 12 : 8)
          }
        }
        .padding(.bottom, 24)
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
    guard a11y.showFeedbackPerWord, !a11y.hideScore else {
      return palette.muted.opacity(0.75)
    }
    return fatte[i].correct ? palette.ok.opacity(0.8) : palette.wrong.opacity(0.8)
  }
}
