import Testing
import Foundation
@testable import MirrorScopio

/// I suoni, verificati **senza orecchie**.
///
/// Un suono sbagliato non fa un errore: fa «tac». E quel «tac» lo sente chi
/// usa l'app, non chi la scrive — anzi, lo sente soprattutto chi non guarda lo
/// schermo e sui suoni ci conta per sapere se ha risposto giusto.
///
/// Un click è una discontinuità: un salto grande fra due campioni vicini,
/// oppure un primo o ultimo campione lontano da zero. Sono cose che si
/// misurano, e qui si misurano.
@Suite("Suoni")
@MainActor
struct SuoniGenerati {

  private let frequenzaCampionamento = 44_100.0

  /// Due note, non una: la giunzione fra due note è il punto dove un inviluppo
  /// scritto male si tradisce.
  private var campioniDiProva: [Float] {
    Suoni.campioni(note: [Suoni.Nota(frequenza: 659, durata: 0.10),
                          Suoni.Nota(frequenza: 988, durata: 0.13)],
                   ampiezza: 0.4, smussatura: 0.22,
                   frequenzaCampionamento: frequenzaCampionamento)
  }

  @Test("Il suono dura quanto dicono le note")
  func durata() {
    let campioni = campioniDiProva
    #expect(!campioni.isEmpty, "un suono senza campioni non si sente")
    let attesi = (0.10 + 0.13) * frequenzaCampionamento
    #expect(abs(Double(campioni.count) - attesi) < 4,
            "durata \(campioni.count) campioni invece di circa \(Int(attesi))")
  }

  @Test("Comincia e finisce a zero: nessun click in entrata o in uscita")
  func nessunClickAgliEstremi() throws {
    let campioni = campioniDiProva
    let primo = try #require(campioni.first)
    let ultimo = try #require(campioni.last)
    #expect(abs(primo) < 1e-4, "primo campione a \(primo): si sentirebbe un «tac»")
    #expect(abs(ultimo) < 1e-4, "ultimo campione a \(ultimo): si sentirebbe un «tac»")
  }

  /// Un click salterebbe verso l'ampiezza di picco tutto in un campione. Una
  /// sinusoide morbida non può muoversi più di 2·π·frequenza·ampiezza diviso la
  /// frequenza di campionamento: a 988 Hz e 0,4 di ampiezza sono circa 0,056.
  /// La soglia sta comoda sopra quel limite fisico e ben sotto il salto che
  /// farebbe un click.
  @Test("Nessun salto brusco fra un campione e il successivo")
  func nessunaDiscontinuita() {
    let campioni = campioniDiProva
    var maxSalto: Float = 0
    for i in 1..<campioni.count {
      maxSalto = max(maxSalto, abs(campioni[i] - campioni[i - 1]))
    }
    #expect(maxSalto < 0.08, "salto massimo \(maxSalto): sopra 0,08 e' un click")
  }

  @Test("C'e' davvero del segnale, e non piu' forte di quanto chiesto")
  func ampiezza() {
    let picco = campioniDiProva.map { abs($0) }.max() ?? 0
    #expect(picco > 0.3, "picco \(picco): quasi silenzio, il suono non si sentirebbe")
    #expect(picco <= 0.4001, "picco \(picco): piu' forte dell'ampiezza chiesta")
  }

  @Test("L'attacco e' smussato, non netto")
  func attaccoSmussato() {
    let campioni = campioniDiProva
    let picco = campioni.map { abs($0) }.max() ?? 0
    #expect(abs(campioni[1]) < picco,
            "il secondo campione e' gia' al picco: l'inviluppo non sale, parte di scatto")
  }

  @Test("Una pausa e' silenzio pieno")
  func pausaMuta() {
    let muto = Suoni.campioni(note: [Suoni.Nota(frequenza: 0, durata: 0.05)],
                              ampiezza: 0.4, smussatura: 0.22,
                              frequenzaCampionamento: frequenzaCampionamento)
    #expect(muto.allSatisfy { $0 == 0 }, "una pausa che non e' silenzio esatto si sente")
  }
}
