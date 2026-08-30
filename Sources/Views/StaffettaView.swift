import SwiftUI

// MARK: - La sala giochi del Fight Camp

/// Il premio che si sblocca a fine sessione: tredici giochi, e si sceglie.
///
/// Non è un secondo esercizio, è il contrario. La sessione appena finita
/// chiedeva di leggere in fretta, e per chi usa questa app quella è già la
/// fatica più grande della giornata. Un premio che chiedesse riflessi, mira o
/// velocità sarebbe la seconda frustrazione di fila, mascherata da regalo.
/// Perciò tutti i giochi obbediscono alle stesse tre regole, e non è
/// una scelta di stile: si gioca con **un tasto solo**, non c'è **nessun
/// cronometro**, e **non si può perdere**. Quando qualcosa non riesce non si
/// perde una vita e non si ricomincia: compare «ANCORA» e si continua.
///
/// I primi cinque sono i giochi veri del Commodore 64 — le piattaforme, la
/// traversata, lo sciame, i mattoni, la grotta — perché quei giochi erano
/// fatti per un televisore scadente guardato da lontano: pochi colori pieni,
/// figure grandi, una regola sola da capire. È esattamente ciò che serve qui.
///
/// Gli altri otto sono **gli sport veri del Fight Camp**, uno per edizione:
/// l'arrampicata del 2020 sulla parete del Politecnico, la scherma in
/// carrozzina del 2021, la vela di Nave Italia del 2022, il triciclo Ormesa
/// del 2023, lo skate del 2024, il beach volley del 2025, la boxe e l'hip hop del 2026. In
/// ognuno il tasto fa il gesto vero di quello sport: afferrare la presa,
/// affondare, tirare la cima a tempo con l'onda, pedalare, spostare il peso,
/// alzare le mani, muovere i piedi. Non sono cartoline: sono la stessa cosa
/// che i ragazzi hanno fatto davvero, ridotta a un tasto.
///
/// **Scegliere è metà del premio.** Chi ha appena finito un esercizio in cui
/// tutto era deciso da qualcun altro — quali parole, quanto veloci, quante
/// volte — qui decide da sé, e nessuna delle tredici scelte è quella sbagliata.
struct StaffettaView: View {
  var a11y: EffettiveImpostazioniAccessibilita
  /// Quanto si muove la scena: viene da com'è andata davvero l'ultima
  /// sessione. Non decide se si arriva in fondo — in fondo ci si arriva
  /// sempre — decide solo il passo.
  var difficolta: Difficolta = .media
  /// Chi ha aperto il premio lo chiude quando vuole: il premio non trattiene.
  let onClose: () -> Void
  /// Solo per le fotografie di `scripts/disegna-schermate.swift`: `ImageRenderer`
  /// disegna una `ScrollView` vuota, e senza questa scorciatoia l'unica schermata
  /// che non si potrebbe mai guardare fuori dall'app sarebbe proprio la prima.
  var perFotografia = false
  /// Il gioco da aprire subito, saltando la sala.
  ///
  /// Serve alle impostazioni, dove l'adulto sceglie *quale* gioco guardare
  /// dall'elenco: costringerlo a scegliere due volte — una nell'elenco delle
  /// impostazioni e una nella sala — sarebbe un passaggio in più senza motivo.
  /// Chiudendo il gioco si torna comunque alla sala, così da lì se ne può
  /// provare un altro.
  var apertoSu: Gioco?

  @State private var scelto: Gioco?
  /// Il gioco d'ingresso si apre una volta sola: senza questa memoria, tornare
  /// alla sala lo riaprirebbe all'infinito e non si uscirebbe più.
  @State private var giaEntrato = false

  var body: some View {
    contenuto
      .onAppear {
        guard !giaEntrato else { return }
        giaEntrato = true
        if let apertoSu { scelto = apertoSu }
      }
  }

