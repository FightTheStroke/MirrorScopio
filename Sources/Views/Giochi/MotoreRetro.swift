import SwiftUI
import Combine

// MARK: - I colori del Commodore 64

/// I sedici colori del Commodore 64, quelli veri.
///
/// Non è una citazione nostalgica per gli adulti: è la ragione per cui quei
/// giochi si vedevano su un televisore scadente a due metri di distanza. Pochi
/// colori, pieni, senza sfumature, ognuno lontanissimo dagli altri — che è
/// esattamente quello che serve a chi vede poco. Il fondo scuro con sopra il
/// giallo, il bianco e il ciano tiene un contrasto altissimo senza il bianco
/// accecante di una pagina.
enum C64 {
  static let nero         = Color(red: 0.00, green: 0.00, blue: 0.00)
  static let bianco       = Color(red: 1.00, green: 1.00, blue: 1.00)
  static let ciano        = Color(red: 0.67, green: 1.00, blue: 0.93)
  static let viola        = Color(red: 0.80, green: 0.40, blue: 0.86)
  static let verde        = Color(red: 0.20, green: 0.78, blue: 0.42)
  static let blu          = Color(red: 0.18, green: 0.16, blue: 0.46)
  static let bluScuro     = Color(red: 0.10, green: 0.09, blue: 0.28)
  static let giallo       = Color(red: 0.96, green: 0.93, blue: 0.42)
  static let arancio      = Color(red: 0.91, green: 0.58, blue: 0.31)
  static let marrone      = Color(red: 0.55, green: 0.35, blue: 0.16)
  static let rosso        = Color(red: 1.00, green: 0.45, blue: 0.45)
  static let verdeChiaro  = Color(red: 0.67, green: 1.00, blue: 0.45)
  static let bluChiaro    = Color(red: 0.45, green: 0.42, blue: 0.88)
  static let grigio       = Color(red: 0.52, green: 0.52, blue: 0.58)
  static let grigioChiaro = Color(red: 0.80, green: 0.80, blue: 0.85)
}

// MARK: - Gli sprite

/// Un disegno a pixel: una riga di testo per ogni riga di pixel, una lettera per
/// ogni colore, il punto per il vuoto. Nel codice si legge come si vedrà sullo
/// schermo — ed è il motivo per cui è scritto così e non con dei numeri.
struct SpritePixel {
  let righe: [String]
  var larghezza: Int { righe.map(\.count).max() ?? 0 }
  var altezza: Int { righe.count }

  /// Lo stesso disegno rivoltato: un personaggio deve poter guardare dall'altra
  /// parte senza che qualcuno lo ridisegni a mano al contrario.
  var specchiato: SpritePixel { SpritePixel(righe: righe.map { String($0.reversed()) }) }
}

// MARK: - Il pennello

/// Chi disegna sullo schermo finto.
///
/// Tiene insieme il contesto di disegno e quanto è grande un pixel, così i
/// giochi ragionano sempre in pixel dello schermo del Commodore — 320×200 — e
/// non sanno nulla di quanto sia larga la finestra. Il contorno nero attorno
/// agli sprite non è un vezzo: è ciò che tiene un personaggio staccato dal
/// fondo anche per chi ha poco contrasto o guarda da lontano.
struct Pennello {
  let ctx: GraphicsContext
  /// Quanti punti dello schermo vero vale un pixel di quello finto.
  let u: Double
  /// Quanti pixel dello schermo finto vale un pixel di uno sprite.
  static let grana: Double = 2

  func rettangolo(_ x: Double, _ y: Double, _ larghezza: Double, _ altezza: Double,
                  _ colore: Color) {
    ctx.fill(Path(CGRect(x: x * u, y: y * u, width: larghezza * u, height: altezza * u)),
             with: .color(colore))
  }

