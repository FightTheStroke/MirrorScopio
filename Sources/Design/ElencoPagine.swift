import SwiftUI

/// Una pagina dell'elenco laterale: un titolo e un simbolo.
protocol PaginaLaterale: Identifiable, Hashable, CaseIterable {
  var titolo: String { get }
  var simbolo: String { get }
}

/// L'elenco delle pagine a sinistra, uguale ovunque.
///
/// Sta in un posto solo di proposito. Le Impostazioni e i Progressi sono le due
/// schermate lunghe dell'app, e finche ognuna aveva la sua navigazione le due
/// si somigliavano soltanto finche qualcuno si ricordava di tenerle allineate.
/// Chi ha imparato a muoversi in una deve ritrovarsi nell'altra senza
/// accorgersene: qui e vero per costruzione, non per buona volonta.
///
/// Sotto: righe alte almeno 48 punti — chi punta con difficolta non deve
/// centrare un bersaglio piccolo — e la pagina aperta si riconosce dal colore
/// *e* dal grassetto, perche il colore da solo non basta a chi non lo
/// distingue.
struct ElencoPagine<P: PaginaLaterale>: View where P.AllCases: RandomAccessCollection {
  @Binding var scelta: P
  var a11y: A11ySettings
  var palette: Palette

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(P.allCases)) { p in
          Button { scelta = p } label: {
            HStack(spacing: 12) {
              Image(systemName: p.simbolo)
                .font(.system(size: a11y.size(17)))
                .frame(width: a11y.size(26))
              Text(p.titolo)
                .font(a11y.typeface.font(size: a11y.size(17),
                                         weight: scelta == p ? .semibold : .regular))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
            .foregroundStyle(scelta == p ? palette.accent : palette.foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, a11y.size(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 48)
            .background(
              RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
                .fill(scelta == p ? palette.accent.opacity(0.15) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(scelta == p ? [.isSelected] : [])
        }
      }
      .padding(10)
    }
    .frame(width: a11y.size(260))
  }
}

/// Il guscio delle schermate lunghe: titolo in alto, elenco a sinistra,
/// contenuto che scorre a destra.
///
/// Nasce da un difetto vero. Le Impostazioni e i Progressi usavano già lo
/// stesso elenco e la stessa intestazione, eppure a schermo erano diverse:
/// il titolo dei Progressi era rientrato di 54 punti invece che di 26, perché
/// sopra i margini che l'intestazione mette già per conto suo ne erano stati
/// aggiunti altri; sotto correva una riga di separazione che nelle Impostazioni
/// non c'era; il contenuto era largo 860 punti invece di 720 e staccato dai
/// bordi di 28 invece che di 32.
///
/// Nessuno di quei numeri era sbagliato da solo. Erano sbagliati insieme: chi
/// impara a muoversi in una schermata deve ritrovarsi nell'altra senza doverci
/// pensare, e non ci si riesce se il titolo si sposta e il contenuto cambia
/// larghezza. Condividere i pezzi non basta, se poi ognuno li monta a modo suo:
/// va condiviso il modo di montarli.
struct PaginaConElenco<P: PaginaLaterale, Contenuto: View>: View
where P.AllCases: RandomAccessCollection {
  let titolo: String
  /// Una riga sotto il titolo: il nome di chi sta usando l'app, la data.
  var sottotitolo: String? = nil
  @Binding var scelta: P
  var a11y: A11ySettings
  var palette: Palette
  let onClose: () -> Void
  @ViewBuilder let contenuto: () -> Contenuto

  /// Quanto è larga la colonna del testo. Oltre una certa larghezza le righe
  /// diventano troppo lunghe e l'occhio perde il capo della riga successiva:
  /// è la ragione per cui i giornali hanno le colonne strette.
  static var larghezzaColonna: CGFloat { 720 }

  var body: some View {
    VStack(spacing: 0) {
      IntestazionePagina(titolo: titolo, sottotitolo: sottotitolo,
                         a11y: a11y, onClose: onClose)
      HStack(spacing: 0) {
        ElencoPagine(scelta: $scelta, a11y: a11y, palette: palette)
        Divider()
        ScrollView {
          contenuto()
            .padding(a11y.size(Metrica.margine))
            .frame(maxWidth: Self.larghezzaColonna, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .background(palette.background.ignoresSafeArea())
  }
}
