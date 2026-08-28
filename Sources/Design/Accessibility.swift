import SwiftUI

// MARK: - Profili di accessibilità

/// Un profilo imposta in un colpo solo carattere, dimensioni, colori e ritmo.
/// Ereditato da MirrorBuddy (`lib/accessibility/accessibility-store/profiles.ts`),
/// tradotto per un'app nativa e per un compito di lettura rapida.
enum A11yProfile: String, CaseIterable, Identifiable, Codable {
  case nessuno, dislessia, autismo, adhd, ipovisione, paralisiCerebrale

  var id: String { rawValue }

  var label: String {
    switch self {
    case .nessuno: "Nessuno in particolare"
    case .dislessia: "Dislessia"
    case .autismo: "Autismo"
    case .adhd: "ADHD"
    case .ipovisione: "Vedo poco"
    case .paralisiCerebrale: "Paralisi cerebrale"
    }
  }

  var symbol: String {
    switch self {
    case .nessuno: "person.fill"
    case .dislessia: "textformat.abc"
    case .autismo: "leaf.fill"
    case .adhd: "target"
    case .ipovisione: "eye.fill"
    case .paralisiCerebrale: "figure.roll"
    }
  }

  /// Che cosa cambia davvero, detto senza gergo.
  var hint: String {
    switch self {
    case .nessuno: "Impostazioni standard."
    case .dislessia: "Carattere OpenDyslexic, lettere più distanziate, sfondo crema, più tempo."
    case .autismo: "Niente animazioni né sorprese, colori calmi, ritmo sempre uguale, pause regolari."
    case .adhd: "Schermo pulito, sessioni corte, pause frequenti, niente distrazioni ai bordi."
    case .ipovisione: "Tutto molto più grande, altissimo contrasto, parola letta ad alta voce."
    case .paralisiCerebrale: "Tutto grande, più tempo per rispondere, si usa solo la voce o pochi tasti."
    }
  }

  func apply(to s: inout A11ySettings) {
    // Si riparte sempre dai valori standard, così i profili non si sommano fra loro.
    s = A11ySettings()
    switch self {
    case .nessuno:
      break
    case .dislessia:
      s.typeface = .openDyslexic
      s.letterSpacing = 6
      s.textScale = 1.15
      s.theme = .sabbia
      s.extraResponseTime = 1.3
    case .autismo:
      s.reducedMotion = true
      s.calmMode = true
      s.showFeedbackPerWord = true
      s.soundsEnabled = false
      s.pauseEveryNWords = 5
      s.textScale = 1.1
      s.theme = .chiaro
    case .adhd:
      s.distractionFree = true
      s.pauseEveryNWords = 5
      s.reducedMotion = true
      s.shorterSessions = true
    case .ipovisione:
      s.typeface = .atkinson
      s.textScale = 1.45
      s.theme = .altoContrasto
      s.speakCorrectWord = true
      s.letterSpacing = 4
    case .paralisiCerebrale:
      s.textScale = 1.3
      s.extraResponseTime = 1.6
      s.reducedMotion = true
      s.speakCorrectWord = true
    }
    s.profile = self
  }
}

/// Tutte le preferenze che riguardano *come* si vede e si usa l'app,
/// separate dai parametri clinici della prova.
struct A11ySettings: Codable, Equatable {
  var profile: A11yProfile = .nessuno

  // Aspetto
  var theme: ThemeChoice = .auto
  var colorVision: ColorVision = .standard
  var typeface: TypefaceChoice = .arrotondato
  /// Moltiplica ogni dimensione di testo dell'interfaccia. 1.0 = già grande.
  var textScale: Double = 1.0
  /// Spazio extra fra le lettere della parola-stimolo, in punti.
  var letterSpacing: Double = 2
  /// Dimensione della parola-stimolo, in punti.
  var stimulusSize: Double = 120

