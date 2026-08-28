import SwiftUI

/// Dice a schermo che c'è un problema con i dati salvati.
///
/// Nasce dal difetto peggiore trovato in questa app: non uno che la fa smettere
/// di funzionare — quelli si vedono — ma uno che perdeva tutto in silenzio.
/// L'app ripartiva vuota e al primo salvataggio ci scriveva sopra. Adesso i
/// file non si toccano finché qualcuno non ha letto che cosa è successo e non
/// ha scelto.
struct AvvisoDati: ViewModifier {
  @ObservedObject var store: Store

  /// Quale finestra è aperta. Un `enum` invece di due `Bool`: due `.alert`
  /// incatenati sulla stessa vista sono il modo classico per ritrovarsi con un
  /// pulsante che non fa niente, perché il secondo viene chiesto mentre SwiftUI
  /// sta ancora smontando il primo.
  private enum Finestra: Int, Identifiable {
    case guasto, confermaRicomincia
    var id: Int { rawValue }
  }
  @State private var finestra: Finestra?
  @State private var confermaInCorso = false

  private var titolo: String {
    switch store.genereDelGuasto {
    case .lettura: return "Non sono riuscita a leggere i dati salvati"
    case .scrittura: return "Non sono riuscita a salvare"
    }
  }

  func body(content: Content) -> some View {
    content
      .onChange(of: store.guastoNeiDati) { _, nuovo in
        // La conferma di "Ricomincia da capo" ha la precedenza: non deve
        // essere scacciata da un avviso che arriva in quel momento.
        if nuovo != nil, !confermaInCorso { finestra = .guasto }
        if nuovo == nil, finestra == .guasto { finestra = nil }
      }
      .onAppear {
        if store.guastoNeiDati != nil { finestra = .guasto }
      }
      .alert(item: $finestra) { quale in
        switch quale {
        case .guasto: return avvisoDelGuasto
        case .confermaRicomincia: return confermaDiRicominciare
        }
      }
  }

  private var avvisoDelGuasto: Alert {
    // Il ruolo di annullamento non è un dettaglio: senza, SwiftUI aggiunge un
    // pulsante suo, scritto «Cancel» in inglese, in un'app tutta in italiano.
    let lascia = Alert.Button.cancel(Text("Lascia tutto com'è")) {
      // Non si fa niente di proposito: l'app resta usabile per oggi, ma non
      // salva. È la strada che non cancella niente.
      store.mettiDaParteIlGuasto()
      finestra = nil
    }
    guard store.ricominciareÈPossibile else {
      // Niente copia di sicurezza, niente proposta di cancellare: sarebbe
      // offrire di distruggere l'unica cosa rimasta.
      return Alert(title: Text(titolo),
                   message: Text(store.guastoNeiDati ?? ""),
                   dismissButton: lascia)
    }
    return Alert(
      title: Text(titolo),
      message: Text(store.guastoNeiDati ?? ""),
      primaryButton: .destructive(Text("Ricomincia da capo")) {
        confermaInCorso = true
        store.mettiDaParteIlGuasto()
        finestra = .confermaRicomincia
      },
      secondaryButton: lascia)
  }

  private var confermaDiRicominciare: Alert {
    Alert(
      title: Text("Ricominciare da capo?"),
      message: Text("""
        Gli allenamenti di prima non si vedranno più nell'app. Le copie che ho \
        messo da parte restano nella cartella, quindi non spariscono dal Mac.
        """),
      primaryButton: .destructive(Text("Sì, ricomincia")) {
        confermaInCorso = false
        finestra = nil
        store.ricominciaDaCapo()
      },
      secondaryButton: .cancel(Text("Annulla")) {
        confermaInCorso = false
        finestra = nil
      })
  }
}

extension View {
  /// Attacca l'avviso sui dati. Sta sulla schermata principale perché è la
  /// prima cosa che si apre: un guasto ai dati non può aspettare che qualcuno
  /// vada a curiosare nelle impostazioni.
  func avvisoDati(_ store: Store) -> some View {
    modifier(AvvisoDati(store: store))
  }
}
