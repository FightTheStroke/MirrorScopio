import Testing
import SwiftUI
@testable import MirrorScopio

/// I comandi si devono poter colpire.
///
/// L'app prometteva bersagli da 44 punti e su ogni pulsante scritto a mano la
/// promessa era mantenuta. Poi bastava aprire le impostazioni: lì i comandi
/// veri erano `Toggle`, `Slider`, `Stepper` e `Picker` disegnati da macOS, alti
/// fra i sedici e i ventisei punti. Cioè il posto dove un adulto prepara l'app
/// per un ragazzo con paralisi cerebrale era il posto con i bersagli più
/// piccoli di tutti.
///
/// Qui si misura l'altezza resa davvero, non quella dichiarata: un
/// `frame(minHeight:)` scritto e poi mangiato da un contenitore darebbe verde
/// su carta e rosso a schermo.
@Suite("I comandi si possono colpire")
@MainActor
struct Bersagli {

  /// L'altezza vera, misurata come farebbe SwiftUI.
  func altezza<V: View>(_ vista: V, larghezza: CGFloat = 520) -> CGFloat {
    ImageRenderer(content: vista.frame(width: larghezza)
      .fixedSize(horizontal: false, vertical: true)).nsImage?.size.height ?? 0
  }

  var tema: Palette { Palette.resolve(theme: .chiaro, vision: .standard, system: .light) }

  /// Le impostazioni normali e quelle di chi ha chiesto bersagli grandi.
  static let profili: [A11yProfile] = [.nessuno, .paralisiCerebrale]

  func impostazioni(_ profilo: A11yProfile) -> EffettiveImpostazioniAccessibilita {
    var a = A11ySettings()
    a.profile = profilo
    profilo.apply(to: &a)
    return EffettiveImpostazioniAccessibilita(a)
  }