  // Ritmo e sensorialità
  var reducedMotion = false
  /// Niente colori accesi, niente esclamazioni, nessun elemento che compare a sorpresa.
  var calmMode = false
  /// Toglie tutto ciò che non serve dai bordi dello schermo durante la prova.
  var distractionFree = false
  /// Mostra da quanto dura la sessione, in alto, durante l'allenamento.
  ///
  /// Spento di proposito: un tempo che scorre sotto gli occhi mette fretta, e
  /// qui la fretta non serve a nessuno. Ma c'è chi lo chiede — chi ha venti
  /// minuti fra una cosa e l'altra, e chi si tranquillizza sapendo quanto
  /// manca invece di immaginarlo. Conta il tempo passato, non quello che resta:
  /// non è un conto alla rovescia.
  var showTimer = false
  /// Acceso di serie: il suono è l'unico riscontro che arriva a chi lo schermo
  /// non riesce a guardarlo mentre legge, ed è breve e morbido di proposito.
  /// Il profilo Autismo lo spegne, e si spegne comunque dalle Impostazioni.
  var soundsEnabled = true
  /// Voce di sistema scelta per dettare le parole. `nil` = la migliore trovata.
  var voiceIdentifier: String? = nil
  /// Velocità della voce. 0.4 è già più lenta del normale.
  var voiceRate: Double = 0.42
  /// Ogni quante parole proporre una pausa. 0 = mai.
  var pauseEveryNWords = 0
  /// Sessioni più corte (usato dal profilo ADHD).
  var shorterSessions = false
  /// Moltiplica il tempo concesso per rispondere.
  var extraResponseTime: Double = 1.0

  // Feedback
  var showFeedbackPerWord = true
  /// Nasconde punteggi, percentuali e stelle: per chi si mette in ansia.
  var hideScore = false
  /// A fine parola il Mac pronuncia la parola giusta.
  var speakCorrectWord = false

  // Suoni di conferma (aggiunta: motore in `Sources/Core/Suoni.swift`).
  // `soundsEnabled` qui sopra è già l'interruttore generale — lo riuso invece
  // di aggiungerne un secondo, così il profilo Autismo che lo spegne continua a
  // valere anche per i suoni nuovi. Qui serve solo il volume.
  /// Volume dei suoni di conferma, da 0 (muti) a 1. Lavora sotto un tetto
  /// prudente: anche a 1 il suono non satura.
  var volumeSuoni: Double = 0.7

  /// Dimensione di un testo dell'interfaccia, già scalata.
  func size(_ base: Double) -> CGFloat { CGFloat(base * textScale) }

  /// La scala dei testi: sette taglie, non venti.
  ///
  /// Prima ogni schermata sceglieva il proprio numero — 15 qui, 16 la', 14
  /// nella riga accanto. Differenze di un punto che nessuno decide e nessuno
  /// vede una per una, ma che messe insieme fanno una pagina che non ha ritmo:
  /// si legge come una stanza dove i quadri sono appesi tutti ad altezze
  /// leggermente diverse. Sette taglie distanti fra loro si distinguono a
  /// colpo d'occhio, ed e' proprio quello che serve a chi fatica a leggere:
  /// capire che cosa e' titolo e che cosa e' nota senza doverlo decifrare.
  ///
  /// Le taglie sono quelle *di partenza*: `size(_:)` le moltiplica poi per
  /// l'ingrandimento scelto, quindi la scala resta proporzionata a ogni misura.
  enum Testo: Double {
    /// Note a margine, unita' di misura, didascalie.
    case nota = 13
    /// Etichette, voci secondarie, testo dentro elementi piccoli.
    case etichetta = 15
    /// Il testo normale: quello che si legge davvero.
    case corpo = 17
    /// Testo guida, voci di elenco, pulsanti.
    case guida = 20
    /// Titoletti di sezione dentro una pagina.
    case sezione = 24
    /// Il titolo di una pagina.
    case titolo = 30
    /// I numeri grandi e le poche parole che devono farsi vedere da lontano.
    case titoloGrande = 40
  }

