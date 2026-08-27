import AVFoundation
import AppKit

/// I suoni di conferma dell'app. Servono a una cosa sola: dire con l'orecchio
/// quello che finora si diceva solo con lo schermo — «ci sono», «ti ho sentito,
/// è giusta», «ancora, riproviamo», «hai finito». In un'app dove spesso proprio
/// lo schermo è quello che non si riesce a guardare bene, un suono che conferma
/// non è un ornamento: è il canale che tiene compagnia a chi legge.
///
/// **Perché sintetizzati e non file audio, né `NSSound(named:)`.**
/// I suoni di sistema sono generici e, soprattutto, non si possono modellare:
/// un tono d'allerta del Mac su «ancora» suonerebbe come un errore, ed è
/// esattamente la cosa che qui non deve succedere mai. Generandoli in codice si
/// controlla ogni cosa che conta per chi ha ipersensibilità uditiva —
/// l'inviluppo morbido che toglie il «tac», la durata cortissima, il volume, e
/// la differenza netta fra «giusta» che sale e «ancora» che resta piatto. In
/// più non entra nessun file binario nel repository. Il prezzo è un po' di
/// matematica qui sotto, tutta verificabile: vedi `Tests/SuoniHarness.swift`.
@MainActor
final class Suoni: ObservableObject {

  /// I quattro momenti che meritano un suono. `rawValue` serve solo al codice;
  /// `titolo` e `spiega` sono per la pagina delle impostazioni, dove un adulto
  /// prova ciascun suono prima di lasciarlo a un ragazzo.
  enum Momento: String, CaseIterable, Identifiable {
    case pronto, giusta, ancora, fine

    var id: String { rawValue }

    var titolo: String {
      switch self {
      case .pronto: "La parola è comparsa"
      case .giusta: "È giusta"
      case .ancora: "Ancora"
      case .fine: "Fine della sessione"
      }
    }

    /// Che cosa dice quel suono, in una riga.
    var spiega: String {
      switch self {
      case .pronto: "Un tocco brevissimo: tocca a te, puoi rispondere."
      case .giusta: "Due note che salgono: ti ho sentito, è giusta."
      case .ancora: "Un tocco piatto e neutro: non è venuta, riproviamo. Mai un suono da errore."
      case .fine: "Una piccola cadenza che chiude, sempre incoraggiante."
      }
    }
  }

  /// Vero mentre il microfono sta valutando una risposta. Finché è vero, non
  /// esce nessun suono: altrimenti il Mac sentirebbe sé stesso e lo scriverebbe
  /// nella trascrizione, rovinando il verdetto. È il cancello che rende sicuro
  /// agganciare i suoni al motore della sessione. Chi lo usa lo tiene allineato
  /// alla finestra di ascolto (`beginWindow`/`endWindow` in `SessionEngine`).
  var microfonoInAscolto = false

  private let motore = AVAudioEngine()
  private let lettore = AVAudioPlayerNode()
  private let frequenzaCampionamento = 44_100.0
  private let formato: AVAudioFormat
  private var avviato = false

