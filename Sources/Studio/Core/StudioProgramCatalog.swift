import Foundation

enum StudioProgramCatalog {
  static let stageTitles = [
    "Chi, che cosa, dove", "L'idea che conta", "Prima e dopo", "Cause e conseguenze",
    "Aggiorno e trovo gli indizi", "Riassumo con parole mie", "Ricostruisco e controllo",
    "Scelgo come studiare"
  ]
  static let goals = [
    "Sequenze brevi, due consegne e le domande che orientano.",
    "Distinguere l'idea principale dai dettagli.",
    "Riprendere una sequenza al contrario e mettere gli eventi in ordine.",
    "Seguire consegne, fare un piccolo calcolo e collegare causa, evento e conseguenza.",
    "Tenere le ultime informazioni e cercare una frase che sostiene un'inferenza.",
    "Riassumere testi di storia e scienze, con gli aiuti vicini.",
    "Leggere, coprire solo se vuoi, ricostruire, controllare e recuperare ancora.",
    "Usare una strategia in italiano, storia e scienze, spiegando la scelta."
  ]

  struct Passage {
    var title: String
    var subject: String
    var who: String
    var whereWhen: String
    var event: String
    var cause: String
    var consequence: String
    var detail: String
    var keywords: [String]
    var inference: String
    var evidence: String
    var text: String { [who + " " + whereWhen + ".", event, cause, consequence, detail].joined(separator: " ") }
    var summary: String { event + " " + consequence }
    var sheet: String {
      "CHI / CHE COSA: \(who)\nDOVE / QUANDO: \(whereWhen)\nCOSA: \(event)\nPERCHÉ: \(cause)\nPOI: \(consequence)\n3 PAROLE CHIAVE: \(keywords.joined(separator: ", "))\nIN 2 FRASI: \(summary)"
    }
  }

  static func lessons(load: StudioProgramLoad = StudioProgramLoad()) throws -> [StudioLesson] {
    try passages.enumerated().map { offset, passage in
      let stage = offset / 5 + 1
      let session = offset % 5 + 1
      let id = "passi-v1-\(stage)-\(session)"
      var lesson = try StudioLesson(title: "\(stage).\(session) · \(passage.title)",
        subject: passage.subject, source: passage.text)
      lesson.map.ideas = passage.keywords
      lesson.map.connection = passage.summary
      lesson.procedures = [
        StudioProcedure(text: "Leggo una parte e mi fermo."),
        StudioProcedure(text: "Provo a dire l'idea con parole mie."),
        StudioProcedure(text: "Controllo il testo. Gli aiuti restano disponibili.")
      ]
      lesson.program = StudioProgramLesson(catalogID: id, stage: stage, session: session,
        load: load, activities: activities(passage, stage: stage, session: session, id: id, load: load))
      return lesson
    }
  }

