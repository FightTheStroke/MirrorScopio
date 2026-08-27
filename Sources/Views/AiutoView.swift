import SwiftUI
import AppKit

/// L'aiuto dentro l'app, scritto per chi lo legge.
///
/// Stessa forma delle Impostazioni — intestazione con «Chiudi», l'elenco delle
/// pagine a sinistra, il testo a destra — perché chi ha imparato a muoversi lì
/// deve ritrovarsi qui senza pensarci. Non è una finestra a parte e non è
/// l'aiuto di sistema: resta dentro l'app, una schermata alla volta.
///
/// Le parole qui contano quanto il codice. Frasi corte, niente termini tecnici
/// senza una spiegazione nella stessa riga, e mai una colpa a chi legge: se il
/// Mac non sente, è l'audio, non la persona.
struct AiutoView: View {
  @ObservedObject var store: Store
  @Environment(\.palette) private var palette
  var onClose: () -> Void

  @State private var pagina: Pagina = .comeFunziona

  private var a11y: A11ySettings { store.current.a11y }

  private let repoURL = "https://github.com/FightTheStroke/MirrorScopio"

  var body: some View {
    VStack(spacing: 0) {
      header
      HStack(spacing: 0) {
        ElencoPagine(scelta: $pagina, a11y: a11y, palette: palette)
        Divider()
        ScrollView {
          paginaCorrente
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private var header: some View {
    HStack {
      Text("Aiuto")
        .font(a11y.typeface.font(size: a11y.size(28), weight: .bold))
        .foregroundStyle(palette.foreground)
      Spacer()
      Button("Chiudi", action: onClose)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.escape, modifiers: [])
    }
    .padding(.horizontal, 26)
    .padding(.vertical, 16)
  }

  // MARK: - L'elenco delle pagine

  private enum Pagina: String, PaginaLaterale {
    case comeFunziona, modalita, nonTiSente, perChiAccompagna, tasti, chiSiamo

    var id: String { rawValue }

    var titolo: String {
      switch self {
      case .comeFunziona: "Come funziona"
      case .modalita: "Leggi e Scrivi"
      case .nonTiSente: "Se non ti sente"
      case .perChiAccompagna: "Per chi accompagna"
      case .tasti: "Tasti"
      case .chiSiamo: "Chi siamo"
      }
    }

    var simbolo: String {
      switch self {
      case .comeFunziona: "sparkles"
      case .modalita: "textformat.abc"
      case .nonTiSente: "mic.slash.fill"
      case .perChiAccompagna: "figure.2.and.child.holdinghands"
      case .tasti: "keyboard"
      case .chiSiamo: "heart.fill"
      }
    }
  }

  @ViewBuilder
  private var paginaCorrente: some View {
    VStack(alignment: .leading, spacing: 28) {
      switch pagina {
      case .comeFunziona: comeFunziona
      case .modalita: modalita
      case .nonTiSente: nonTiSente
      case .perChiAccompagna: perChiAccompagna
      case .tasti: tasti
      case .chiSiamo: chiSiamo
      }
    }
  }

  // MARK: - Come funziona

  private var comeFunziona: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Come funziona", a11y: a11y)
      testo("Una parola appare sullo schermo per un lampo — pochi millesimi di secondo — e sparisce.")
      testo("Tu la leggi ad alta voce. Il Mac ascolta con il microfono e capisce da solo se l'hai presa.")
      testo("Non serve un adulto seduto accanto a segnare i risultati: l'app tiene il conto da sé.")
      testo("Ogni volta che prendi una parola, la volta dopo appare per un po' meno tempo. Così, senza accorgertene, leggi sempre più in fretta.")
      testo("Non si sbaglia mai: quando una parola non viene, l'app dice «Ancora». Non è venuta *ancora* — ci si riprova.")
    }
  }

  // MARK: - Leggi e Scrivi

  private var modalita: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Leggi e Scrivi", a11y: a11y)
      testo("Sono i due modi di allenarsi. Li scegli nella schermata di casa, prima di cominciare.")

      sottotitolo("Leggi")
      testo("La parola lampeggia, tu la dici ad alta voce. Qui cresce la **velocità**: più vai avanti, meno a lungo resta la parola sullo schermo.")

      sottotitolo("Scrivi")
      testo("Il Mac dice una parola ad alta voce, tu la scrivi sulla tastiera. Qui cresce la **difficoltà**: si comincia da una parola sola, poi si passa alle frasi.")
      testo("Alza il volume quando scrivi: le parole si sentono, non si vedono.")
    }
  }

  // MARK: - Se non ti sente

  private var nonTiSente: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Se non ti sente", a11y: a11y)
      testo("Prima di tutto: se il Mac non sente, è l'audio che non va, non tu.")
      testo("In alto a destra c'è il microfono. Da lì scegli quale usare e apri «Prova microfono e voce»: dici qualcosa e vedi subito se la barra si muove.")
      testo("Durante la lettura, parla **dopo** che compare l'invito a dire la parola. Se parli mentre la parola è ancora lì, il Mac non sta ancora ascoltando.")
      testo("Se qualcosa non torna, l'app te lo dice invece di stare zitta:")
      elenco("«Non ho sentito niente»", "il microfono non ha colto nulla: controllalo qui in alto.")
      elenco("«Ti ho sentito, ma non sono riuscita a capire»", "il suono è arrivato, ma le parole no: prova a dirla più chiara, senza fretta.")
    }
  }

  // MARK: - Per chi accompagna

  private var perChiAccompagna: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Per chi accompagna", a11y: a11y)
      testo("Per genitori e logopedisti. Il ragazzo non ha bisogno di leggere questa pagina.")

      sottotitolo("Dove stanno i dati")
      testo("Tutto resta su questo Mac, in file JSON che puoi aprire e leggere, dentro la cartella `~/Library/Application Support/MirrorScopio/`. Niente rete, niente account, niente servizi esterni.")
      testo("La trovi anche da Impostazioni → «I dati e l'app» → «Apri la cartella dei dati».")

      sottotitolo("Portare via i risultati")
      testo("Nei Progressi, alla pagina «Porta via i dati», esporti un **PDF** riassuntivo o il **CSV** dell'ultima sessione, da rivedere con calma o da consegnare.")

      sottotitolo("Se i numeri mettono ansia")
      testo("Da Impostazioni → «Dopo ogni parola» puoi nascondere punteggi e percentuali: resta solo il senso di aver finito.")

      sottotitolo("Le prime parole")
      testo("A inizio sessione alcune parole restano visibili più a lungo, per prendere la mano. Sono un riscaldamento e **non entrano** nel punteggio.")
    }
  }

  // MARK: - Tasti

  private var tasti: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Tasti", a11y: a11y)
      testo("Le scorciatoie da tastiera, per chi preferisce non usare il mouse.")
      elenco("Esc", "ferma la lettura in corso, o chiude la pagina che stai guardando.")
      elenco("Invio", "dà il via alla lettura dalla schermata di casa.")
      elenco("⌘,", "apre le Impostazioni.")
      elenco("⌘P", "apre «I tuoi progressi».")
      elenco("⌘?", "apre questo aiuto.")
    }
  }

  // MARK: - Chi siamo

  private var chiSiamo: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Chi siamo", a11y: a11y)
      testo("MirrorScopio è fatto dalla **Fight The Stroke Foundation**, per i ragazzi che imparano a leggere con più fatica.")
      testo("Il codice è aperto, sotto licenza Apache 2.0: chiunque può leggerlo, controllarlo e proporre miglioramenti.")
      SmallButton(title: "Apri il progetto su GitHub", symbol: "arrow.up.forward.app", a11y: a11y) {
        if let u = URL(string: repoURL) { NSWorkspace.shared.open(u) }
      }
    }
  }

  // MARK: - Mattoncini di testo

  private func testo(_ s: String) -> some View {
    Explain(text: s, a11y: a11y, size: 17)
  }

  private func sottotitolo(_ s: String) -> some View {
    Text(s)
      .font(a11y.typeface.font(size: a11y.size(19), weight: .semibold))
      .foregroundStyle(palette.foreground)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Una riga di elenco: la cosa in grassetto, poi la spiegazione. Il grassetto
  /// da solo non porta l'informazione — c'è sempre anche il pallino e le parole.
  private func elenco(_ voce: String, _ spiega: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "circle.fill")
        .font(.system(size: a11y.size(6)))
        .foregroundStyle(palette.accent)
        .accessibilityHidden(true)
      (Text("\(Text(voce).fontWeight(.semibold)) — \(spiega)"))
        .font(a11y.typeface.font(size: a11y.size(17)))
        .foregroundStyle(palette.foreground)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