  init() {
    // Un solo canale: questi suoni sono centrati, non hanno una posizione nello
    // spazio, e il mixer di uscita pensa lui alla conversione verso l'hardware.
    formato = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                            sampleRate: frequenzaCampionamento,
                            channels: 1, interleaved: false)!
    motore.attach(lettore)
    motore.connect(lettore, to: motore.mainMixerNode, format: formato)
  }

  // MARK: - Riproduzione

  /// Suona il momento indicato, se le impostazioni lo consentono e il microfono
  /// non sta ascoltando. `quota` (0…1) conta solo per `.fine`: quante parole
  /// sono venute, per una cadenza adeguata ma sempre in salita.
  func suona(_ momento: Momento, quota: Double = 1, a11y: A11ySettings) {
    guard !microfonoInAscolto else { return }
    riproduci(momento, quota: quota, a11y: a11y, anteprima: false)
  }

  /// Come `suona`, ma per il pulsante «Ascolta» delle impostazioni: si sente
  /// anche a suoni spenti e a microfono chiuso, perché serve proprio a decidere
  /// se accenderli. La forma del suono resta quella vera (volume e profilo
  /// dell'accessibilità inclusi): l'adulto sente ciò che sentirà il ragazzo.
  func anteprima(_ momento: Momento, quota: Double = 1, a11y: A11ySettings) {
    riproduci(momento, quota: quota, a11y: a11y, anteprima: true)
  }

  private func riproduci(_ momento: Momento, quota: Double, a11y: A11ySettings, anteprima: Bool) {
    guard let resa = resa(a11y: a11y, forza: anteprima) else { return }
    let note = note(per: momento, quota: quota, resa: resa)
    let campioni = Suoni.campioni(note: note,
                                  ampiezza: resa.ampiezza,
                                  smussatura: resa.smussatura,
                                  frequenzaCampionamento: frequenzaCampionamento)
    guard let buffer = buffer(da: campioni) else { return }
    avvia()
    guard avviato else { return }
    lettore.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
  }

  private func avvia() {
    guard !avviato else { return }
    do {
      try motore.start()
      lettore.play()
      avviato = true
    } catch {
      // Un Mac senza uscita audio non deve fermare l'allenamento: si resta
      // muti e si annota, come per ogni guasto che non vale interrompere.
      Log.warn("Il motore dei suoni non è partito: \(error.localizedDescription)")
    }
  }

  private func buffer(da campioni: [Float]) -> AVAudioPCMBuffer? {
    guard !campioni.isEmpty,
          let buffer = AVAudioPCMBuffer(pcmFormat: formato,
                                        frameCapacity: AVAudioFrameCount(campioni.count)),
          let canale = buffer.floatChannelData else { return nil }
    buffer.frameLength = AVAudioFrameCount(campioni.count)
    campioni.withUnsafeBufferPointer { canale[0].update(from: $0.baseAddress!, count: campioni.count) }
    return buffer
  }

  // MARK: - Come le disabilità cambiano i suoni

  /// La forma del suono dopo aver ascoltato le impostazioni: quanto forte,
  /// quanto lungo, quanto morbido, e se deve farsi capire con più nettezza.
  private struct Resa {
    var ampiezza: Double
    var scalaDurata: Double
    var smussatura: Double
    /// Vero quando il suono sostituisce un colore che non arriva: allora
    /// «giusta» e «ancora» devono distinguersi con chiarezza, non sparire.
    var chiarezza: Bool
    /// Modalità calma accesa: la fine si fa gentile, mai una fanfara.
    var calmo: Bool
  }

  /// Traduce le impostazioni di accessibilità in una forma sonora. Torna `nil`
  /// quando non si deve suonare affatto.
  private func resa(a11y: A11ySettings, forza: Bool) -> Resa? {
    guard forza || a11y.soundsEnabled else { return nil }

    // Margine abbondante sotto il tetto: un suono di conferma non deve mai
    // saturare né far sobbalzare. Il volume scelto lavora dentro questo tetto.
    var ampiezza = max(0, min(1, a11y.volumeSuoni)) * 0.5
    var scalaDurata = 1.0
    var smussatura = 0.22
    var chiarezza = false

    // Modalità calma (autismo, ipersensibilità): più basso, più corto, più
    // morbido. Mai fanfare.
    if a11y.calmMode {
      ampiezza *= 0.6
      scalaDurata *= 0.85
      smussatura = min(0.45, smussatura + 0.12)
    }

    // Chi chiede meno movimento spesso chiede anche meno stimoli: si attenua.
    if a11y.reducedMotion {
      ampiezza *= 0.9
      scalaDurata *= 0.92
    }

    // Daltonismo e altissimo contrasto (ipovisione): qui il suono prende il
    // posto del colore, quindi conta di più. Si rende «giusta»/«ancora» più
    // distinti e si tiene un pavimento di volume perché restino udibili — senza
    // gridare, e senza scavalcare la modalità calma se è accesa insieme.
    if a11y.colorVision != .standard || a11y.theme == .altoContrasto {
      chiarezza = true
      ampiezza = max(ampiezza, a11y.calmMode ? 0.12 : 0.18)
    }

    // VoiceOver acceso: non si parla sopra il sintetizzatore. Suoni ancora più
    // brevi e un filo più bassi, così cedono il passo alla voce.
    if NSWorkspace.shared.isVoiceOverEnabled {
      scalaDurata *= 0.6
      ampiezza *= 0.85
    }

    guard ampiezza > 0 else { return nil }
    return Resa(ampiezza: ampiezza, scalaDurata: scalaDurata, smussatura: smussatura,
                chiarezza: chiarezza, calmo: a11y.calmMode)
  }

  // MARK: - Le note di ogni momento

  private func note(per momento: Momento, quota: Double, resa: Resa) -> [Nota] {
    let s = resa.scalaDurata
    func n(_ frequenza: Double, _ durata: Double) -> Nota { Nota(frequenza: frequenza, durata: durata * s) }
    // Una pausa: un tratto di silenzio, per separare due tocchi uguali.
    func pausa(_ durata: Double) -> Nota { Nota(frequenza: 0, durata: durata * s) }

    switch momento {
    case .pronto:
      // Un solo tocco cortissimo e discreto: «ci sono, tocca a te».
      return [n(880, 0.07)]

    case .giusta:
      // Due note che salgono. Con più chiarezza partono da più in basso, così
      // la salita è inequivocabile per chi si affida solo all'orecchio.
      return resa.chiarezza ? [n(587, 0.10), n(988, 0.15)] : [n(659, 0.10), n(988, 0.13)]

    case .ancora:
      // Due tocchi *alla stessa altezza*: nessuna discesa, nessun tono cupo,
      // nessun buzz. Un pianoro che dice «riproviamo», non «hai sbagliato». È
      // la cosa più importante di tutto il file: due colpi uguali si leggono
      // come «ancora», mai come una bocciatura.
      return [n(523, 0.085), pausa(0.05), n(523, 0.095)]

    case .fine:
      // Una cadenza che sale sempre, mai triste. La quota di parole venute la
      // rende più o meno ricca, ma la direzione resta in su. In modalità calma
      // si riduce a due note gentili: nessun trionfo.
      if resa.calmo || quota < 0.5 {
        return [n(523, 0.17), n(659, 0.26)]
      } else if quota >= 0.8 {
        return [n(523, 0.14), n(659, 0.14), n(784, 0.16), n(1047, 0.24)]
      } else {
        return [n(523, 0.15), n(659, 0.15), n(784, 0.22)]
      }
    }
  }

  // MARK: - Sintesi (pura e verificabile)

  /// Una nota: una frequenza per una durata. Frequenza 0 vuol dire silenzio.
  struct Nota {
    let frequenza: Double
    let durata: Double
  }

  /// Trasforma una sequenza di note in campioni audio, con un inviluppo a
  /// coseno rialzato su ogni nota.
  ///
  /// L'inviluppo è il cuore della faccenda: un'onda che parte o finisce di
  /// scatto produce un «tac» — una discontinuità — che fa sobbalzare chi ha
  /// ipersensibilità uditiva. Qui ogni nota entra da zero e torna a zero con
  /// una salita e una discesa morbide, così il primo e l'ultimo campione sono
  /// esattamente 0 e non c'è nessun salto. `smussatura` è la frazione della
  /// nota spesa a salire e scendere: più alta, più morbido. Che tutto questo
  /// funzioni davvero lo controlla `Tests/SuoniHarness.swift`, contando i
  /// campioni invece di fidarsi dell'orecchio (che qui non abbiamo).
  static func campioni(note: [Nota], ampiezza: Double, smussatura: Double,
                       frequenzaCampionamento fs: Double) -> [Float] {
    var uscita: [Float] = []
    let smuss = min(0.5, max(0.0, smussatura))
    for nota in note {
      let n = max(1, Int((nota.durata * fs).rounded()))
      let rampa = max(1, min(n / 2, Int(Double(n) * smuss)))
      for i in 0..<n {
        let inviluppo: Double
        if i < rampa {
          inviluppo = 0.5 - 0.5 * cos(Double.pi * Double(i) / Double(rampa))
        } else if i >= n - rampa {
          let k = n - 1 - i
          inviluppo = 0.5 - 0.5 * cos(Double.pi * Double(k) / Double(rampa))
        } else {
          inviluppo = 1
        }
        let t = Double(i) / fs
        let onda = nota.frequenza > 0 ? sin(2 * Double.pi * nota.frequenza * t) : 0
        uscita.append(Float(onda * inviluppo * ampiezza))
      }
    }
    return uscita
  }
}