  private static func activities(_ p: Passage, stage: Int, session: Int, id: String,
                                 load: StudioProgramLoad) -> [StudioProgramActivity] {
    var result: [StudioProgramActivity] = []
    func add(_ key: String, _ block: StudioProgramBlock, _ kind: StudioProgramKind,
             _ instruction: String, material: String = "", reference: String,
             support: String? = nil, options: [StudioProgramOption] = [], answer: [Int] = []) {
      result.append(StudioProgramActivity(id: "\(id)-\(key)", block: block, kind: kind,
        instruction: instruction, material: material, support: support ?? p.sheet,
        reference: reference, options: options, answer: answer))
    }
    func ordered(_ key: String, _ block: StudioProgramBlock, _ instruction: String,
                 tokens: [String], expected: [Int], material: String? = nil) {
      let options = tokens.enumerated().map { StudioProgramOption(id: $0.offset, text: $0.element) }
      // Le etichette non vengono valutate: si confrontano gli identificatori delle scelte.
      let shuffled = Array(options.dropFirst()) + Array(options.prefix(1))
      add(key, block, .sequence, instruction, material: material ?? tokens.joined(separator: " · "),
        reference: expected.map { tokens[$0] }.joined(separator: " → "),
        support: (material ?? tokens.joined(separator: " · ")) + "\nPuoi tenere la consegna visibile.",
        options: shuffled, answer: expected)
    }
    func choice(_ key: String, _ block: StudioProgramBlock, _ instruction: String,
                correct: String, alternatives: [String], reference: String? = nil) {
      let texts = [correct] + alternatives
      let options = texts.enumerated().map { StudioProgramOption(id: $0.offset, text: $0.element) }
      let shift = session % options.count
      add(key, block, .choice, instruction, material: p.text, reference: reference ?? correct,
        options: Array(options.dropFirst(shift)) + Array(options.prefix(shift)), answer: [0])
    }
    let count = min(max(2, load.memory), stage == 1 ? 3 : 4)
    let digits = (0..<count).map { String((session * 2 + $0 * 3) % 10) }
    let words = Array((p.keywords + ["sentiero"]).prefix(count))
    let tokens = stage == 1 || stage == 3 ? digits : words
    if stage == 5 {
      let keep = min(3, max(2, load.memory))
      let stream = ["finestra", "matita"] + Array(p.keywords.prefix(keep))
      ordered("memoria", .activation, "Tieni soltanto le ultime \(keep) parole, nello stesso ordine.",
        tokens: stream, expected: Array((stream.count - keep)..<stream.count))
    } else {
      let reverse = stage == 3
      ordered("memoria", .activation,
        reverse ? "Scegli i numeri partendo dall'ultimo." : "Scegli gli elementi nello stesso ordine.",
        tokens: tokens, expected: reverse ? Array(tokens.indices.reversed()) : Array(tokens.indices))
    }
    let commandSets = [
      ["Quaderno", "Pagina", "Titolo"],
      ["Mappa", "Idea", "Collegamento"],
      ["Foglio", "Matita", "Gomma"],
      ["Domanda", "Indizio", "Risposta"],
      ["Testo", "Frase", "Punto"]
    ]
    let commands = Array(commandSets[session - 1]
      .prefix(min(max(2, load.instructions), 3)))
    ordered("consegne", .activation, "Segui le consegne: tocca i pulsanti nell'ordine richiesto.",
      tokens: commands, expected: Array(commands.indices),
      material: commands.enumerated().map { "\($0.offset + 1). Tocca «\($0.element)»." }.joined(separator: "\n"))
    if stage == 4 {
      let initial = session + 3
      choice("calcolo", .activation, "Hai \(initial) fogli. Ne usi 2. Quanti ne restano?",
        correct: String(initial - 2), alternatives: [String(initial), String(initial + 2)],
        reference: "\(initial) meno 2 fa \(initial - 2). Puoi contare con le dita o scrivere.")
      result[result.count - 1].material = "Fogli all'inizio: \(initial). Fogli usati: 2."
      result[result.count - 1].support = "Parti da \(initial) e togli un foglio, poi un altro."
    }
    let parts = [p.who + " " + p.whereWhen + ".", p.event, p.cause, p.consequence, p.detail]
    for (index, part) in parts.enumerated() {
      add("lettura-\(index)", .comprehension, .reading, "Leggi questa parte. Puoi anche ascoltarla.",
          material: part, reference: "Hai incontrato una parte del testo, non è una prova di comprensione.")
    }
    if stage == 1 {
      choice("chi", .comprehension, "Di chi o di che cosa parla il testo?",
        correct: p.who, alternatives: ["Un gruppo in piscina", "Un orologio in riparazione"])
      choice("dove", .comprehension, "Dove e quando si svolge?",
        correct: p.whereWhen, alternatives: ["in una palestra, durante una gara", "su una nave, di notte"])
      choice("cosa", .comprehension, "Che cosa succede?",
        correct: p.event, alternatives: ["Si prepara una gara di nuoto.", "Si ripara un orologio."])
    } else if stage == 2 {
      choice("idea", .comprehension, "Quale frase porta l'idea principale?",
        correct: p.summary, alternatives: [p.detail, "Il testo elenca soltanto dei colori."])
      choice("dettaglio", .comprehension, "Quale informazione è un dettaglio, non tutta la storia?",
        correct: p.detail, alternatives: [p.summary, "Il testo non fornisce informazioni."])
    } else if stage == 3 {
      ordered("ordine", .comprehension, "Metti in ordine: prima, poi, alla fine.",
        tokens: [p.event, p.cause, p.consequence], expected: [0, 1, 2], material: p.text)
    } else if stage == 4 {
      choice("causa", .comprehension, "Quale frase spiega perché cambia la situazione?",
        correct: p.cause, alternatives: [p.detail, p.who + "."])
      choice("conseguenza", .comprehension, "Che cosa succede dopo?",
        correct: p.consequence, alternatives: [p.detail, p.event])
    } else if stage == 5 {
      choice("inferenza", .comprehension, "Quale idea puoi ricavare dal testo, anche se non è scritta così?",
        correct: p.inference, alternatives: ["Il risultato non dipende dalle azioni descritte.",
          "Non esiste nessun legame tra gli eventi."])
      choice("indizio", .comprehension, "Quale frase sostiene questa idea: «\(p.inference)»?",
        correct: p.evidence, alternatives: [p.detail, p.who + " " + p.whereWhen + "."])
    } else {
      add("ricostruisco", .comprehension, .open,
        "Fermati: racconta che cosa hai capito. Puoi coprire il testo, ma non devi.",
        material: p.text, reference: p.summary)
    }
    add("scheda", .strategy, .open,
      "Di chi o di che cosa parla il testo? Dillo con parole tue.",
      material: "CHI / CHE COSA?", reference: p.who)
    add("luogo", .strategy, .open, "Dove e quando si svolge?",
      material: "DOVE / QUANDO?", reference: p.whereWhen)
    add("evento", .strategy, .open, "Che cosa succede?",
      material: "COSA?", reference: p.event)
    add("legame", .strategy, .open, "Perché cambia la situazione?",
      material: "PERCHÉ?", reference: p.cause)
    add("poi", .strategy, .open, "Che cosa succede dopo?",
      material: "POI?", reference: p.consequence)
    add("parole", .strategy, .open, "Scegli fino a 3 parole che ti aiutano a ritrovare il filo.",
      reference: "Un esempio: \(p.keywords.joined(separator: ", ")). Altre scelte possono essere utili.")
    if stage == 8 {
      add("titolo", .strategy, .open, "Dai un titolo che faccia capire l'idea principale.",
        reference: "Un esempio: «\(p.title)». Il tuo titolo può essere diverso.")
      add("strategia", .strategy, .open,
        "Quale aiuto sceglieresti per un testo di \(p.subject.lowercased())? Spiega perché.",
        material: "Posso rileggere una parte, usare CHI / COSA / PERCHÉ, scegliere parole chiave o raccontare a voce.",
        reference: "Un esempio: scelgo parole chiave per ritrovare le idee. La scelta è tua: spiega come ti aiuta.")
    }
    let sentences = stage >= 6 ? min(max(2, load.sentences), 5) : 2
    add("riassunto", .retrieval, .open,
      "Riprendi il filo in non più di \(sentences) frasi. Tieni le idee importanti; il testo è sempre disponibile.",
      reference: sentences <= 2 ? p.summary :
        [p.who + " " + p.whereWhen + ".", p.event, p.cause, p.consequence].prefix(sentences).joined(separator: " "))
    if stage >= 7 {
      add("secondo-recupero", .retrieval, .open,
        "Ora prova ancora: qual è l'idea principale? Che cosa la sostiene?",
        material: "Questo è un secondo recupero, non una gara con il primo. Se vuoi, riapri il testo.",
        reference: p.summary + "\nUn indizio: " + p.evidence)
    }
    return result
  }