  @Test("L'interruttore è alto quanto promette", arguments: profili)
  func interruttore(profilo: A11yProfile) {
    let a = impostazioni(profilo)
    var acceso = true
    let v = InterruttoreAccessibile(
      titolo: "Meno movimento",
      acceso: Binding(get: { acceso }, set: { acceso = $0 }),
      a11y: a)
      .environment(\.palette, tema)
    let h = altezza(v)
    #expect(h >= a.bersaglio,
      "con il profilo «\(profilo.label)» l'interruttore è alto \(Int(h)) punti invece di \(Int(a.bersaglio))")
  }

  @Test("I pulsanti più e meno sono alti quanto promettono", arguments: profili)
  func passo(profilo: A11yProfile) {
    let a = impostazioni(profilo)
    var valore = 5.0
    let v = PassoAccessibile(
      titolo: "Numero di parole",
      valore: Binding(get: { valore }, set: { valore = $0 }),
      intervallo: 1...20, a11y: a) { "Numero di parole: \(Int($0))" }
      .environment(\.palette, tema)
    let h = altezza(v)
    #expect(h >= a.bersaglio,
      "con il profilo «\(profilo.label)» i pulsanti più e meno sono alti \(Int(h)) punti invece di \(Int(a.bersaglio))")
  }

  @Test("La scelta a comparsa è alta quanto promette", arguments: profili)
  func scelta(profilo: A11yProfile) {
    let a = impostazioni(profilo)
    var s = ThemeChoice.chiaro
    let v = SceltaAccessibile(
      titolo: "Colori",
      scelta: Binding(get: { s }, set: { s = $0 }),
      opzioni: ThemeChoice.allCases, a11y: a) { $0.label }
      .environment(\.palette, tema)
    // Anche qui: misurare tutta la riga (titolo a sinistra + comando a destra)
    // fa passare la prova per costruzione, perche' il `frame(minHeight:)` sulla
    // riga la allarga davvero mentre il menu dentro resta di 19 punti. Il
    // confronto giusto e' fra la riga intera e il solo titolo: se il comando
    // non regge il bersaglio, la riga si appiattisce sul titolo.
    let intero = altezza(v)
    let soloTitolo = altezza(Text("Colori").font(a.font(.corpo))
      .frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.palette, tema))
    #expect(intero >= a.bersaglio && intero > soloTitolo,
      "con il profilo «\(profilo.label)» la scelta a comparsa è alta \(Int(intero)) punti (il solo titolo ne occupa \(Int(soloTitolo))) invece di \(Int(a.bersaglio))")
  }

  @Test("Il cursore ha accanto due pulsanti grandi", arguments: profili)
  func cursore(profilo: A11yProfile) {
    let a = impostazioni(profilo)
    var valore = 0.5
    let v = CursoreAccessibile(
      titolo: "Velocità della voce",
      valore: Binding(get: { valore }, set: { valore = $0 }),
      intervallo: 0.3...0.6, passo: 0.01, a11y: a) { _ in "media" }
      .environment(\.palette, tema)
    // Il cursore ha il titolo sopra e la riga dei comandi sotto. La prova
    // diceva di misurare la riga e misurava il tutto: cosi' non poteva fallire
    // per il motivo che dichiarava, perche' titolo piu' riga supera 60 punti
    // anche se la riga ne ha 19. Ora si misura la differenza fra il tutto e il
    // solo titolo, che e' quello che resta ai comandi.
    let intero = altezza(v)
    let soloTitolo = altezza(Text("Velocità della voce").font(a.font(.corpo))
      .frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.palette, tema))
    let riga = intero - soloTitolo - Metrica.briciola
    #expect(riga >= a.bersaglio,
      "con il profilo «\(profilo.label)» la riga del cursore è alta \(Int(riga)) punti invece di \(Int(a.bersaglio))")
  }

  /// Chi sceglie «Paralisi cerebrale» ha chiesto bersagli grandi: se il profilo
  /// non li ingrandisce davvero, la promessa è scritta e basta. È già successo.
  @Test("Il profilo per la paralisi cerebrale ingrandisce davvero i bersagli")
  func profiloIngrandisce() {
    #expect(impostazioni(.paralisiCerebrale).bersaglio >= 60)
    #expect(impostazioni(.paralisiCerebrale).bersaglio > impostazioni(.nessuno).bersaglio)
  }

  /// Il caso vero: si sceglie il profilo, poi si tocca una manopola qualunque.
  ///
  /// Toccare una manopola riporta il profilo a «nessuno» — è voluto, perché da
  /// lì in poi le scelte sono su misura — e prima questo faceva tornare i
  /// bersagli da 60 a 44 **senza dirlo**: bastava alzare di un filo la
  /// dimensione del testo e l'app smetteva di essere usabile per la persona che
  /// aveva appena dichiarato di non riuscire a prendere i comandi piccoli.
  @Test("I bersagli grandi restano anche dopo aver toccato un'altra manopola")
  func bersagliGrandiSopravvivono() {
    var s = A11ySettings()
    A11yProfile.paralisiCerebrale.apply(to: &s)
    #expect(EffettiveImpostazioniAccessibilita(s).bersaglio >= 60)

    // Quello che fa `SettingsView.update` a ogni modifica manuale.
    s.textScale += 0.05
    s.profile = .nessuno
    #expect(EffettiveImpostazioniAccessibilita(s).bersaglio >= 60,
      "dopo aver toccato una manopola i bersagli sono tornati a \(Int(EffettiveImpostazioniAccessibilita(s).bersaglio)) punti: la scelta di chi non riesce a prenderli piccoli è stata annullata in silenzio")
  }

  /// Stessa storia per le righe distanziate, che si salvavano solo per caso:
  /// il profilo Dislessia sceglie anche il carattere, e il carattere restava.
  @Test("Le righe distanziate restano anche cambiando carattere")
  func interlineaSopravvive() {
    var s = A11ySettings()
    A11yProfile.dislessia.apply(to: &s)
    #expect(EffettiveImpostazioniAccessibilita(s).interlinea > 0)
    s.typeface = .arrotondato
    s.profile = .nessuno
    #expect(EffettiveImpostazioniAccessibilita(s).interlinea > 0,
      "cambiando carattere si è persa la spaziatura fra le righe, che nessuno aveva chiesto di togliere")
  }

  /// Un controllo che non sa fallire non sta controllando niente: l'interruttore
  /// di sistema, nudo, è il difetto che questa suite deve saper vedere.
  @Test("La misura sa ancora bocciare: il Toggle di sistema è troppo piccolo")
  func laMisuraSaBocciare() {
    var acceso = true
    let h = altezza(Toggle("Meno movimento", isOn: Binding(get: { acceso }, set: { acceso = $0 })))
    #expect(h < Metrica.bersaglio,
      "un Toggle nudo dovrebbe risultare più basso di \(Int(Metrica.bersaglio)) punti, invece dà \(Int(h)): la misura si è rotta")
  }
}
