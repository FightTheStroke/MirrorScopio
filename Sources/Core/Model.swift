import Foundation
import SwiftUI

// MARK: - Configurazione

enum MaskMode: String, CaseIterable, Identifiable, Codable {
  case none, post, both
  var id: String { rawValue }
  var label: String {
    switch self {
    case .none: "Nessuna"
    case .post: "Dopo lo stimolo"
    case .both: "Prima e dopo"
    }
  }
}

enum Staircase: String, CaseIterable, Identifiable, Codable {
  case fixed, oneUpOneDown, twoDownOneUp
  var id: String { rawValue }
  var label: String {
    switch self {
    case .fixed: "Esposizione fissa"
    case .oneUpOneDown: "Adattiva 1-su / 1-giù (~50%)"
    case .twoDownOneUp: "Adattiva 2-giù / 1-su (~71%)"
    }
  }
}

/// Livelli pronti all'uso: l'operatore sceglie chi ha davanti, non i millisecondi.
enum Level: String, CaseIterable, Identifiable, Codable {
  case inizio, base, intermedio, avanzato, personalizzato

  var id: String { rawValue }

  var title: String {
    switch self {
    case .inizio: "Lentissimo"
    case .base: "Lento"
    case .intermedio: "Veloce"
    case .avanzato: "Fulmine"
    case .personalizzato: "Su misura"
    }
  }

  var subtitle: String { subtitle(for: .lettura) }

  /// Il livello regola due cose insieme: **quanto durano** le parole sullo
  /// schermo e **quanto sono difficili**. In modalità Scrivi la parola non si
  /// vede — il Mac la dice — quindi metà di quella descrizione sarebbe falsa:
  /// resta la difficoltà, sparisce il tempo. Un'app che promette millesimi di
  /// secondo dove non ce ne sono insegna a non fidarsi di quello che scrive.
  func subtitle(for mode: SessionMode) -> String {
    switch mode {
    case .lettura:
      switch self {
      case .inizio: "Sillabe, quasi un secondo"
      case .base: "Parole corte, mezzo secondo"
      case .intermedio: "Parole medie, un lampo"
      case .avanzato: "Parole lunghe, lampo brevissimo"
      case .personalizzato: "Deciso dall'adulto"
      }
    case .scrittura:
      switch self {
      case .inizio: "Sillabe semplici"
      case .base: "Parole corte, due sillabe"
      case .intermedio: "Parole medie, tre sillabe"
      case .avanzato: "Parole lunghe, quattro sillabe"
      case .personalizzato: "Deciso dall'adulto"
      }
    }
  }

  var symbol: String {
    switch self {
    case .inizio: "tortoise.fill"
    case .base: "hare.fill"
    case .intermedio: "bolt.fill"
    case .avanzato: "flame.fill"
    case .personalizzato: "slider.horizontal.3"
    }
  }

  func apply(to c: inout SessionConfig) {
    switch self {
    case .inizio:
      c.set = .sillabePiane; c.exposureMs = 900; c.stepMs = 40; c.trials = 12
    case .base:
      c.set = .bisillabe; c.exposureMs = 600; c.stepMs = 30; c.trials = 15
    case .intermedio:
      c.set = .trisillabe; c.exposureMs = 300; c.stepMs = 20; c.trials = 20
    case .avanzato:
      c.set = .quadrisillabe; c.exposureMs = 150; c.stepMs = 15; c.trials = 20
    case .personalizzato:
      break
    }
  }
}

/// Che cosa si esercita in questa sessione.
enum SessionMode: String, CaseIterable, Identifiable, Codable {
  /// Lampeggia una parola, la si legge ad alta voce, il Mac ascolta.
  case lettura
  /// Il Mac pronuncia una parola, la si scrive alla tastiera.
  case scrittura

  var id: String { rawValue }

  var label: String {
    switch self {
    case .lettura: "Leggi"
    case .scrittura: "Scrivi"
    }
  }

  var childHint: String {
    switch self {
    case .lettura: "Appare una parola per un lampo. Tu la leggi ad alta voce."
    case .scrittura: "Il Mac dice una parola. Tu la scrivi."
    }
  }

  var symbol: String {
    switch self {
    case .lettura: "eye.fill"
    case .scrittura: "keyboard.fill"
    }
  }
}

/// Quanto è impegnativo il **dettato**.
///
/// In lettura la difficoltà è il tempo: la parola resta meno. Scrivendo il
/// tempo non c'entra niente — la parola si sente, non si vede — e quello che
/// cresce è la complessità: prima parole facili, poi parole con le trappole
/// ortografiche, poi frasi, infine frasi vere di cui bisogna tenere a mente il
/// senso mentre si scrive.
///
/// È la progressione usata dai software di riabilitazione della disortografia
/// (parola → frase → brano), e ha una ragione precisa: scrivere una frase
/// intera non è scrivere più parole, è reggere insieme significato, ordine e
/// ortografia. Sono muscoli diversi e vanno allenati in quest'ordine.
enum WritingLevel: String, CaseIterable, Identifiable, Codable {
  case parole, paroleDifficili, frasiBrevi, frasiIntere

