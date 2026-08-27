import Foundation

/// Liste di stimoli in italiano per il training di lettura, ordinate per difficoltà.
enum StimulusSet: String, CaseIterable, Identifiable, Codable {
  case sillabePiane, sillabeComplesse, bisillabe, trisillabe, quadrisillabe
  case nonParole, gruppiConsonantici, digrammi, frasiBrevi, frasiIntere, numeri, personalizzata

  var id: String { rawValue }

  var label: String {
    switch self {
    case .sillabePiane: "Sillabe piane (CV)"
    case .sillabeComplesse: "Sillabe complesse (CCV / CVC)"
    case .bisillabe: "Parole bisillabe"
    case .trisillabe: "Parole trisillabe"
    case .quadrisillabe: "Parole quadrisillabe"
    case .nonParole: "Non-parole"
    case .gruppiConsonantici: "Parole con gruppi consonantici"
    case .digrammi: "Parole con digrammi (gn gl sc ch gh)"
    case .frasiBrevi: "Frasi brevi"
    case .frasiIntere: "Frasi intere di senso compiuto"
    case .numeri: "Numeri in lettere"
    case .personalizzata: "Lista personalizzata"
    }
  }

  /// Le non-parole non appartengono al vocabolario del riconoscitore: il punteggio
  /// automatico su questa lista è indicativo e va segnalato all'operatore.
  var isReliableForASR: Bool { self != .nonParole }

  var items: [String] {
    switch self {
    case .sillabePiane:
      ["ma", "me", "mi", "mo", "mu", "pa", "pe", "pi", "po", "pu", "ta", "te", "ti", "to", "tu",
       "la", "le", "li", "lo", "lu", "na", "ne", "ni", "no", "nu", "sa", "se", "si", "so", "su",
       "da", "de", "di", "do", "du", "ra", "re", "ri", "ro", "ru", "fa", "fe", "fi", "fo", "fu",
       "va", "ve", "vi", "vo", "vu", "ba", "be", "bi", "bo", "bu", "ca", "co", "cu", "ga", "go", "gu"]
    case .sillabeComplesse:
      ["bra", "bre", "bri", "bro", "bru", "cra", "cre", "cri", "cro", "cru",
       "dra", "dre", "dri", "dro", "dru", "fra", "fre", "fri", "fro", "fru",
       "gla", "gle", "gli", "glo", "glu", "pla", "ple", "pli", "plo", "plu",
       "tra", "tre", "tri", "tro", "tru", "bar", "ber", "bir", "bor", "bur",
       "cal", "col", "cul", "mar", "mer", "mor", "pas", "pes", "pos", "tan", "ten", "tin", "ton"]
    case .bisillabe:
      ["cane", "gatto", "luna", "mare", "sole", "pane", "vino", "rosa", "casa", "pera",
       "topo", "nave", "dito", "muro", "riso", "sale", "pila", "fico", "gola", "mano",
       "naso", "bocca", "testa", "zampa", "penna", "libro", "porta", "sedia", "tazza",
       "vetro", "ferro", "letto", "lupo", "pesce", "fiore", "fumo", "gioco", "piede", "ruota"]
    case .trisillabe:
      ["tavolo", "banana", "cavallo", "bambino", "farfalla", "montagna", "telefono", "bicchiere",
       "matita", "finestra", "giardino", "macchina", "gelato", "formica", "medusa", "balena",
       "cannuccia", "coperta", "gomitolo", "lucertola", "panino", "semaforo", "tartaruga",
       "vulcano", "capello", "zucchero", "pallone", "cartella", "quaderno", "scarpone"]
    case .quadrisillabe:
      ["elicottero", "frigorifero", "televisione", "automobile", "calcolatrice", "biblioteca",
       "temperatura", "dinosauro", "apparecchio", "mongolfiera", "interruttore", "ombrellone",
       "pappagallo", "periscopio", "stetoscopio", "supermercato", "termosifone", "ventilatore",
       "zanzariera"]
    case .nonParole:
      ["lamo", "fide", "peca", "rino", "tulo", "bame", "zeti", "nofa", "suri", "gepa",
       "trima", "clofe", "brasu", "spide", "glaru", "dranto", "plesta", "scarfo", "strimo",
       "sbulda", "farindolo", "mepatico", "tresolina", "cabulente", "fistrando", "zapruco"]
    case .gruppiConsonantici:
      ["stralcio", "scherzo", "sbaglio", "strada", "sgabello", "splendore", "trattore",
       "crampo", "branco", "proprio", "frangia", "glicine", "platano", "dromedario",
       "astronave", "costruzione", "tempesta", "transito", "instabile", "perplesso"]
    case .digrammi:
      ["gnomo", "ragno", "legna", "cigno", "montagna", "bagno", "foglia", "aglio",
       "famiglia", "coniglio", "meglio", "sbaglio", "scena", "pesce", "uscita", "ruscello",
       "sciarpa", "prosciutto", "chiave", "chiodo", "occhio", "ricchezza", "macchia",
       "ghiaccio", "ghirlanda", "lunghezza", "spaghetti", "funghi"]
    case .frasiBrevi:
      ["il cane corre", "la luna è alta", "apri la porta", "bevo il latte",
       "il sole scalda", "corro nel prato", "mangio una mela", "chiudi la finestra",
       "il treno parte", "piove sul tetto", "porta il libro", "la neve cade",
       "il gatto dorme", "salta il muro", "conta fino a dieci"]
    case .frasiIntere:
      // Frasi vere, non esercizi: hanno un senso che si può tenere a mente
      // mentre si scrive. È quello a rendere il compito diverso da una fila di
      // parole — bisogna reggere il significato e l'ortografia insieme.
      ["il gatto dorme sul divano rosso",
       "domani andiamo al mare con la nonna",
       "ho dimenticato il quaderno di matematica a casa",
       "la maestra ci ha letto una storia bellissima",
       "quando piove preferisco restare a leggere",
       "mio fratello gioca a pallone nel cortile",
       "abbiamo mangiato gli spaghetti al pomodoro",
       "il treno per Bologna parte alle sette",
       "ho visto un ragno enorme sulla finestra",
       "la bicicletta nuova è appoggiata al muro",
       "gli alberi del giardino sono pieni di foglie",
       "non riesco a trovare le chiavi di casa",
       "ci siamo divertiti moltissimo alla festa",
       "il cane della vicina abbaia tutta la notte",
       "questa estate ho imparato a nuotare",
       "la pioggia ha bagnato tutti i banchi",
       "vorrei un gelato al cioccolato e alla panna",
       "il maestro ha spiegato una cosa difficile",
       "sabato mattina andiamo in biblioteca",
       "le montagne sono coperte di neve fresca"]
    case .numeri:
      ["quattro", "sette", "dodici", "diciannove", "ventitré", "trentuno", "quarantasei",
       "cinquantotto", "sessantaquattro", "settantanove", "ottantacinque", "novantadue"]
    case .personalizzata:
      []
    }
  }
}