  /// Uno sprite con l'angolo in alto a sinistra dove dici tu.
  func sprite(_ s: SpritePixel, x: Double, y: Double, colori: [Character: Color],
              contorno: Bool = true) {
    let lato = Pennello.grana
    if contorno {
      // Il contorno si disegna guardando i vuoti attorno a ogni pixel pieno:
      // costa poco e fa la differenza fra una figura che si stacca dal fondo e
      // una macchia che ci si confonde dentro.
      for (riga, pixel) in s.righe.enumerated() {
        for (colonna, segno) in pixel.enumerated() where colori[segno] != nil {
          for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let rr = riga + dy, cc = colonna + dx
            let vuoto = rr < 0 || rr >= s.righe.count || cc < 0
              || cc >= s.righe[rr].count
              || colori[Array(s.righe[rr])[cc]] == nil
            guard vuoto else { continue }
            rettangolo(x + Double(cc) * lato, y + Double(rr) * lato, lato, lato, C64.nero)
          }
        }
      }
    }
    for (riga, pixel) in s.righe.enumerated() {
      for (colonna, segno) in pixel.enumerated() {
        guard let colore = colori[segno] else { continue }
        rettangolo(x + Double(colonna) * lato, y + Double(riga) * lato, lato, lato, colore)
      }
    }
  }

  /// Uno sprite con i piedi appoggiati al suolo indicato. Gli sprite non sono
  /// tutti alti uguale, e contare a mano gli scarti è il modo sicuro per
  /// ritrovarsi un personaggio che galleggia sopra il pavimento.
  func appoggia(_ s: SpritePixel, x: Double, suolo: Double, colori: [Character: Color]) {
    sprite(s, x: x, y: suolo - Double(s.altezza) * Pennello.grana, colori: colori)
  }

  /// La larghezza che uno sprite occupa sullo schermo finto.
  static func larghezza(_ s: SpritePixel) -> Double { Double(s.larghezza) * grana }
  static func altezza(_ s: SpritePixel) -> Double { Double(s.altezza) * grana }
}

// MARK: - Quanto è difficile

/// Quanto corre il gioco, e come impara a stare addosso a chi sta giocando.
///
/// Parte dal punto in cui è il ragazzo davvero — quante parole ha preso nella
/// sessione appena finita e quante sessioni ha alle spalle — e poi si muove
/// **mentre** si gioca, con la stessa regola con cui l'app sceglie la durata di
/// una parola: tre cose andate bene e sale di un gradino, una andata male e
/// scende subito. Sale piano e scende in fretta, perché la frustrazione costa
/// molto più della noia a chi apre questa app.
///
/// Non è mai una condizione per vincere: cambia quanto si muove la scena, non
/// se si può arrivare in fondo. In fondo ci si arriva sempre.
struct Difficolta: Equatable {
  /// Da 0 (il più calmo) a 6 (il più mosso).
  private(set) var passo: Int
  private var diFila = 0

  init(passo: Int = 3) { self.passo = max(0, min(6, passo)) }

  /// Il punto di partenza, letto da com'è andata davvero.
  ///
  /// `accuratezza` è la quota di parole prese nell'ultima sessione, se c'è
  /// stata; `sessioniFatte` conta l'esperienza con l'app. Chi apre il gioco
  /// dalle impostazioni, senza aver letto niente, parte in mezzo.
  static func da(accuratezza: Double?, sessioniFatte: Int) -> Difficolta {
    var p = 3
    if let a = accuratezza { p = Int((a * 5).rounded()) }
    p += min(2, sessioniFatte / 10)
    return Difficolta(passo: p)
  }

  static let media = Difficolta(passo: 3)

  /// Quanto vanno veloci le cose che si muovono.
  var velocita: Double { 0.60 + Double(passo) * 0.13 }
  /// Quante cose ci sono da schivare o da prendere.
  var densita: Double { 0.55 + Double(passo) * 0.14 }
  /// Quanto è largo il margine di errore, in pixel dello schermo finto.
  var tolleranza: Double { 18 - Double(passo) * 1.6 }

  var nome: String {
    ["CALMISSIMO", "CALMO", "TRANQUILLO", "GIUSTO", "VIVACE", "VELOCE", "SPRINT"][passo]
  }

  mutating func andataBene() {
    diFila += 1
    if diFila >= 3 { diFila = 0; passo = min(6, passo + 1) }
  }

  mutating func andataMale() {
    diFila = 0
    passo = max(0, passo - 1)
  }
}

// MARK: - Il caso, ma gentile

/// Il generatore dei livelli.
///
/// I livelli sono diversi ogni volta — è la ragione per cui si rigioca — ma il
/// caso qui non è libero: nessun livello può nascere impossibile, e l'ultimo
/// pezzo di strada è sempre sgombro. Un gioco che «non si può perdere» deve
/// valere anche per il livello che il caso ha appena inventato.
enum Sorte {
  static func fra(_ minimo: Double, _ massimo: Double) -> Double {
    massimo <= minimo ? minimo : Double.random(in: minimo...massimo)
  }