  /// Il carattere per un ruolo della scala, gia' ingrandito e gia' del tipo
  /// scelto (compreso quello pensato per la dislessia).
  func font(_ testo: Testo, _ weight: Font.Weight = .regular) -> Font {
    typeface.font(size: size(testo.rawValue), weight: weight)
  }

  /// Durata di un'animazione: zero quando il movimento va evitato.
  func animation(_ base: Double = 0.25) -> Animation? {
    reducedMotion ? nil : .easeOut(duration: base)
  }
}

// MARK: - Le manopole dell'app messe insieme a quelle del Mac

/// Quello che l'app deve davvero fare, dopo aver messo insieme due cose: le
/// preferenze che chi usa l'app ha già dato **al Mac**, e le manopole di
/// MirrorScopio.
///
/// Il punto di partenza è il Mac. Se lì è già stato chiesto meno movimento,
/// qui il movimento non c'è, senza doverlo ripetere. Le manopole dell'app
/// vengono dopo e possono **aggiungere**, mai togliere: se il Mac chiede meno
/// movimento e nell'app la casella è spenta, il movimento resta tolto. Togliere
/// in silenzio una cosa che qualcuno ha chiesto al proprio computer sarebbe
/// esattamente il difetto che questo tipo è nato per riparare — e la scelta
/// consapevole di fare diversamente esiste già dove ha senso: il tema si può
/// mettere a mano su «Chiaro» invece di lasciarlo su «Come il Mac».
///
/// Le viste ricevono questo, non `A11ySettings`: così nessuna schermata può
/// decidere come disegnarsi guardando solo metà della verità. Le manopole
/// grezze restano raggiungibili con `manopole`, ma servono a un caso solo —
/// le due schermate che le *scrivono*.
struct EffettiveImpostazioniAccessibilita: Equatable {
  private let scelte: A11ySettings
  /// Che cosa sta chiedendo il Mac in questo momento.
  let mac: StatoAccessibilitaDelMac

  init(_ scelte: A11ySettings = A11ySettings(),
       mac: StatoAccessibilitaDelMac = .nessunaRichiesta) {
    self.scelte = scelte
    self.mac = mac
  }

  /// Le manopole così come sono salvate. Solo per chi le cambia.
  var manopole: A11ySettings { scelte }

  // MARK: Quello che arriva tale e quale dalle manopole

  var profile: A11yProfile { scelte.profile }
  var colorVision: ColorVision { scelte.colorVision }
  var typeface: TypefaceChoice { scelte.typeface }
  var textScale: Double { scelte.textScale }
  var letterSpacing: Double { scelte.letterSpacing }
  var stimulusSize: Double { scelte.stimulusSize }
  var calmMode: Bool { scelte.calmMode }
  var distractionFree: Bool { scelte.distractionFree }
  var showTimer: Bool { scelte.showTimer }
  var soundsEnabled: Bool { scelte.soundsEnabled }
  var voiceIdentifier: String? { scelte.voiceIdentifier }
  var voiceRate: Double { scelte.voiceRate }
  var pauseEveryNWords: Int { scelte.pauseEveryNWords }
  var shorterSessions: Bool { scelte.shorterSessions }
  var extraResponseTime: Double { scelte.extraResponseTime }
  var showFeedbackPerWord: Bool { scelte.showFeedbackPerWord }
  var hideScore: Bool { scelte.hideScore }
  var speakCorrectWord: Bool { scelte.speakCorrectWord }
  var volumeSuoni: Double { scelte.volumeSuoni }

  // MARK: Quello che nasce dalle due cose insieme

  /// Niente si muove: o perché l'ha chiesto il Mac, o perché l'ha chiesto qui.
  var reducedMotion: Bool { scelte.reducedMotion || mac.menoMovimento }

