import SwiftUI

// MARK: - Distintivi

/// Il distintivo di un obiettivo, nei suoi due stati.
///
/// Nasce da un difetto vero: nella pagina Obiettivi ogni traguardo ancora da
/// prendere mostrava lo stesso lucchetto grigio. Nove lucchetti identici non
/// dicono *che cosa* si può conquistare, sembrano nove porte chiuse in faccia e
/// tolgono la voglia di provarci. Qui invece si vede sempre **il simbolo
/// dell'obiettivo** — attenuato finché non è tuo, pieno quando lo diventa.
///
/// La differenza fra i due stati non è affidata al colore: cambia la forma del
/// bordo (tratteggiato e aperto contro pieno e spesso), l'intensità del simbolo
/// e il segnale nell'angolo (un piccolo lucchetto contro un segno di spunta).
/// Così la distinzione si legge a colpo d'occhio anche in bianco e nero, e da
/// chi i colori non li distingue.
struct DistintivoObiettivo: View {
  let simbolo: String
  let conquistato: Bool
  var diametro: CGFloat = 56
  let a11y: EffettiveImpostazioniAccessibilita
  let palette: Palette

  /// Oro quando l'obiettivo è tuo; in modalità calma niente ori accesi, si usa
  /// il colore del testo — perché la modalità calma toglie i festeggiamenti, non
  /// il senso di aver conquistato qualcosa. La forma continua a parlare da sola.
  private var coloreConquistato: Color {
    a11y.calmMode ? palette.foreground : palette.premio
  }

  private var lato: CGFloat { a11y.size(diametro) }

  var body: some View {
    ZStack {
      if conquistato { corpoConquistato } else { corpoDaConquistare }
    }
    .frame(width: lato, height: lato)
    .accessibilityHidden(true)
  }

  // Conquistato: medaglia piena. Cerchio chiuso e spesso, simbolo pieno, e un
  // segno di spunta nell'angolo che ribadisce "preso" senza usare il colore.
  private var corpoConquistato: some View {
    let colore = coloreConquistato
    return Image(systemName: simbolo)
      .font(a11y.typeface.font(size: lato * 0.42, weight: .bold))
      .foregroundStyle(colore)
      .frame(width: lato, height: lato)
      .background(Circle().fill(colore.opacity(a11y.calmMode ? 0.10 : 0.16)))
      .overlay(Circle().strokeBorder(colore, lineWidth: max(2.5, lato * 0.06)))
      .overlay(alignment: .bottomTrailing) {
        segnaleAngolo(simbolo: "checkmark.circle.fill", colore: colore, sfondo: palette.surface)
      }
  }

  // Da conquistare: il simbolo c'è, ma tenue. Il cerchio è tratteggiato e non
  // ancora "chiuso" con spessore: dice "questo si può ancora prendere", non
  // "questo ti è negato". Il lucchetto resta, ma piccolo e in un angolo: è un
  // segnale in più, non l'unica cosa che si vede.
  private var corpoDaConquistare: some View {
    Image(systemName: simbolo)
      .font(a11y.typeface.font(size: lato * 0.40, weight: .regular))
      .foregroundStyle(palette.muted.opacity(0.55))
      .frame(width: lato, height: lato)
      .background(Circle().fill(palette.muted.opacity(0.06)))
      .overlay(
        Circle().strokeBorder(
          palette.muted.opacity(0.5),
          style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
        )
      )
      .overlay(alignment: .bottomTrailing) {
        segnaleAngolo(simbolo: "lock.fill", colore: palette.muted, sfondo: palette.surface)
      }
  }

  // Il gettone nell'angolo: un cerchietto pieno che stacca il segnale dallo
  // sfondo, così resta leggibile su qualunque tema.
  private func segnaleAngolo(simbolo: String, colore: Color, sfondo: Color) -> some View {
    let d = lato * 0.34
    return Image(systemName: simbolo)
      .font(.system(size: d * 0.66, weight: .bold))
      .foregroundStyle(colore)
      .frame(width: d, height: d)
      .background(Circle().fill(sfondo))
      .overlay(Circle().strokeBorder(sfondo, lineWidth: 1))
      .offset(x: d * 0.16, y: d * 0.16)
  }
}