  static func fra(_ minimo: Int, _ massimo: Int) -> Int {
    massimo <= minimo ? minimo : Int.random(in: minimo...massimo)
  }

  static func moneta(_ probabilita: Double = 0.5) -> Bool { Double.random(in: 0...1) < probabilita }
}

// MARK: - Il cabinato

/// La cabina del gioco: il televisore, la barra dei punteggi, il tasto unico.
///
/// Tutti e cinque i giochi stanno qui dentro, e non è per risparmiare righe: è
/// perché chi gioca deve trovare **sempre** le stesse cose nello stesso posto.
/// Il punteggio in alto, il campo in mezzo, la frase che dice che cosa fare in
/// basso, «Chiudi» in alto a destra. Cambia il gioco, non dove si guarda.
///
/// Il tasto è uno solo — barra spazio, invio, o un clic in un punto qualsiasi
/// dello schermo — perché chi ha emiparesi gioca con la mano che ha e non deve
/// prendere nessuna mira.
struct CabinatoRetro: View {
  var a11y: EffettiveImpostazioniAccessibilita
  var titolo: String
  var sottotitolo: String
  var punti: Int
  var statoDestra: String
  /// La frase umana sotto lo schermo: né maiuscola né a spaziatura fissa,
  /// perché è l'unica cosa qui dentro che si legge davvero leggendo.
  var frase: String
  var invito: String
  var etichettaVoce: String
  /// Quello che compare in mezzo allo schermo: «ANCORA», «+100», «BRAVO».
  var lampo: LampoRetro?
  var battiti: Int
  var onPremi: () -> Void
  var onBattito: () -> Void
  var onClose: () -> Void
  var disegna: (Pennello) -> Void

  /// Trenta battiti al secondo: il passo dei giochi di allora. La scena si
  /// muove a scatti di un pixel intero, e non è un limite tecnico — è il modo
  /// in cui quei giochi si vedevano.
  private let battito = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

  /// Vero quando la vista sta posando per una fotografia: `ImageRenderer` non
  /// disegna il contenuto di ciò che scorre — provato, esce un rettangolo vuoto
  /// — e senza questa deroga i giochi sarebbero le uniche schermate che non si
  /// possono guardare in PNG, cioè proprio quelle che vanno guardate.
  var perFotografia = false

  private var fermo: Bool { a11y.reducedMotion || a11y.calmMode }