  /// Il tema da usare davvero.
  ///
  /// «Come il Mac» vuol dire come il Mac fino in fondo: se lì è acceso
  /// «Aumenta contrasto», qui arriva «Altissimo contrasto» invece del chiaro o
  /// dello scuro di serie. Un tema scelto a mano resta quello scelto a mano:
  /// è la scelta consapevole, e non si scavalca.
  var theme: ThemeChoice {
    if scelte.theme == .auto, mac.piuContrasto { return .altoContrasto }
    return scelte.theme
  }

  /// Il Mac chiede di non usare velature e trasparenze.
  var menoTrasparenza: Bool { mac.menoTrasparenza }

  /// Il Mac chiede che niente si distingua **solo** dal colore.
  ///
  /// Nell'app giusto e sbagliato hanno già simbolo e parola. Restava un posto
  /// dove il colore era solo: la fila di pallini che dice a che punto si è.
  var senzaColore: Bool { mac.senzaColore }

  /// Quanto deve essere opaco uno sfondo velato.
  ///
  /// Le velature servono a dire «questo è sullo sfondo», ma per chi ha chiesto
  /// meno trasparenze sono solo un contrasto in meno: qui diventano piene.
  func velo(_ quanto: Double) -> Double { menoTrasparenza ? 1 : quanto }

  // MARK: Misure che dipendono da chi usa l'app

  /// Il lato minimo di qualunque cosa si possa premere.
  ///
  /// I 44 punti di Apple sono il minimo per una mano ferma. Chi ha paralisi
  /// cerebrale un bersaglio di 44 punti lo colpisce a fatica: nel suo profilo
  /// il minimo sale a 60, ed è la differenza fra un'app che si usa e una che si
  /// abbandona. Prima il profilo lo prometteva a parole e non lo faceva.
  var bersaglio: CGFloat {
    profile == .paralisiCerebrale ? 60 : Metrica.bersaglio
  }

  /// Lo spazio in più fra una riga e l'altra.
  ///
  /// Righe troppo vicine si scavalcano con l'occhio: si rilegge la stessa o si
  /// salta la successiva. È la fatica che il profilo Dislessia prometteva di
  /// togliere da quando esiste, senza che nel codice ci fosse una sola riga che
  /// la togliesse davvero.
  var interlinea: CGFloat {
    let base: Double = profile == .dislessia || typeface == .openDyslexic ? 6 : 0
    return CGFloat(base * textScale)
  }

  // MARK: Le stesse funzioni di prima

  func size(_ base: Double) -> CGFloat { scelte.size(base) }

  func font(_ testo: A11ySettings.Testo, _ weight: Font.Weight = .regular) -> Font {
    scelte.font(testo, weight)
  }

  func animation(_ base: Double = 0.25) -> Animation? {
    reducedMotion ? nil : .easeOut(duration: base)
  }

  /// Le manopole da dare al motore della sessione, con dentro già quello che
  /// chiede il Mac: `Core` non conosce le Impostazioni di Sistema, e i suoni si
  /// adattano a «meno movimento» esattamente come si adatta lo schermo.
  var perIlMotore: A11ySettings {
    var s = scelte
    s.reducedMotion = reducedMotion
    s.theme = theme
    return s
  }
}

/// Le impostazioni effettive viaggiano nell'ambiente, come la palette: una
/// vista non deve poterle ricostruire per conto suo e sbagliarsi.
private struct ImpostazioniKey: EnvironmentKey {
  static let defaultValue = EffettiveImpostazioniAccessibilita()
}

extension EnvironmentValues {
  var impostazioni: EffettiveImpostazioniAccessibilita {
    get { self[ImpostazioniKey.self] }
    set { self[ImpostazioniKey.self] = newValue }
  }
}

extension View {
  /// L'interlinea giusta per chi legge con fatica, applicata dove c'è del testo
  /// che scorre su più righe.
  func interlinea(_ a11y: EffettiveImpostazioniAccessibilita) -> some View {
    lineSpacing(a11y.interlinea)
  }
}