/// Il distintivo di una fascia di livello.
///
/// Prima il livello era solo un numero grosso e una barra: nessuna faccia,
/// nessun senso di salita. Qui ogni fascia — Esploratore, Lettore curioso,
/// Occhio veloce, Lampo, Maestro dei lampi, Leggenda — ha il suo simbolo, e un
/// anello diviso in tanti spicchi quante sono le fasce: sono pieni gli spicchi
/// già raggiunti. Più anello pieno vuol dire fascia più alta, e questo si vede
/// anche in bianco e nero: si capisce che Leggenda viene dopo Esploratore senza
/// dover leggere il numero.
struct DistintivoLivello: View {
  let livello: Int
  var diametro: CGFloat = 64
  /// Quando presente, mostra il numero di livello in un gettone: serve dove il
  /// numero non è già scritto accanto (in home), si omette dove c'è già.
  var numero: Int? = nil
  let a11y: EffettiveImpostazioniAccessibilita
  let palette: Palette

  private var lato: CGFloat { a11y.size(diametro) }

  private var colore: Color {
    a11y.calmMode ? palette.foreground : palette.accent
  }

  var body: some View {
    let fasce = Gamification.numeroFasce
    let raggiunti = Gamification.levelRank(livello) + 1
    let spessore = max(3, lato * 0.07)

    ZStack {
      Circle().fill(colore.opacity(a11y.calmMode ? 0.08 : 0.14))

      // Anello a spicchi: uno per fascia, pieni quelli già saliti. La quantità
      // di anello pieno racconta la progressione senza affidarsi al colore.
      ForEach(0..<fasce, id: \.self) { i in
        // Stacco fra spicchi tenuto piccolo: un gap troppo largo li azzererebbe.
        let gap = 0.018
        Circle()
          .trim(from: Double(i) / Double(fasce) + gap,
                to: Double(i + 1) / Double(fasce) - gap)
          .stroke(
            i < raggiunti ? colore : colore.opacity(0.25),
            style: StrokeStyle(lineWidth: spessore, lineCap: .butt)
          )
          .rotationEffect(.degrees(-90))
          .padding(spessore / 2)
      }

      Image(systemName: Gamification.levelSymbol(livello))
        .font(a11y.typeface.font(size: lato * 0.34, weight: .bold))
        .foregroundStyle(colore)
    }
    .frame(width: lato, height: lato)
    .overlay(alignment: .bottomTrailing) {
      if let n = numero {
        let d = lato * 0.42
        Text("\(n)")
          .font(a11y.typeface.font(size: d * 0.5, weight: .bold))
          .foregroundStyle(palette.background)
          .frame(width: d, height: d)
          .background(Circle().fill(colore))
          .overlay(Circle().strokeBorder(palette.background, lineWidth: 1.5))
          .offset(x: d * 0.14, y: d * 0.14)
      }
    }
    .accessibilityHidden(true)
  }
}

#if DEBUG
// Anteprima di lavoro: i due stati dell'obiettivo affiancati e la scala dei
// livelli, per giudicare a occhio la differenza — anche in scala di grigi.
// Vive solo nelle build di debug: non finisce mai nell'app che si consegna.
#Preview("Distintivi") {
  let palette = Palette.resolve(theme: .chiaro, vision: .standard, system: .light)
  let a11y = EffettiveImpostazioniAccessibilita()
  return VStack(spacing: Metrica.spazioLargo) {
    HStack(spacing: Metrica.spazioLargo) {
      DistintivoObiettivo(simbolo: "bolt.fill", conquistato: false, a11y: a11y, palette: palette)
      DistintivoObiettivo(simbolo: "bolt.fill", conquistato: true, a11y: a11y, palette: palette)
    }
    HStack(spacing: Metrica.spazioMedio) {
      ForEach([1, 4, 7, 12, 17, 25], id: \.self) { lv in
        DistintivoLivello(livello: lv, numero: lv, a11y: a11y, palette: palette)
      }
    }
  }
  .padding(Metrica.spazioEnorme)
  .background(palette.background)
}
#endif
