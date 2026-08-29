import SwiftUI

// MARK: - La sala giochi del Fight Camp

/// Il premio che si sblocca a fine sessione: cinque giochi, e si sceglie.
///
/// Non è un secondo esercizio, è il contrario. La sessione appena finita
/// chiedeva di leggere in fretta, e per chi usa questa app quella è già la
/// fatica più grande della giornata. Un premio che chiedesse riflessi, mira o
/// velocità sarebbe la seconda frustrazione di fila, mascherata da regalo.
/// Perciò tutti e cinque i giochi obbediscono alle stesse tre regole, e non è
/// una scelta di stile: si gioca con **un tasto solo**, non c'è **nessun
/// cronometro**, e **non si può perdere**. Quando qualcosa non riesce non si
/// perde una vita e non si ricomincia: compare «ANCORA» e si continua.
///
/// I giochi sono quelli veri del Commodore 64 — le piattaforme, la traversata,
/// lo sciame, i mattoni, la grotta — perché quei giochi erano fatti per un
/// televisore scadente guardato da lontano: pochi colori pieni, figure grandi,
/// una regola sola da capire. È esattamente ciò che serve qui.
///
/// **Scegliere è metà del premio.** Chi ha appena finito un esercizio in cui
/// tutto era deciso da qualcun altro — quali parole, quanto veloci, quante
/// volte — qui decide da sé, e nessuna delle cinque scelte è quella sbagliata.
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

  @State private var scelto: Gioco?

  var body: some View {
    if let scelto {
      // Il tasto «Chiudi» del gioco riporta alla sala, non fuori dal premio:
      // chi ha aperto un gioco per sbaglio non si ritrova buttato fuori.
      gioco(scelto, indietro: { self.scelto = nil })
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
      VStack(spacing: a11y.size(Metrica.spazioPiccolo)) {
        ForEach(Gioco.allCases) { g in scheda(g) }
      }
      .frame(maxWidth: a11y.size(660))
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
      Text("Cinque giochi. Scegli tu.")
        .font(a11y.font(.corpo))
        .foregroundStyle(C64.bianco)
    }
    .multilineTextAlignment(.center)
    .padding(.trailing, a11y.size(80))
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

  /// I cinque giochi. Il nome dice che cosa succede, non a che genere
  /// appartiene: «La traversata», non «un platform a scorrimento».
  enum Gioco: String, CaseIterable, Identifiable {
    case corsa, traversata, bolle, muro, grotta

    var id: String { rawValue }

    var nome: String {
      switch self {
      case .corsa: "La corsa"
      case .traversata: "La traversata"
      case .bolle: "Le bolle"
      case .muro: "Il muro"
      case .grotta: "La grotta"
      }
    }

    var cosa: String {
      switch self {
      case .corsa: "Le quattro tappe del Fight Camp, una sopra l'altra. A ogni tappa un compagno resta a fare il tifo per te."
      case .traversata: "Un fiume, e delle zattere che passano. Chi finisce in acqua galleggia e riprova."
      case .bolle: "Bolle di sapone che scendono, e una retina che scorre da sola in basso."
      case .muro: "I mattoni da buttare giù con la pallina. Sotto la racchetta c'è un trampolino."
      case .grotta: "Si cammina verso l'uscita mentre cadono i massi. Le gemme sono lungo la strada."
      }
    }

    var tasto: String {
      switch self {
      case .corsa: "salta."
      case .traversata: "salta sulla zattera che sta passando."
      case .bolle: "la retina scatta in su e prende."
      case .muro: "la racchetta cambia direzione."
      case .grotta: "ti fermi, e riparti."
      }
    }

    var simbolo: String {
      switch self {
      case .corsa: "figure.run"
      case .traversata: "water.waves"
      case .bolle: "bubbles.and.sparkles"
      case .muro: "square.grid.3x3.fill"
      case .grotta: "mountain.2.fill"
      }
    }

    var tinta: Color {
      switch self {
      case .corsa: C64.giallo
      case .traversata: C64.ciano
      case .bolle: C64.verdeChiaro
      case .muro: C64.arancio
      case .grotta: C64.grigioChiaro
      }
    }
  }
}
