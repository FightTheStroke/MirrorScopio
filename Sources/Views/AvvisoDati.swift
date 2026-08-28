import SwiftUI

/// Dice a schermo che i dati salvati non si sono potuti leggere.
///
/// Nasce da un difetto che perdeva tutto in silenzio: l'app ripartiva vuota e
/// al primo salvataggio ci scriveva sopra. Adesso il file non si tocca finché
/// qualcuno non ha letto che cosa è successo e non ha scelto.
struct AvvisoDati: ViewModifier {
  @ObservedObject var store: Store
  @State private var mostraConferma = false

  /// L'avviso si chiude solo passando dalla porta: qualunque modo di
  /// congedarlo — pulsante o tasto Esc — mette via il guasto senza toccare i
  /// file.
  private var avviso: Binding<Bool> {
    Binding(get: { store.guastoNeiDati != nil },
            set: { if !$0 { store.mettiDaParteIlGuasto() } })
  }

  func body(content: Content) -> some View {
    content
      .alert("Non sono riuscita a leggere i dati salvati",
             isPresented: avviso) {
        // Il ruolo `.cancel` non è un dettaglio: senza, SwiftUI ne aggiunge uno
        // suo, scritto «Cancel» in inglese, dentro un'app tutta in italiano.
        Button("Lascia tutto com'è", role: .cancel) {
          // Non si fa niente di proposito: l'app resta usabile per oggi, ma non
          // salva. È la strada che non cancella niente.
          store.mettiDaParteIlGuasto()
        }
        if store.scritturaSospesa {
          Button("Ricomincia da capo", role: .destructive) {
            mostraConferma = true
          }
        }
      } message: {
        Text(store.guastoNeiDati ?? "")
      }
      .alert("Ricominciare da capo?", isPresented: $mostraConferma) {
        Button("Annulla", role: .cancel) {}
        Button("Sì, ricomincia", role: .destructive) {
          store.ricominciaDaCapo()
        }
      } message: {
        Text("""
          Gli allenamenti di prima non si vedranno più nell'app. Le copie che ho \
          messo da parte restano nella cartella, quindi non spariscono dal Mac.
          """)
      }
  }
}

extension View {
  /// Attacca l'avviso sui dati illeggibili. Sta sulla schermata principale
  /// perché è la prima cosa che si apre: un guasto ai dati non può aspettare
  /// che qualcuno vada a curiosare nelle impostazioni.
  func avvisoDati(_ store: Store) -> some View {
    modifier(AvvisoDati(store: store))
  }
}
