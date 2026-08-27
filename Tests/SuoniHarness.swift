import Foundation

/// Verifica dei suoni **senza orecchie**: controlla i campioni generati, che è
/// l'unico modo affidabile per sapere se un suono farà «tac». Un click è una
/// discontinuità — un salto grande fra due campioni vicini, o un primo/ultimo
/// campione lontano da zero: qui si misura proprio quello.
@main
struct SuoniHarness {
  static func main() {
    var failures = 0
    func check(_ name: String, _ condition: Bool) {
      print("\(condition ? "PASS" : "FAIL")  \(name)")
      if !condition { failures += 1 }
    }

    let fs = 44_100.0

    // Un suono qualsiasi con due note: è il caso che stressa gli inviluppi,
    // perché c'è anche la giunzione fra le note.
    let note = [Suoni.Nota(frequenza: 659, durata: 0.10),
                Suoni.Nota(frequenza: 988, durata: 0.13)]
    let campioni = Suoni.campioni(note: note, ampiezza: 0.4, smussatura: 0.22,
                                  frequenzaCampionamento: fs)

    check("il suono ha dei campioni", !campioni.isEmpty)
    check("la durata corrisponde alle note",
          abs(Double(campioni.count) - (0.10 + 0.13) * fs) < 4)

    if let primo = campioni.first, let ultimo = campioni.last {
      check("il primo campione è a zero (nessun click in entrata)", abs(primo) < 1e-4)
      check("l'ultimo campione è a zero (nessun click in uscita)", abs(ultimo) < 1e-4)
    }

    // Nessun salto brusco: un click salterebbe verso l'ampiezza di picco (~0.8
    // qui) tutto in un campione. Una sinusoide morbida, invece, non può muoversi
    // più di 2·π·frequenza·ampiezza/fs per campione: a 988 Hz e 0,4 di ampiezza
    // sono circa 0,056. La soglia sta comoda sopra quel limite fisico e ben
    // sotto il salto che farebbe un click.
    var maxSalto: Float = 0
    for i in 1..<campioni.count {
      maxSalto = max(maxSalto, abs(campioni[i] - campioni[i - 1]))
    }
    check("nessuna discontinuità: passi piccoli fra campioni vicini", maxSalto < 0.08)

    // Deve esserci davvero del segnale, non solo silenzio.
    let picco = campioni.map { abs($0) }.max() ?? 0
    check("il segnale arriva vicino all'ampiezza chiesta", picco > 0.3 && picco <= 0.4001)

    // L'inviluppo sale da zero: i primissimi campioni non sono già al picco.
    check("l'attacco è smussato, non netto", abs(campioni[1]) < picco)

    // Il silenzio (frequenza 0) resta silenzio esatto.
    let muto = Suoni.campioni(note: [Suoni.Nota(frequenza: 0, durata: 0.05)],
                              ampiezza: 0.4, smussatura: 0.22, frequenzaCampionamento: fs)
    check("una pausa è silenzio pieno", muto.allSatisfy { $0 == 0 })

    print("\nfallimenti: \(failures)")
    exit(failures == 0 ? 0 : 1)
  }
}
