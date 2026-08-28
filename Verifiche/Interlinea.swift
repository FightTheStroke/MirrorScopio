import Testing
import SwiftUI
@testable import MirrorScopio

/// Le righe non si scavalcano.
///
/// `docs/ACCESSIBILITA.md` prometteva «righe più larghe» nel profilo Dislessia
/// da quando quel profilo esiste. Nel codice non c'era una sola riga che le
/// allargasse: zero occorrenze di `lineSpacing` in tutta l'app. Era una
/// promessa scritta e basta, ed è il difetto peggiore in un documento di
/// accessibilità — chi lo legge ci conta.
///
/// Questa prova esiste perché quella promessa non torni a essere solo scritta.
@Suite("Le righe non si scavalcano")
@MainActor
struct Interlinea {

  func impostazioni(profilo: A11yProfile) -> EffettiveImpostazioniAccessibilita {
    var a = A11ySettings()
    profilo.apply(to: &a)
    return EffettiveImpostazioniAccessibilita(a)
  }

  @Test("Il profilo per chi salta le righe le allarga davvero")
  func dislessiaAllarga() {
    #expect(impostazioni(profilo: .dislessia).interlinea > 0,
      "il profilo Dislessia promette righe più larghe e non le allarga di un punto")
  }

  @Test("Senza profilo l'interlinea resta quella del carattere")
  func senzaProfiloNienteInterlinea() {
    var a = A11ySettings()
    a.typeface = .sistema
    #expect(EffettiveImpostazioniAccessibilita(a).interlinea == 0)
  }

  /// Un controllo che non sa fallire non sta controllando niente: se
  /// l'interlinea non arrivasse davvero al testo, l'altezza resa sarebbe
  /// identica con e senza.
  @Test("L'interlinea arriva fino al testo, non si ferma nei numeri")
  func arrivaAlTesto() {
    let frase = "Una frase abbastanza lunga da andare a capo almeno tre volte dentro una colonna stretta, così le righe si contano."
    func altezza(_ a: EffettiveImpostazioniAccessibilita) -> CGFloat {
      ImageRenderer(content: Text(frase)
        .interlinea(a)
        .frame(width: 200)
        .fixedSize(horizontal: false, vertical: true)).nsImage?.size.height ?? 0
    }
    let stretta = altezza(impostazioni(profilo: .nessuno))
    let larga = altezza(impostazioni(profilo: .dislessia))
    #expect(larga > stretta,
      "con le righe larghe il testo è alto \(Int(larga)) punti contro \(Int(stretta)): l'interlinea non sta arrivando al testo")
  }
}
