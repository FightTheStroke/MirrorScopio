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
  var a11y: EffettiveImpostazioniAccessibilita
  var palette: Palette

  /// Sopra il testo grande la colonna laterale diventa una barra in alto.
  ///
  /// La larghezza cresceva col testo: 260 punti diventavano più di 500, e a
  /// quel punto la colonna si mangiava metà finestra proprio a chi aveva
  /// chiesto testo grande perché lo spazio gli serviva per leggere. Adesso
  /// sopra quella soglia le voci si mettono in fila in alto e il contenuto si
  /// riprende tutta la larghezza.
  var body: some View {
    if a11y.testoGrande {
      // La voce scelta deve stare dentro lo schermo.
      //
      // Con il testo grande le voci non ci stanno tutte in fila: l'ultima
      // resta fuori a destra. Finche' si clicca va bene — si clicca quello che
      // si vede — ma cambiando pagina con la tastiera, o tornando a una
      // schermata gia' aperta, la pagina attiva poteva essere quella invisibile:
      // il contenuto cambiava e l'unico segno di dove ci si trovava era fuori
      // dal bordo. Chi usa il testo grande e' esattamente chi non puo'
      // indovinarlo.
      ScrollViewReader { barra in
        ScrollView(.horizontal) {
          HStack(spacing: Metrica.briciola) {
            ForEach(Array(P.allCases)) { p in voce(p, larga: false).id(p.id) }
          }
          .padding(Metrica.spazioStretto)
        }
        .onAppear { barra.scrollTo(scelta.id, anchor: .center) }
        .onChange(of: scelta) { _, nuova in
          withAnimation(a11y.reducedMotion ? nil : .easeOut(duration: 0.2)) {
            barra.scrollTo(nuova.id, anchor: .center)
          }
        }
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: Metrica.briciola) {
          ForEach(Array(P.allCases)) { p in voce(p, larga: true) }
        }
        .padding(Metrica.spazioStretto)
      }
      .frame(width: a11y.size(260))
    }
  }

  private func voce(_ p: P, larga: Bool) -> some View {
    Button { scelta = p } label: {
      HStack(spacing: Metrica.spazioPiccolo) {
        Image(systemName: p.simbolo)
          .font(.system(size: a11y.size(17)))
          .frame(width: a11y.size(26))
        Text(p.titolo)
          .font(a11y.font(.corpo, scelta == p ? .semibold : .regular))
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        if larga { Spacer(minLength: 0) }
      }
      .foregroundStyle(scelta == p ? palette.accent : palette.foreground)
      .padding(.horizontal, Metrica.spazioPiccolo)
      .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
      .frame(maxWidth: larga ? .infinity : nil, alignment: .leading)
      .frame(minHeight: max(48, a11y.bersaglio))
      .background(
        RoundedRectangle(cornerRadius: Metrica.raggioPiccolo)
          .fill(scelta == p ? palette.accent.opacity(a11y.velo(0.15)) : .clear))
      .contentShape(RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
    }
    .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
    .accessibilityAddTraits(scelta == p ? [.isSelected] : [])
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
  var a11y: EffettiveImpostazioniAccessibilita
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
      if a11y.testoGrande {
        VStack(spacing: 0) {
          ElencoPagine(scelta: $scelta, a11y: a11y, palette: palette)
          Divider()
          corpo
        }
      } else {
        HStack(spacing: 0) {
          ElencoPagine(scelta: $scelta, a11y: a11y, palette: palette)
          Divider()
          corpo
        }
      }
    }
    .background(palette.background.ignoresSafeArea())
  }

  private var corpo: some View {
    ScrollView {
      contenuto()
        .padding(a11y.size(Metrica.margine))
        // La colonna del testo non si allarga oltre la misura leggibile, ma con
        // il testo grande quella misura cresce insieme al testo: tenerla a 720
        // punti fissi vorrebbe dire righe da tre parole.
        .frame(maxWidth: a11y.size(Self.larghezzaColonna), alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
