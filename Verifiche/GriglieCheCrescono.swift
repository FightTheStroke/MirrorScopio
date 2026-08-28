import Testing
import SwiftUI
@testable import MirrorScopio

/// Le griglie crescono insieme al testo.
///
/// Il 28 agosto 2026, guardando l'app in esecuzione con «Dimensione di tutto» a
/// ×2, la pagina «Obiettivi» mostrava questo: «Una settima…», «Più veloce…»,
/// «Hai letto giuste tutte le…», «Sei tornato tre giorn…». Sette obiettivi su
/// nove col nome tagliato a metà.
///
/// La causa: ogni `LazyVGrid` dell'app nasceva con una larghezza minima di
/// colonna scritta a mano — 144, 160, 220, 230, 250 punti — e quel numero non
/// veniva moltiplicato da `a11y.size()` come tutto il resto. Il testo
/// raddoppiava, la colonna restava ferma, e SwiftUI teneva **sette** colonne
/// strette invece di passarne a tre larghe: quello che non ci stava spariva
/// sotto i puntini.
///
/// È il tipo di difetto peggiore che ci sia in quest'app, perché **non colpisce
/// tutti allo stesso modo**: colpisce solo chi ha alzato il testo, cioè chi
/// vede poco, cioè esattamente la persona per cui quella manopola è stata
/// messa. Chi legge bene non l'avrebbe mai visto.
///
/// Nessuna prova se n'era accorta perché non ne esisteva una: le prove
/// misuravano la larghezza della finestra, non quella delle colonne dentro.
/// Questa la misura.
@Suite("Le griglie crescono insieme al testo")
@MainActor
struct GriglieCheCrescono {

  func impostazioni(scala: Double) -> EffettiveImpostazioniAccessibilita {
    var a = A11ySettings()
    a.textScale = scala
    return EffettiveImpostazioniAccessibilita(a)
  }

  /// Legge la larghezza minima davvero chiesta a SwiftUI.
  ///
  /// `GridItem.Size` non espone i suoi valori, quindi si passa dalla
  /// descrizione testuale: è brutto, ma è l'unico modo di misurare ciò che
  /// arriva a SwiftUI invece di ciò che credevamo di avergli passato — ed è
  /// proprio la differenza fra le due cose che ha prodotto il difetto.
  func minimoChiesto(_ colonne: [GridItem]) -> Double? {
    guard case .adaptive(let minimo, _) = colonne.first?.size else { return nil }
    return Double(minimo)
  }

  @Test("A grandezza normale la colonna resta quella pensata")
  func normaleNonCambia() {
    let colonne = impostazioni(scala: 1.0).colonneAdattive(minimo: 144, massimo: 220)
    #expect(minimoChiesto(colonne) == 144,
      "senza ingrandimento la griglia deve restare identica a prima")
  }

  @Test("Col testo a ×2 la colonna raddoppia")
  func doppioRaddoppia() {
    let colonne = impostazioni(scala: 2.0).colonneAdattive(minimo: 144, massimo: 220)
    #expect(minimoChiesto(colonne) == 288,
      "il testo è due volte più grande: se la colonna non raddoppia, il nome dell'obiettivo viene tagliato")
  }

  @Test("La colonna cresce a ogni scatto, non solo agli estremi")
  func cresceSempre() {
    var precedente = 0.0
    for scala in stride(from: 0.8, through: 2.0, by: 0.05) {
      let minimo = minimoChiesto(impostazioni(scala: scala).colonneAdattive(minimo: 160)) ?? 0
      #expect(minimo > precedente,
        "a ×\(String(format: "%.2f", scala)) la colonna non è cresciuta rispetto allo scatto prima")
      precedente = minimo
    }
  }

  @Test("Anche il massimo si moltiplica")
  func massimoSegue() {
    guard case .adaptive(_, let massimo)? = impostazioni(scala: 2.0)
      .colonneAdattive(minimo: 144, massimo: 220).first?.size else {
      Issue.record("le colonne non sono adattive")
      return
    }
    #expect(Double(massimo) == 440,
      "se il massimo resta fermo la colonna non può crescere abbastanza da contenere il testo doppio")
  }

  @Test("Anche lo spazio fra le colonne si moltiplica")
  func spazioSegue() {
    let colonne = impostazioni(scala: 2.0).colonneAdattive(minimo: 160, spazio: 10)
    #expect(colonne.first?.spacing == 20,
      "con il testo doppio le colonne devono restare distinguibili l'una dall'altra")
  }

  @Test("Senza massimo la colonna non ne inventa uno")
  func senzaMassimo() {
    guard case .adaptive(_, let massimo)? = impostazioni(scala: 1.0)
      .colonneAdattive(minimo: 80).first?.size else {
      Issue.record("le colonne non sono adattive")
      return
    }
    #expect(massimo == .infinity,
      "chi non chiede un massimo non deve ritrovarselo imposto")
  }
}
