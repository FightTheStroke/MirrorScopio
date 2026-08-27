import SwiftUI

/// Le schermate dell'app. Una sola alla volta, mai due finestre: l'app deve
/// essere comprensibile da un bambino senza spiegazioni.
enum Schermata: Equatable {
  case casa, impostazioni, progressi, obiettivi, audio, preparazione, benvenuto
}

/// Dove si trova l'app in questo momento.
///
/// Prima la schermata era uno `@State` privato dentro `RootView`, e andava
/// bene finché a cambiarla erano solo i pulsanti dentro quella vista. Ma i
/// comandi del menu in alto vivono in `MirrorScopioApp`, un altro pezzo
/// dell'app, e da lì non c'è modo di toccare uno stato privato di una vista.
/// Tenere qui la schermata — in un oggetto solo, condiviso — è ciò che permette
/// alla voce «Impostazioni…» del menu e al pulsante dentro la pagina di aprire
/// la stessa identica cosa.
@MainActor
final class Navigazione: ObservableObject {
  @Published var schermata: Schermata = .casa
  /// L'aiuto in-app: si apre sopra la schermata di casa, non è una finestra a
  /// parte. Sta qui, e non fra le `Schermata`, perché è una cosa che si può
  /// aprire da qualunque punto e chiudere per tornare esattamente dov'eri.
  @Published var mostraAiuto = false
}

/// I comandi del menu in alto.
///
/// Stanno in un tipo a parte, e non scritti a mano dentro `body`, perché devono
/// **guardare** il motore: durante un allenamento le voci che portano altrove
/// si spengono da sole, così nessuno butta fuori un ragazzo da una sessione in
/// corso premendo una scorciatoia per sbaglio.
struct ComandiMenu: Commands {
  @ObservedObject var nav: Navigazione
  @ObservedObject var engine: SessionEngine

  /// Vero mentre una lettura è davvero in corso. A riposo o a sessione finita
  /// si può andare dove si vuole; nel mezzo no.
  private var inAllenamento: Bool {
    switch engine.phase {
    case .idle, .finished: return false
    default: return true
    }
  }

  private func vaiA(_ schermata: Schermata) {
    nav.mostraAiuto = false
    nav.schermata = schermata
  }

  var body: some Commands {
    // «Nuovo» non ha senso in un'app a finestra singola: si toglie, così il
    // menu non promette una cosa che non esiste.
    CommandGroup(replacing: .newItem) {}

    CommandGroup(replacing: .appSettings) {
      Button("Impostazioni…") { vaiA(.impostazioni) }
        .keyboardShortcut(",", modifiers: .command)
        .disabled(inAllenamento)
    }

    CommandMenu("Vista") {
      Button("I tuoi progressi") { vaiA(.progressi) }
        .keyboardShortcut("p", modifiers: .command)
        .disabled(inAllenamento)

      Button("Prova microfono e voce") { vaiA(.audio) }
        .disabled(inAllenamento)

      Button("Prepara il Mac") { vaiA(.preparazione) }
        .disabled(inAllenamento)
    }

    CommandGroup(replacing: .help) {
      Button("Aiuto di MirrorScopio") {
        nav.schermata = .casa
        nav.mostraAiuto = true
      }
      .keyboardShortcut("?", modifiers: .command)
      .disabled(inAllenamento)
    }
  }
}