  var body: some View {
    ZStack {
      (a11y.theme == .altoContrasto ? Color.black : C64.bluChiaro).ignoresSafeArea()

      Button(action: onPremi) { Color.clear.contentShape(Rectangle()) }
        // L'unico `.plain` dell'app, e a ragion veduta: questo pulsante è lo
        // schermo intero, e un anello di fuoco lungo i quattro bordi non
        // direbbe «sei qui», direbbe soltanto che c'è una cornice.
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityLabel(etichettaVoce)
        .accessibilityHint("Premi la barra spazio, invio, o fai clic ovunque.")

      Button("", action: onPremi)
        .keyboardShortcut(.return, modifiers: [])
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)

      if perFotografia {
        contenuto.padding(a11y.size(Metrica.spazioPiccolo))
      } else {
        // Con i caratteri al massimo ingrandimento le scritte crescono e il
        // televisore non ci sta più in una finestra da 700: allora si scorre,
        // invece di lasciare fuori schermo la parte bassa proprio a chi il
        // testo l'ha ingrandito perché vede poco.
        ScrollView {
          contenuto
            .frame(maxWidth: .infinity, minHeight: a11y.size(440))
            .padding(a11y.size(Metrica.spazioPiccolo))
        }
        .scrollIndicators(.never)
        .allowsHitTesting(false)
      }

      VStack {
        HStack {
          Spacer()
          PulsanteChiudi(a11y: a11y, cosa: "il gioco", action: onClose)
        }
        .padding(.horizontal, Metrica.spazioMedio)
        .padding(.top, Metrica.spazioPiccolo)
        Spacer()
      }
    }
    .onReceive(battito) { _ in onBattito() }
  }

  private var contenuto: some View {
    VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
      barra
      schermo
      VStack(spacing: a11y.size(Metrica.filo)) {
        Text(sottotitolo)
          .font(.system(size: a11y.size(18), weight: .bold, design: .monospaced))
          .foregroundStyle(C64.ciano)
        Text(frase)
          .font(a11y.font(.corpo))
          .foregroundStyle(C64.grigioChiaro)
          .frame(maxWidth: a11y.size(600))
          .fixedSize(horizontal: false, vertical: true)
      }
      .multilineTextAlignment(.center)
      Text(invito)
        .font(.system(size: a11y.size(17), weight: .bold, design: .monospaced))
        .foregroundStyle(C64.bianco)
        // Se il movimento è spento la scritta sta ferma: un lampeggio è un
        // movimento anche quando è piccolo, e per chi ha ipersensibilità è il
        // più fastidioso di tutti.
        .opacity(fermo || (battiti / 15) % 2 == 0 ? 1 : 0.3)
        .frame(minHeight: a11y.bersaglio)
        .multilineTextAlignment(.center)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: a11y.size(900))
  }

  private var barra: some View {
    HStack(alignment: .firstTextBaseline, spacing: a11y.size(Metrica.spazio)) {
      testo(titolo, C64.giallo)
      Spacer(minLength: 0)
      // Chi si mette in ansia con i numeri ha già una manopola che li toglie in
      // tutta l'app: vale anche qui, e il gioco resta identico senza.
      if !a11y.hideScore { testo("PUNTI \(String(format: "%06d", punti))", C64.bianco) }
      testo(statoDestra, C64.ciano)
    }
    // Il punteggio finiva sotto il pulsante «Chiudi», che sta sopra a tutto:
    // visto in una fotografia, si leggeva «PUNTI 00130» e basta.
    .padding(.trailing, a11y.size(120))
    .accessibilityHidden(true)
  }

  private func testo(_ t: String, _ c: Color) -> some View {
    Text(t)
      .font(.system(size: a11y.size(15), weight: .bold, design: .monospaced))
      .foregroundStyle(a11y.theme == .altoContrasto ? .white : c)
      // Niente rimpicciolimenti: chi ha chiesto testo grande non lo vuole
      // ridotto per far stare la riga. Se non ci sta, va a capo.
      .lineLimit(2)
  }

  private var schermo: some View {
    Canvas { contesto, dimensione in
      disegna(Pennello(ctx: contesto, u: dimensione.width / SchermoRetro.larghezza))
    }
    // Il rapporto fra i lati è quello di allora, 320 per 200: la scena non si
    // deforma mai, si ingrandisce e basta.
    .aspectRatio(SchermoRetro.larghezza / SchermoRetro.altezza, contentMode: .fit)
    .frame(maxWidth: a11y.size(700))
    .background(a11y.theme == .altoContrasto ? Color.black : C64.blu)
    .overlay(alignment: .center) { scrittaLampo }
    .accessibilityHidden(true)
  }

  /// Le uniche parole dentro lo schermo, e sono testo vero: crescono con la
  /// dimensione scelta e le legge VoiceOver, cosa che un disegno a pixel non
  /// saprebbe fare.
  @ViewBuilder
  private var scrittaLampo: some View {
    if let lampo, !(a11y.hideScore && lampo.soloPunteggio) {
      Text(lampo.testo)
        .font(.system(size: a11y.size(lampo.grande ? 40 : 32), weight: .heavy, design: .monospaced))
        .foregroundStyle(lampo.colore)
        .shadow(color: .black, radius: 0, x: 2, y: 2)
    }
  }
}

/// Una parola che compare in mezzo allo schermo per un attimo.
struct LampoRetro: Equatable {
  let testo: String
  let colore: Color
  var grande = true
  /// Vero se è solo un numero: chi ha spento i punteggi non lo vede.
  var soloPunteggio = false

  static let ancora = LampoRetro(testo: "ANCORA", colore: C64.giallo)
  static func punti(_ n: Int) -> LampoRetro {
    LampoRetro(testo: "+\(n)", colore: C64.verdeChiaro, grande: false, soloPunteggio: true)
  }
}

/// Le misure dello schermo finto: 320×200, la risoluzione del Commodore 64.
enum SchermoRetro {
  static let larghezza: Double = 320
  static let altezza: Double = 200
}