  static let passages: [Passage] = [
    Passage(title: "La fermata spostata", subject: "Italiano", who: "Nora",
      whereWhen: "è alla fermata, lunedì mattina", event: "Trova un cartello che indica una fermata provvisoria.",
      cause: "Il tratto di strada davanti alla scuola è chiuso per lavori.",
      consequence: "Nora segue la freccia e prende l'autobus dalla piazza.",
      detail: "Il cartello ha un bordo giallo.", keywords: ["fermata", "lavori", "piazza"],
      inference: "Leggere il cartello aiuta Nora a raggiungere la scuola.", evidence: "Nora segue la freccia e prende l'autobus dalla piazza."),
    Passage(title: "Il libro prenotato", subject: "Italiano", who: "Amir",
      whereWhen: "è in biblioteca, nel pomeriggio", event: "Chiede un libro di esplorazioni che non è sullo scaffale.",
      cause: "Un'altra persona lo ha preso in prestito.",
      consequence: "La bibliotecaria prenota il libro e Amir sceglie intanto un altro racconto.",
      detail: "Sul tavolo vicino c'è una lampada verde.", keywords: ["libro", "prestito", "prenotazione"],
      inference: "Amir può leggere qualcosa mentre aspetta.", evidence: "La bibliotecaria prenota il libro e Amir sceglie intanto un altro racconto."),
    Passage(title: "L'orto sul balcone", subject: "Scienze", who: "Le piantine di basilico",
      whereWhen: "sono sul balcone, in una mattina calda", event: "Hanno la terra asciutta.",
      cause: "Il calore favorisce l'evaporazione dell'acqua dal terreno.",
      consequence: "Elia controlla la terra e aggiunge un po' d'acqua.",
      detail: "I vasi sono disposti su una mensola.", keywords: ["basilico", "terra", "acqua"],
      inference: "Guardare il terreno aiuta a decidere quando annaffiare.", evidence: "Elia controlla la terra e aggiunge un po' d'acqua."),
    Passage(title: "La partita al coperto", subject: "Italiano", who: "La squadra del quartiere",
      whereWhen: "è al campo, sabato pomeriggio", event: "Si prepara ad allenarsi all'aperto.",
      cause: "Comincia a piovere e il campo diventa scivoloso.",
      consequence: "La squadra si sposta in palestra per fare gli esercizi.",
      detail: "I palloni sono in una sacca blu.", keywords: ["squadra", "pioggia", "palestra"],
      inference: "La squadra cambia luogo per allenarsi con più sicurezza.", evidence: "Comincia a piovere e il campo diventa scivoloso."),
    Passage(title: "Il pranzo condiviso", subject: "Italiano", who: "Ada e i compagni",
      whereWhen: "sono al parco, all'ora di pranzo", event: "Appoggiano i contenitori sul tavolo.",
      cause: "Si accorgono che non ci sono abbastanza bicchieri per tutti.",
      consequence: "Ada prende i bicchieri di riserva dallo zaino.",
      detail: "Il tavolo si trova vicino a un albero.", keywords: ["pranzo", "bicchieri", "riserva"],
      inference: "Preparare una riserva può risolvere un imprevisto.", evidence: "Ada prende i bicchieri di riserva dallo zaino."),
    Passage(title: "Un cortile con ombra", subject: "Scienze", who: "Un gruppo di studenti",
      whereWhen: "è nel cortile della scuola, in primavera", event: "Confronta due zone dove sedersi.",
      cause: "Sotto gli alberi arriva meno luce diretta e la panchina si scalda meno.",
      consequence: "Il gruppo sceglie la zona ombreggiata per la lettura.",
      detail: "Una delle panchine ha quattro assi.", keywords: ["cortile", "ombra", "calore"],
      inference: "L'ombra può rendere più comoda una pausa in una giornata calda.", evidence: "Sotto gli alberi arriva meno luce diretta e la panchina si scalda meno."),
    Passage(title: "La fontana del paese", subject: "Storia", who: "Gli abitanti di un paese",
      whereWhen: "si incontravano in piazza, prima dell'acqua corrente nelle case", event: "Portavano recipienti alla fontana.",
      cause: "La fontana permetteva di raccogliere l'acqua per gli usi quotidiani.",
      consequence: "Il luogo diventava anche un punto d'incontro tra vicini.",
      detail: "Accanto alla vasca c'era un gradino di pietra.", keywords: ["fontana", "acqua", "incontro"],
      inference: "Un luogo utile può avere anche una funzione sociale.", evidence: "Il luogo diventava anche un punto d'incontro tra vicini."),
    Passage(title: "Il cartellone chiaro", subject: "Italiano", who: "Milo",
      whereWhen: "è in aula, prima di una presentazione", event: "Prepara un cartellone con molte frasi.",
      cause: "Da lontano le scritte piccole si leggono con fatica.",
      consequence: "Milo lascia tre idee principali e ingrandisce le parole.",
      detail: "Usa un foglio rettangolare.", keywords: ["cartellone", "idee", "leggibilità"],
      inference: "Scegliere le informazioni essenziali può aiutare chi legge.", evidence: "Milo lascia tre idee principali e ingrandisce le parole."),
    Passage(title: "Il sentiero protetto", subject: "Scienze", who: "I visitatori",
      whereWhen: "camminano in una riserva, durante un'escursione", event: "Seguono un sentiero segnato.",
      cause: "Fuori dal percorso crescono piccole piante che possono essere calpestate.",
      consequence: "Restando sul sentiero, i visitatori lasciano spazio alle piante.",
      detail: "Il segnale all'ingresso è di legno.", keywords: ["percorso", "piante", "protezione"],
      inference: "Il percorso segnato aiuta a proteggere la vegetazione.", evidence: "Fuori dal percorso crescono piccole piante che possono essere calpestate."),
    Passage(title: "Il mercato vicino al fiume", subject: "Storia", who: "I mercanti",
      whereWhen: "arrivavano a un mercato fluviale, molti secoli fa", event: "Scaricavano merci dalle barche.",
      cause: "Il fiume consentiva di trasportare carichi tra località collegate dall'acqua.",
      consequence: "Vicino all'approdo si sviluppavano spazi per scambiare i prodotti.",
      detail: "Alcune merci viaggiavano in ceste.", keywords: ["fiume", "trasporto", "mercato"],
      inference: "I collegamenti possono influenzare il luogo di un mercato.", evidence: "Il fiume consentiva di trasportare carichi tra località collegate dall'acqua."),
    Passage(title: "La foto della mostra", subject: "Italiano", who: "Lina",
      whereWhen: "è al centro culturale, la mattina della mostra", event: "Sceglie una foto da esporre.",
      cause: "Poi si accorge che manca il nome dell'autore e prepara un'etichetta.",
      consequence: "Infine appende la foto con l'etichetta accanto.",
      detail: "La cornice è di legno chiaro.", keywords: ["foto", "etichetta", "mostra"],
      inference: "L'etichetta permette di attribuire la foto al suo autore.", evidence: "Poi si accorge che manca il nome dell'autore e prepara un'etichetta."),
    Passage(title: "Il pane in tre momenti", subject: "Scienze", who: "Un impasto",
      whereWhen: "è in cucina, durante la preparazione del pane", event: "Viene preparato mescolando gli ingredienti.",
      cause: "Durante il riposo il lievito produce gas e l'impasto aumenta di volume.",
      consequence: "Infine l'impasto viene cotto in forno da un adulto.",
      detail: "La ciotola ha due piccoli manici.", keywords: ["impasto", "riposo", "cottura"],
      inference: "Il tempo di riposo cambia l'impasto.", evidence: "Durante il riposo il lievito produce gas e l'impasto aumenta di volume."),
    Passage(title: "Il giornalino pronto", subject: "Italiano", who: "La redazione della scuola",
      whereWhen: "è in biblioteca, giovedì", event: "Raccoglie i testi scritti dai compagni.",
      cause: "Poi controlla i titoli perché ogni articolo deve essere riconoscibile.",
      consequence: "Infine impagina e stampa il giornalino.",
      detail: "Il primo numero ha una copertina arancione.", keywords: ["testi", "titoli", "stampa"],
      inference: "Il controllo precede la distribuzione del giornalino.", evidence: "Poi controlla i titoli perché ogni articolo deve essere riconoscibile."),
    Passage(title: "Un reperto al museo", subject: "Storia", who: "Un frammento di ceramica",
      whereWhen: "arriva in un museo, dopo uno scavo", event: "Viene registrato con il luogo del ritrovamento.",
      cause: "Poi viene studiato per capire come poteva essere usato.",
      consequence: "Infine viene esposto con una spiegazione per i visitatori.",
      detail: "La vetrina ha una base grigia.", keywords: ["ritrovamento", "studio", "esposizione"],
      inference: "La spiegazione al pubblico si basa sul lavoro di studio.", evidence: "Poi viene studiato per capire come poteva essere usato."),
    Passage(title: "Il seme osservato", subject: "Scienze", who: "Un seme di fagiolo",
      whereWhen: "è in un vaso, all'inizio della primavera", event: "Assorbe acqua dal terreno umido.",
      cause: "Poi, nelle condizioni adatte, germoglia e compare la radice.",
      consequence: "In seguito il germoglio emerge dal terreno.",
      detail: "Il vaso porta un'etichetta con la data.", keywords: ["seme", "radice", "germoglio"],
      inference: "La crescita si può descrivere come una successione di cambiamenti.", evidence: "Poi, nelle condizioni adatte, germoglia e compare la radice."),
    Passage(title: "Il vetro appannato", subject: "Scienze", who: "Il vapore nell'aria",
      whereWhen: "è vicino a un vetro freddo, in inverno", event: "Entra in contatto con la superficie fredda.",
      cause: "Raffreddandosi, parte del vapore si trasforma in piccole gocce.",
      consequence: "Il vetro appare appannato.",
      detail: "La finestra ha una maniglia scura.", keywords: ["vapore", "freddo", "gocce"],
      inference: "L'appannamento non richiede che piova sulla finestra.", evidence: "Raffreddandosi, parte del vapore si trasforma in piccole gocce."),
    Passage(title: "Il ponte chiuso", subject: "Italiano", who: "I ciclisti del quartiere",
      whereWhen: "arrivano al ponte, una domenica", event: "Trovano una barriera e si fermano.",
      cause: "Il ponte è chiuso perché gli operai stanno sistemando il pavimento.",
      consequence: "I ciclisti seguono il percorso alternativo indicato.",
      detail: "Uno dei ciclisti porta una borraccia rossa.", keywords: ["ponte", "riparazione", "alternativa"],
      inference: "La chiusura cambia il percorso, non necessariamente la destinazione.", evidence: "I ciclisti seguono il percorso alternativo indicato."),
    Passage(title: "Le strade dei Romani", subject: "Storia", who: "Le strade romane",
      whereWhen: "collegavano molti territori, nell'antichità", event: "Permettevano spostamenti tra città distanti.",
      cause: "Una rete di percorsi collegati facilitava il passaggio di persone e merci.",
      consequence: "Le comunicazioni e gli scambi potevano raggiungere più località.",
      detail: "In alcuni tratti restano ancora pietre della pavimentazione.", keywords: ["strade", "collegamenti", "scambi"],
      inference: "Una strada è utile anche per le località che collega.", evidence: "Le comunicazioni e gli scambi potevano raggiungere più località."),
    Passage(title: "La raccolta separata", subject: "Scienze", who: "La classe",
      whereWhen: "è in aula, dopo un laboratorio", event: "Separa i ritagli di carta pulita dagli altri materiali.",
      cause: "Materiali diversi richiedono trattamenti diversi per essere recuperati.",
      consequence: "I ritagli vengono messi nel contenitore indicato per la carta.",
      detail: "Il contenitore è accanto alla porta.", keywords: ["carta", "separazione", "recupero"],
      inference: "Separare con attenzione aiuta il recupero dei materiali.", evidence: "Materiali diversi richiedono trattamenti diversi per essere recuperati."),
    Passage(title: "La sala silenziosa", subject: "Italiano", who: "Il gruppo di lettura",
      whereWhen: "è in una sala comune, nel pomeriggio", event: "Prova a discutere un racconto.",
      cause: "Dalla sala vicina arriva musica che copre alcune parole.",
      consequence: "Il gruppo chiude la porta e riprende la discussione.",
      detail: "Le sedie sono disposte in cerchio.", keywords: ["lettura", "rumore", "porta"],
      inference: "Cambiare l'ambiente può rendere più facile seguire una discussione.", evidence: "Dalla sala vicina arriva musica che copre alcune parole."),
    Passage(title: "Le tracce sulla terra", subject: "Scienze", who: "Due escursionisti",
      whereWhen: "sono su un sentiero, dopo la pioggia", event: "Osservano impronte nella terra morbida.",
      cause: "Un animale è passato mentre il terreno era umido.",
      consequence: "Gli escursionisti fotografano le tracce senza toccarle.",
      detail: "Vicino al sentiero c'è una pietra chiara.", keywords: ["impronte", "terreno", "animale"],
      inference: "L'animale può essere passato anche se adesso non si vede.", evidence: "Osservano impronte nella terra morbida."),
    Passage(title: "Il posto tenuto libero", subject: "Italiano", who: "Sara",
      whereWhen: "è al tavolo del laboratorio, prima dell'incontro", event: "Sposta la propria borsa dalla sedia accanto.",
      cause: "Vede arrivare una compagna che cerca dove sedersi.",
      consequence: "La compagna si siede e le due preparano il materiale.",
      detail: "Sul tavolo c'è un contenitore trasparente.", keywords: ["sedia", "compagna", "accoglienza"],
      inference: "Sara vuole fare spazio alla compagna.", evidence: "Vede arrivare una compagna che cerca dove sedersi."),
    Passage(title: "Le ruote del carro", subject: "Storia", who: "Un carro antico",
      whereWhen: "è raffigurato su un reperto, in un museo", event: "Mostra un pianale carico e due ruote visibili.",
      cause: "Le ruote permettevano di spostare il carico senza portarlo tutto sulle spalle.",
      consequence: "Il visitatore collega la forma del carro al trasporto di merci.",
      detail: "La didascalia è stampata su un piccolo pannello.", keywords: ["carro", "ruote", "carico"],
      inference: "La forma di un oggetto può suggerire il suo uso.", evidence: "Le ruote permettevano di spostare il carico senza portarlo tutto sulle spalle."),
    Passage(title: "Il ghiaccio nella ciotola", subject: "Scienze", who: "Un cubetto di ghiaccio",
      whereWhen: "è in una ciotola, in una stanza calda", event: "Diventa più piccolo mentre sul fondo compare acqua.",
      cause: "Riceve calore dall'ambiente e fonde.",
      consequence: "Dopo un po' nella ciotola resta acqua liquida.",
      detail: "La ciotola è appoggiata su un vassoio.", keywords: ["ghiaccio", "calore", "fusione"],
      inference: "Il materiale non è scomparso: ha cambiato stato.", evidence: "Dopo un po' nella ciotola resta acqua liquida."),
    Passage(title: "La prova generale", subject: "Italiano", who: "Il gruppo teatrale",
      whereWhen: "è sul palco, prima dello spettacolo", event: "Ripete il momento in cui devono entrare tre personaggi.",
      cause: "Alla prima prova due attori erano entrati insieme invece che uno dopo l'altro.",
      consequence: "Il gruppo usa un segnale concordato per rispettare l'ordine.",
      detail: "Una sedia di scena è coperta da un telo.", keywords: ["teatro", "ordine", "segnale"],
      inference: "Il segnale serve a coordinare gli ingressi.", evidence: "Il gruppo usa un segnale concordato per rispettare l'ordine."),
    Passage(title: "L'acqua cambia posto", subject: "Scienze", who: "L'acqua di una pozzanghera",
      whereWhen: "è sull'asfalto, dopo un temporale", event: "Diminuisce durante una giornata soleggiata.",
      cause: "Una parte passa nell'aria come vapore attraverso l'evaporazione.",
      consequence: "La pozzanghera si riduce anche se nessuno raccoglie l'acqua.",
      detail: "Una foglia resta sul bordo bagnato.", keywords: ["acqua", "evaporazione", "aria"],
      inference: "Una diminuzione visibile può dipendere da un passaggio che non vediamo.", evidence: "Una parte passa nell'aria come vapore attraverso l'evaporazione."),
    Passage(title: "Scrivere prima della carta", subject: "Storia", who: "Gli scribi della Mesopotamia",
      whereWhen: "lavoravano nelle città, nell'antichità", event: "Incidevano segni su tavolette d'argilla.",
      cause: "La scrittura permetteva di conservare elenchi e accordi oltre il momento in cui venivano detti.",
      consequence: "Le informazioni potevano essere rilette in seguito.",
      detail: "Alcune tavolette avevano dimensioni ridotte.", keywords: ["scrittura", "argilla", "informazioni"],
      inference: "Un testo scritto può aiutare a ricordare un accordo.", evidence: "Le informazioni potevano essere rilette in seguito."),
    Passage(title: "Le radici trattengono", subject: "Scienze", who: "Le radici delle piante",
      whereWhen: "si sviluppano nel terreno, lungo un pendio", event: "Formano una rete tra le particelle del suolo.",
      cause: "Questa rete contribuisce a trattenere il terreno quando scorre l'acqua.",
      consequence: "La vegetazione può ridurre una parte dell'erosione superficiale.",
      detail: "Sul pendio crescono piante di altezze diverse.", keywords: ["radici", "suolo", "erosione"],
      inference: "La funzione delle radici non si limita all'assorbimento dell'acqua.", evidence: "Questa rete contribuisce a trattenere il terreno quando scorre l'acqua."),
    Passage(title: "Il mulino ad acqua", subject: "Storia", who: "Un mulino ad acqua",
      whereWhen: "si trovava vicino a un corso d'acqua, secoli fa", event: "Usava una ruota mossa dalla corrente.",
      cause: "Il movimento della ruota veniva trasmesso al meccanismo per macinare.",
      consequence: "Il grano poteva essere trasformato in farina sfruttando l'energia dell'acqua.",
      detail: "I sacchi venivano raccolti sotto una tettoia.", keywords: ["corrente", "ruota", "farina"],
      inference: "La posizione del mulino era legata alla fonte di energia.", evidence: "Usava una ruota mossa dalla corrente."),
    Passage(title: "I semi in viaggio", subject: "Scienze", who: "Alcuni semi leggeri",
      whereWhen: "si staccano dalle piante, in una giornata ventosa", event: "Vengono trasportati dall'aria.",
      cause: "Le loro forme aiutano il vento a sostenerli per un tratto.",
      consequence: "Possono arrivare in luoghi diversi da quello della pianta d'origine.",
      detail: "Una parte dei semi si ferma vicino a una recinzione.", keywords: ["semi", "vento", "dispersione"],
      inference: "Il vento può contribuire alla diffusione delle piante.", evidence: "Possono arrivare in luoghi diversi da quello della pianta d'origine."),
    Passage(title: "Le notizie del quartiere", subject: "Italiano", who: "La bacheca del quartiere",
      whereWhen: "è all'ingresso del centro civico, questa settimana", event: "Raccoglie gli orari delle attività.",
      cause: "Alcuni orari sono cambiati e i fogli precedenti potrebbero confondere chi legge.",
      consequence: "Un volontario sostituisce gli avvisi vecchi con quelli aggiornati.",
      detail: "I fogli sono fissati con puntine tonde.", keywords: ["bacheca", "orari", "aggiornamento"],
      inference: "Togliere un'informazione superata è importante quanto aggiungerne una nuova.", evidence: "Alcuni orari sono cambiati e i fogli precedenti potrebbero confondere chi legge."),
    Passage(title: "Una lettera conservata", subject: "Storia", who: "Una lettera del passato",
      whereWhen: "è conservata in un archivio, oggi", event: "Racconta un viaggio dal punto di vista di chi l'ha scritto.",
      cause: "L'autore descrive soltanto ciò che ha visto e scelto di raccontare.",
      consequence: "Chi studia il viaggio confronta la lettera con altre fonti.",
      detail: "La lettera è custodita in una cartella.", keywords: ["lettera", "punto di vista", "fonti"],
      inference: "Una fonte può essere utile senza raccontare tutto.", evidence: "L'autore descrive soltanto ciò che ha visto e scelto di raccontare."),
    Passage(title: "La catena del prato", subject: "Scienze", who: "Un merlo",
      whereWhen: "cerca cibo in un prato, al mattino", event: "Mangia piccoli invertebrati tra l'erba.",
      cause: "Gli organismi del prato dipendono da altre risorse per nutrirsi.",
      consequence: "Il merlo fa parte di una rete di relazioni alimentari.",
      detail: "Il prato si trova vicino a una siepe.", keywords: ["merlo", "cibo", "relazioni"],
      inference: "Studiare un animale può richiedere di osservare anche il suo ambiente.", evidence: "Gli organismi del prato dipendono da altre risorse per nutrirsi."),
    Passage(title: "Il messaggio preciso", subject: "Italiano", who: "Teo",
      whereWhen: "è a casa, prima di incontrare gli amici", event: "Scrive soltanto «ci vediamo dopo».",
      cause: "Gli amici non sanno quale luogo e quale ora scegliere.",
      consequence: "Teo aggiunge il nome della piazza e l'orario dell'incontro.",
      detail: "Il messaggio contiene anche un saluto.", keywords: ["messaggio", "luogo", "ora"],
      inference: "Chi scrive deve considerare le informazioni che il lettore non conosce.", evidence: "Gli amici non sanno quale luogo e quale ora scegliere."),
    Passage(title: "Una mappa del passato", subject: "Storia", who: "Una mappa antica",
      whereWhen: "è osservata in classe, durante una lezione", event: "Mostra mura e porte attorno a una città.",
      cause: "Chi l'ha disegnata voleva rappresentare alcuni elementi utili del luogo.",
      consequence: "La classe confronta la mappa con una pianta attuale per riconoscere i cambiamenti.",
      detail: "La copia della mappa è stampata su un foglio grande.", keywords: ["mappa", "città", "cambiamenti"],
      inference: "Confrontare due rappresentazioni può far emergere differenze nel tempo.", evidence: "La classe confronta la mappa con una pianta attuale per riconoscere i cambiamenti."),
    Passage(title: "Un titolo per il racconto", subject: "Italiano", who: "Iris",
      whereWhen: "è alla fermata, dopo la scuola", event: "Trova una tessera lasciata su una panchina.",
      cause: "Il nome sulla tessera permette di capire a chi appartiene.",
      consequence: "Iris la consegna all'ufficio oggetti trovati, spiegando dove l'ha raccolta.",
      detail: "La panchina è vicina a un cestino.", keywords: ["tessera", "nome", "restituzione"],
      inference: "Iris cerca un modo per far ritrovare la tessera al proprietario.", evidence: "Iris la consegna all'ufficio oggetti trovati, spiegando dove l'ha raccolta."),
    Passage(title: "La stampa dei libri", subject: "Storia", who: "La stampa a caratteri mobili",
      whereWhen: "si diffuse in Europa, dal Quattrocento", event: "Permise di usare e ricomporre caratteri per stampare pagine.",
      cause: "Una stessa composizione poteva produrre molte copie senza riscriverle a mano.",
      consequence: "Nel tempo divenne possibile far circolare un numero maggiore di libri.",
      detail: "Le officine usavano inchiostro e fogli.", keywords: ["caratteri", "copie", "libri"],
      inference: "Un cambiamento tecnico può modificare la circolazione delle informazioni.", evidence: "Una stessa composizione poteva produrre molte copie senza riscriverle a mano."),
    Passage(title: "Il suono attraverso il tavolo", subject: "Scienze", who: "Una vibrazione",
      whereWhen: "attraversa un tavolo, durante una dimostrazione", event: "Si trasmette nel materiale del tavolo.",
      cause: "Il suono può propagarsi nei solidi, oltre che nell'aria.",
      consequence: "Un ascoltatore può percepire un suono trasmesso dal tavolo.",
      detail: "La dimostrazione avviene su un banco di legno.", keywords: ["vibrazione", "suono", "solido"],
      inference: "L'aria non è l'unico mezzo che può trasmettere il suono.", evidence: "Il suono può propagarsi nei solidi, oltre che nell'aria."),
    Passage(title: "Due versioni dello stesso fatto", subject: "Italiano", who: "Due amici",
      whereWhen: "si ritrovano in classe, dopo un'uscita", event: "Raccontano lo stesso viaggio con dettagli diversi.",
      cause: "Uno ha osservato il paesaggio e l'altro ha parlato con la guida.",
      consequence: "Confrontando i racconti, la classe raccoglie informazioni complementari.",
      detail: "I racconti vengono scritti su due fogli.", keywords: ["racconti", "osservazioni", "confronto"],
      inference: "Dettagli diversi non significano per forza che un racconto contraddica l'altro.", evidence: "Uno ha osservato il paesaggio e l'altro ha parlato con la guida."),
    Passage(title: "Acqua per l'orto comune", subject: "Scienze", who: "Il gruppo dell'orto",
      whereWhen: "si incontra vicino alle aiuole, in estate", event: "Confronta il terreno prima di annaffiare.",
      cause: "Alcune zone all'ombra sono ancora umide, altre al sole sono asciutte.",
      consequence: "Il gruppo distribuisce l'acqua dove il terreno ne ha bisogno.",
      detail: "Gli annaffiatoi sono riposti vicino al cancello.", keywords: ["terreno", "umidità", "scelta"],
      inference: "Osservare prima di agire può evitare un uso inutile dell'acqua.", evidence: "Alcune zone all'ombra sono ancora umide, altre al sole sono asciutte.")
  ]
}
