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