  var id: String { rawValue }

  var title: String {
    switch self {
    case .parole: "Parole semplici"
    case .paroleDifficili: "Parole difficili"
    case .frasiBrevi: "Frasi brevi"
    case .frasiIntere: "Frasi intere"
    }
  }

  var subtitle: String {
    switch self {
    case .parole: "Due sillabe, senza trappole"
    case .paroleDifficili: "gn, gl, sc, ch, doppie"
    case .frasiBrevi: "Tre o quattro parole"
    case .frasiIntere: "Frasi vere, di senso compiuto"
    }
  }

  var symbol: String {
    switch self {
    case .parole: "textformat.abc"
    case .paroleDifficili: "character.magnify"
    case .frasiBrevi: "text.alignleft"
    case .frasiIntere: "text.quote"
    }
  }

  /// Vero quando lo stimolo è fatto di più parole: allora serve poterle
  /// ricontrollare una per una.
  var isSentences: Bool { self == .frasiBrevi || self == .frasiIntere }

  func apply(to c: inout SessionConfig) {
    switch self {
    case .parole: c.set = .bisillabe; c.trials = 15
    case .paroleDifficili: c.set = .digrammi; c.trials = 15
    case .frasiBrevi: c.set = .frasiBrevi; c.trials = 10
    // Poche: una frase intera costa fatica, e la fatica va dosata.
    case .frasiIntere: c.set = .frasiIntere; c.trials = 8
    }
  }
}

struct SessionConfig: Codable, Equatable {
  var mode: SessionMode = .lettura
  var level: Level = .base
  var writingLevel: WritingLevel = .parole

  var set: StimulusSet = .bisillabe
  var customList: String = ""
  var shuffle = true
  var uppercase = false
  var trials = 20

  /// Prime parole della sessione, mostrate molto più a lungo per prendere la mano.
  var warmupTrials = 3

  var exposureMs: Double = 600
  var staircase: Staircase = .twoDownOneUp
  var stepMs: Double = 15
  var minExposureMs: Double = 16
  var maxExposureMs: Double = 1000

  var fixationMs: Double = 900
  var maskMode: MaskMode = .post
  var maskMs: Double = 200
  var interTrialMs: Double = 1200

  /// Tempo massimo di attesa della risposta vocale prima di registrare "nessuna risposta".
  var responseTimeoutMs: Double = 4000
  /// Silenzio necessario dopo l'ultima parola per considerare conclusa la risposta.
  ///
  /// Sette decimi erano troppi: sommati all'attesa del testo definitivo
  /// facevano passare più di un secondo fra la parola detta e qualsiasi segno
  /// sullo schermo, e in quel vuoto chi legge ripete — rovinando la risposta
  /// che aveva già dato giusta. Quattro decimi e mezzo restano sopra la pausa
  /// che si fa naturalmente in mezzo a una frase, quindi non tagliano chi sta
  /// ancora parlando.
  var endpointSilenceMs: Double = 450


  /// Analisi qualitativa degli errori con il modello Apple on-device.
  var useAppleIntelligence = true

  /// Permette di scendere sotto il limite di lampeggio.
  ///
  /// Sta qui e non fra le opzioni del ragazzo: è una scelta che un adulto fa
  /// consapevolmente, sapendo che cosa comporta, per un bambino di cui conosce
  /// la storia clinica. Il valore predefinito è «no» perché chi non ne sa
  /// niente non deve poterlo attivare per sbaglio.
  var lampeggioVeloceConsentito = false

  var resolvedItems: [String] {
    let base = set == .personalizzata
      ? customList.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
      : set.items
    guard !base.isEmpty else { return [] }

    var out: [String] = []
    while out.count < trials {
      out.append(contentsOf: shuffle ? base.shuffled() : base)
    }
    let slice = Array(out.prefix(trials))
    return uppercase ? slice.map { $0.uppercased() } : slice
  }
}

// MARK: - Quanto lampeggia lo schermo

extension SessionConfig {

  /// Il limite oltre il quale uno schermo che si accende e si spegne può
  /// scatenare una crisi in chi ha un'epilessia fotosensibile.
  ///
  /// Tre volte al secondo è la soglia delle linee guida internazionali sui
  /// contenuti web (WCAG 2.3.1). Questa app mostra parole ad alto contrasto
  /// alternate a una maschera, cioè esattamente il tipo di alternanza a cui
  /// quella soglia si riferisce, e la usa un ragazzo **da solo**: se lo
  /// schermo lampeggia troppo in fretta non c'è nessun adulto accanto a
  /// fermarlo.
  static let limiteLampeggioHz: Double = 3