  @ViewBuilder
  private var contenuto: some View {
    if let scelto {
      // Il tasto «Chiudi» del gioco riporta alla sala, non fuori dal premio:
      // chi ha aperto un gioco per sbaglio non si ritrova buttato fuori.
      //
      // Ma se il gioco è stato aperto **direttamente** — dall'elenco delle
      // impostazioni, dove i tredici giochi sono già scritti uno per uno —
      // chiuderlo riporta fuori, da dove si era partiti. Passare dalla sala
      // vorrebbe dire farsi rileggere lo stesso elenco una seconda volta, in
      // un'altra veste: sembrava che l'app si fosse duplicata.
      gioco(scelto, indietro: {
        if apertoSu != nil { onClose() } else { self.scelto = nil }
      })
    } else {
      sala
    }
  }

  @ViewBuilder
  private func gioco(_ quale: Gioco, indietro: @escaping () -> Void) -> some View {
    switch quale {
    case .corsa: GiocoCorsa(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .traversata: GiocoTraversata(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .bolle: GiocoBolle(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .muro: GiocoMuro(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .grotta: GiocoGrotta(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .arrampicata: GiocoArrampicata(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .scherma: GiocoScherma(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .vela: GiocoVela(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .triciclo: GiocoTriciclo(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .skate: GiocoSkate(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .beach: GiocoBeach(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .boxe: GiocoBoxe(a11y: a11y, difficolta: difficolta, onClose: indietro)
    case .hiphop: GiocoHipHop(a11y: a11y, difficolta: difficolta, onClose: indietro)
    }
  }

  // MARK: - La sala

  private var sala: some View {
    ZStack {
      (a11y.theme == .altoContrasto ? Color.black : C64.bluChiaro).ignoresSafeArea()

      if perFotografia {
        elenco
      } else {
        ScrollView { elenco }
          .scrollIndicators(.automatic)
      }

      VStack {
        HStack {
          Spacer()
          PulsanteChiudi(a11y: a11y, cosa: "la sala giochi", action: onClose)
        }
        .padding(.horizontal, Metrica.spazioMedio)
        .padding(.top, Metrica.spazioPiccolo)
        Spacer()
      }
    }
  }

  private var elenco: some View {
    VStack(spacing: a11y.size(Metrica.spazioMedio)) {
      intestazione
      // Una colonna sola. Una griglia costringe a cercare dove si è rimasti;
      // un elenco si scorre con un dito e con il tasto Tab, e sopravvive ai
      // caratteri ingranditi il doppio senza scomporsi.
      //
      // Tredici voci di fila sono troppe da guardare tutte insieme: stanno in
      // due gruppi con un titolo sopra, così si sa sempre in che metà si è.
      ForEach(Gruppo.allCases) { gruppo in
        VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
          titoloGruppo(gruppo)
          ForEach(Gioco.allCases.filter { $0.gruppo == gruppo }) { g in scheda(g) }
        }
        .frame(maxWidth: a11y.size(660))
      }
      promessa
    }
    .frame(maxWidth: .infinity)
    .padding(a11y.size(Metrica.spazio))
    .padding(.top, a11y.size(Metrica.spazioGrande))
  }

  private var intestazione: some View {
    VStack(spacing: a11y.size(Metrica.spazioMinimo)) {
      Text("SALA GIOCHI")
        .font(.system(size: a11y.size(30), weight: .heavy, design: .monospaced))
        .foregroundStyle(a11y.theme == .altoContrasto ? .white : C64.giallo)
      Text("Tredici giochi. Scegli tu.")
        .font(a11y.font(.corpo))
        .foregroundStyle(C64.bianco)
    }
    .multilineTextAlignment(.center)
    .padding(.trailing, a11y.size(80))
  }

  private func titoloGruppo(_ gruppo: Gruppo) -> some View {
    VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMinimo)) {
      Text(gruppo.nome)
        .font(.system(size: a11y.size(18), weight: .heavy, design: .monospaced))
        .foregroundStyle(a11y.theme == .altoContrasto ? .white : C64.ciano)
      Text(gruppo.cosa)
        .font(a11y.font(.etichetta))
        .foregroundStyle(C64.grigioChiaro)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, a11y.size(Metrica.spazioPiccolo))
    .accessibilityAddTraits(.isHeader)
  }

  private func scheda(_ g: Gioco) -> some View {
    Button { scelto = g } label: { etichetta(g) }
      .buttonStyle(.plain)
      .accessibilityLabel("\(g.nome). \(g.cosa)")
      .accessibilityHint("Il tasto: \(g.tasto). Non si può perdere.")
  }

  private func etichetta(_ g: Gioco) -> some View {
    let tinta: Color = a11y.theme == .altoContrasto ? .white : g.tinta
    let bordo: Color = a11y.theme == .altoContrasto ? .white : g.tinta.opacity(0.7)
    let titolo: Color = a11y.theme == .altoContrasto ? .white : C64.giallo
    return HStack(alignment: .top, spacing: a11y.size(Metrica.spazioMedio)) {
      // L'icona non porta nessuna informazione da sola: il nome del gioco e
      // che cosa fa il tasto stanno scritti accanto, a parole.
      Image(systemName: g.simbolo)
        .font(.system(size: a11y.size(26), weight: .bold))
        .foregroundStyle(tinta)
        .frame(width: a11y.size(44), height: a11y.size(44))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioMinimo)) {
        Text(g.nome)
          .font(.system(size: a11y.size(20), weight: .bold, design: .monospaced))
          .foregroundStyle(titolo)
        Text(g.cosa)
          .font(a11y.font(.corpo))
          .foregroundStyle(C64.bianco)
          .fixedSize(horizontal: false, vertical: true)
        Text("Il tasto: " + g.tasto)
          .font(a11y.font(.etichetta))
          .foregroundStyle(C64.ciano)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .multilineTextAlignment(.leading)
    .padding(a11y.size(Metrica.spazioMedio))
    .frame(maxWidth: .infinity, minHeight: a11y.bersaglio, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: Metrica.spazioPiccolo).fill(C64.blu))
    .overlay(
      RoundedRectangle(cornerRadius: Metrica.spazioPiccolo)
        .strokeBorder(bordo, lineWidth: Metrica.filo)
    )
    .contentShape(Rectangle())
  }

  private var promessa: some View {
    Text("Valgono per tutti: un tasto solo, nessun tempo che scade, non si può perdere. Quando qualcosa non riesce non si torna indietro — compare «Ancora», e si continua.")
      .font(a11y.font(.etichetta))
      .foregroundStyle(C64.grigioChiaro)
      .multilineTextAlignment(.center)
      .frame(maxWidth: a11y.size(620))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// Le due metà della sala. Non è una classifica: è solo un modo per non
  /// mettere dodici voci di fila senza un respiro.
  enum Gruppo: String, CaseIterable, Identifiable {
    case arcade, camp

    var id: String { rawValue }

    var nome: String {
      switch self {
      case .arcade: "I GIOCHI"
      case .camp: "GLI SPORT DEL CAMP"
      }
    }

    var cosa: String {
      switch self {
      case .arcade: "Quelli con cui si giocava trent'anni fa, davanti a un televisore."
      case .camp: "Uno per ogni edizione del Fight Camp, con il gesto vero di quello sport."
      }
    }
  }

  /// I tredici giochi. Il nome dice che cosa succede, non a che genere
  /// appartiene: «La traversata», non «un platform a scorrimento».
  enum Gioco: String, CaseIterable, Identifiable {
    case corsa, traversata, bolle, muro, grotta
    case arrampicata, scherma, vela, triciclo, skate, beach, boxe, hiphop

    var id: String { rawValue }

    var gruppo: Gruppo {
      switch self {
      case .corsa, .traversata, .bolle, .muro, .grotta: .arcade
      case .arrampicata, .scherma, .vela, .triciclo, .skate, .beach, .boxe, .hiphop: .camp
      }
    }

    var nome: String {
      switch self {
      case .corsa: "La corsa"
      case .traversata: "La traversata"
      case .bolle: "Le bolle"
      case .muro: "Il muro"
      case .grotta: "La grotta"
      case .arrampicata: "L'arrampicata"
      case .scherma: "La scherma"
      case .vela: "La vela"
      case .triciclo: "Il triciclo"
      case .skate: "Lo skate"
      case .beach: "Il beach volley"
      case .boxe: "La boxe"
      case .hiphop: "L'hip hop"
      }
    }

    var cosa: String {
      switch self {
      case .corsa: "Le quattro tappe del Fight Camp, una sopra l'altra. A ogni tappa un compagno resta a fare il tifo per te."
      case .traversata: "Un fiume, e delle zattere che passano. Chi finisce in acqua galleggia e riprova."
      case .bolle: "Bolle di sapone che scendono, e una retina che scorre da sola in basso."
      case .muro: "I mattoni da buttare giù con la pallina. Sotto la racchetta c'è un trampolino."
      case .grotta: "Si cammina verso l'uscita mentre cadono i massi. Le gemme sono lungo la strada."
      case .arrampicata: "La parete del camp del 2020, quella coi sensori. La mano scorre sopra di te e cerca la presa."
      case .scherma: "Scherma in carrozzina, 2021. Il compagno tiene la guardia, poi per un attimo si scopre."
      case .vela: "Nave Italia, 2022. Si issa la vela a tempo con l'onda, da Civitavecchia a La Spezia."
      case .triciclo: "Il triciclo del 2023. Ogni pedalata dà spinta, e in salita la spinta cala prima."
      case .skate: "La tavola del 2024. Pende sempre da una parte: si sposta il peso e si resta in mezzo."
      case .beach: "Beach volley del 2025. L'ombra sulla sabbia dice dove cade il pallone."
      case .boxe: "La boxe del 2026. Contano i piedi: il diretto parte da solo quando sei nella misura."
      case .hiphop: "L'hip hop del 2026. I passi arrivano da destra: si sta a tempo, e alla fine si balla davanti a tutti."
      }
    }

    var tasto: String {
      switch self {
      case .corsa: "salta."
      case .traversata: "salta sulla zattera che sta passando."
      case .bolle: "la retina scatta in su e prende."
      case .muro: "la racchetta cambia direzione."
      case .grotta: "ti fermi, e riparti."
      case .arrampicata: "la mano afferra la presa."
      case .scherma: "parte l'affondo."
      case .vela: "tiri la cima."
      case .triciclo: "una pedalata."
      case .skate: "sposti il peso dall'altra parte."
      case .beach: "alzi le mani e palleggi."
      case .boxe: "cambi direzione, avanti o indietro."
      case .hiphop: "fai il passo, quando è sulla riga."
      }
    }

    var simbolo: String {
      switch self {
      case .corsa: "figure.run"
      case .traversata: "water.waves"
      case .bolle: "bubbles.and.sparkles"
      case .muro: "square.grid.3x3.fill"
      case .grotta: "mountain.2.fill"
      case .arrampicata: "figure.climbing"
      case .scherma: "figure.fencing"
      case .vela: "sailboat.fill"
      case .triciclo: "bicycle"
      case .skate: "figure.skateboarding"
      case .beach: "figure.volleyball"
      case .boxe: "figure.boxing"
      case .hiphop: "figure.dance"
      }
    }

    var tinta: Color {
      switch self {
      case .corsa: C64.giallo
      case .traversata: C64.ciano
      case .bolle: C64.verdeChiaro
      case .muro: C64.arancio
      case .grotta: C64.grigioChiaro
      case .arrampicata: C64.verdeChiaro
      case .scherma: C64.grigioChiaro
      case .vela: C64.ciano
      case .triciclo: C64.rosso
      case .skate: C64.marrone
      case .beach: C64.giallo
      case .boxe: C64.viola
      case .hiphop: C64.arancio
      }
    }
  }
}