  /// Quanto dura il ciclo visivo completo, nel caso peggiore, in millesimi.
  ///
  /// Nel caso peggiore, cioè: esposizione al minimo che la scala adattiva può
  /// raggiungere, e risposta immediata. Il tempo di ascolto e il riscontro non
  /// si contano apposta — durano quanto ci mette una persona, e una stima
  /// ottimistica qui vorrebbe dire dichiarare sicuro un ritmo che sicuro non
  /// è.
  var durataCicloPeggioreMs: Double {
    let mascheraPrima = maskMode == .both ? maskMs : 0
    let mascheraDopo = maskMode != .none ? maskMs : 0
    return fixationMs + mascheraPrima + max(minExposureMs, 1) + mascheraDopo + interTrialMs
  }

  /// Quante volte al secondo si ripete il ciclo completo, nel caso peggiore.
  var frequenzaCicloHz: Double {
    let ms = durataCicloPeggioreMs
    return ms > 0 ? 1000 / ms : .infinity
  }

  /// Vero quando questa configurazione fa lampeggiare lo schermo più in fretta
  /// del limite.
  var oltreIlLimiteDiLampeggio: Bool {
    frequenzaCicloHz > SessionConfig.limiteLampeggioHz
  }

  /// La durata minima che il ciclo deve avere per restare sotto il limite.
  static var durataCicloMinimaMs: Double { 1000 / limiteLampeggioHz }
}

// MARK: - Esito di una prova

enum ErrorKind: String, Codable {
  case none, omissioneTotale, inversione, sostituzione, omissione, aggiunta, altroErrore

  var label: String {
    switch self {
    case .none: "—"
    case .omissioneTotale: "nessuna risposta"
    case .inversione: "inversione"
    case .sostituzione: "sostituzione"
    case .omissione: "omissione"
    case .aggiunta: "aggiunta"
    case .altroErrore: "errore"
    }
  }
}

struct Trial: Identifiable, Codable {
  let id: Int
  let stimulus: String
  var response: String = ""
  var correct = false
  var errorKind: ErrorKind = .none
  var requestedExposureMs: Double = 0
  var actualExposureMs: Double = 0
  /// Latenza fra la scomparsa dello stimolo e l'inizio della voce.
  var vocalLatencyMs: Double?
  var editDistance: Int = 0
  var confidence: Double?
  var note: String = ""
  /// Frequenza dello schermo su cui la parola è stata mostrata, in hertz.
  ///
  /// Senza questo numero la durata richiesta e quella ottenuta non si possono
  /// confrontare fra due Mac: a 60 Hz non esiste un'esposizione di 30 ms, il
  /// frame più vicino ne dura 16,7. Scriverlo è l'unico modo perché chi legge
  /// il referto sappia quanto vale davvero il numero che ha davanti.
  var refreshHz: Double?
  /// Quanti frame sarebbero serviti per la durata richiesta e quanti ne sono
  /// stati davvero disegnati.
  var frameRichiesti: Int?
  var frameEffettivi: Int?
  /// Vero quando lo schermo ha saltato almeno un frame durante l'esposizione:
  /// la parola è rimasta visibile più del dovuto e la prova va guardata con
  /// sospetto invece che contata come le altre.
  var frameSaltato: Bool = false
  /// Vero quando il turno è stato interrotto da qualcosa che non c'entra con
  /// chi legge: il Mac si è addormentato, la finestra è passata in secondo
  /// piano, il microfono è sparito. **Non è un'omissione**: contarla come tale
  /// vorrebbe dire scrivere nel referto che un ragazzo non ha risposto quando
  /// nessuno gli aveva chiesto niente.
  var interrotto: Bool = false
  /// Perché è stato interrotto, con parole che si possono leggere.
  var motivoInterruzione: String?
}

// MARK: - Scala adattiva

/// Gestisce la variazione dell'esposizione e la stima della soglia dalle inversioni.
struct StaircaseState {
  private(set) var exposure: Double
  private(set) var reversals: [Double] = []
  private var consecutiveCorrect = 0
  private var lastDirection = 0  // -1 in discesa, +1 in salita
  let rule: Staircase
  let step: Double
  let minMs: Double
  let maxMs: Double

  init(config: SessionConfig) {
    exposure = config.exposureMs
    rule = config.staircase
    step = config.stepMs
    minMs = config.minExposureMs
    maxMs = config.maxExposureMs
  }

  mutating func update(correct: Bool) {
    guard rule != .fixed else { return }
    var direction = 0

    if correct {
      consecutiveCorrect += 1
      let needed = rule == .twoDownOneUp ? 2 : 1
      if consecutiveCorrect >= needed {
        consecutiveCorrect = 0
        direction = -1
      }
    } else {
      consecutiveCorrect = 0
      direction = 1
    }

    guard direction != 0 else { return }
    if lastDirection != 0 && direction != lastDirection { reversals.append(exposure) }
    lastDirection = direction
    exposure = min(maxMs, max(minMs, exposure + Double(direction) * step))
  }

  /// Soglia stimata come media delle ultime inversioni, che è la stima standard
  /// in psicofisica una volta scartate le prime oscillazioni ampie.
  var threshold: Double? {
    guard reversals.count >= 4 else { return nil }
    let tail = reversals.suffix(max(4, (reversals.count / 2) * 2))
    return tail.reduce(0, +) / Double(tail.count)
  }
}
