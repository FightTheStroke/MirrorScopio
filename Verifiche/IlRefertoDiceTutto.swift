import Foundation
import Testing
@testable import MirrorScopio

/// Il referto dice tutto quello che l'app sa.
///
/// Per quattro versioni il file di numeri ha avuto sette colonne, e tre cose
/// che il motore misurava a ogni turno non uscivano da nessuna parte: se il
/// turno era stato interrotto, a quanti hertz girava lo schermo, se un
/// fotogramma era stato saltato. Erano scritte nel registro su disco e
/// morivano lì.
///
/// Non era un dettaglio da rimandare, ed è la regola di `AGENTS.md` scritta a
/// chiare lettere: **se l'app sa qualcosa, lo dice**. Uno stato conosciuto e
/// taciuto è un difetto anche quando il codice è corretto.
///
/// Il danno concreto: le prove interrotte non entrano nel conto
/// dell'accuratezza — ed è giusto così, un ragazzo non ha sbagliato niente se
/// il Mac si è addormentato — ma senza la colonna chi legge il file conta venti
/// righe, vede «diciassette su diciotto» in testa e non ha modo di capire dove
/// siano finite le altre due. Le due strade che gli restano sono fidarsi o
/// buttare via la sessione, e sono sbagliate tutte e due.
@Suite("Il referto dice tutto quello che l'app sa")
struct IlRefertoDiceTutto {

  func prova(parola: String = "gatto", risposta: String = "gatto",
             giusta: Bool = true, riscaldamento: Bool = false,
             interrotta: Bool = false, motivo: String? = nil,
             hz: Double? = 60, saltato: Bool = false) -> ItemRecord {
    ItemRecord(stimulus: parola, response: risposta, correct: giusta,
               exposureMs: 200, latencyMs: 450, errorKind: "nessuno",
               warmup: riscaldamento, interrotto: interrotta,
               refreshHz: hz, frameSaltato: saltato, motivoInterruzione: motivo)
  }

  func sessione(_ prove: [ItemRecord]) -> SessionRecord {
    var s = SessionRecord()
    s.items = prove
    s.correct = prove.filter { !$0.warmup && !$0.interrotto && $0.correct }.count
    s.total = prove.filter { !$0.warmup && !$0.interrotto }.count
    return s
  }

  func csv(_ prove: [ItemRecord]) -> String {
    Exporter.csv(sessione(prove), learner: Learner(name: "Mario"))
  }

  // MARK: Le tre cose che non uscivano

  @Test("Le colonne che mancavano adesso ci sono")
  func intestazioneCompleta() {
    let testo = csv([prova()])
    for colonna in ["interrotta", "motivo_interruzione", "schermo_hz", "fotogramma_saltato"] {
      #expect(testo.contains(colonna),
        "la colonna «\(colonna)» non esce dal file, e il dato resta chiuso nell'app")
    }
  }

  @Test("Una prova interrotta esce come interrotta, non come sbagliata")
  func interrottaNonEUnErrore() {
    let testo = csv([prova(interrotta: true, motivo: "il Mac si e' addormentato")])
    #expect(testo.contains("non contata"),
      "una prova che nessuno ha chiesto non può comparire come «ancora»: è una cosa falsa su un ragazzo")
    #expect(testo.contains("il Mac si e' addormentato"),
      "senza il motivo, chi legge sa che qualcosa è andato storto ma non che cosa")
  }

  @Test("La frequenza dello schermo esce, perché senza i millesimi non valgono")
  func laFrequenzaEsce() {
    #expect(csv([prova(hz: 120)]).contains("120.0"),
      "a 60 Hz un'esposizione di 30 ms non esiste: senza la frequenza il numero non si può confrontare fra due Mac")
  }

  @Test("Il fotogramma saltato esce")
  func ilFotogrammaSaltatoEsce() {
    let righe = csv([prova(saltato: true)]).split(separator: "\n")
    let riga = righe.last { !$0.hasPrefix("#") && !$0.hasPrefix("parola;") } ?? ""
    #expect(riga.hasSuffix("\"si\""),
      "se la parola è rimasta a schermo più del dovuto, il referto deve dirlo")
  }

  // MARK: I conti in testa devono tornare con le righe sotto

  @Test("La testata spiega perché le righe sono più delle parole contate")
  func lanotaSpiegaIConti() {
    let testo = csv([
      prova(riscaldamento: true),
      prova(interrotta: true, motivo: "microfono staccato"),
      prova(saltato: true),
      prova(),
    ])
    #expect(testo.contains("righe_nel_file;4"))
    #expect(testo.contains("prove_di_riscaldamento;1"))
    #expect(testo.contains("prove_interrotte;1"))
    #expect(testo.contains("fotogrammi_saltati;1"))
    #expect(testo.contains("non sono errori di chi legge"),
      "la nota deve dire a chiare lettere che le prove escluse non sono colpa del ragazzo")
  }

  @Test("Quando non c'è niente da spiegare, la nota non inventa allarmi")
  func nessunAllarmeInutile() {
    let testo = csv([prova(), prova()])
    #expect(testo.contains("tutte le righe di questo file entrano nel conteggio"))
    #expect(!testo.contains("sospetto"),
      "una sessione pulita non deve seminare dubbi che non esistono")
  }

  @Test("Il riscaldamento si riconosce riga per riga")
  func riscaldamentoRiconoscibile() {
    #expect(csv([prova(riscaldamento: true)]).contains("(riscaldamento)"),
      "chi legge la riga deve capire perché non è nel conto senza tornare in testa al file")
  }

  // MARK: Il PDF

  @Test("Il PDF esce e non è vuoto anche con prove interrotte")
  func ilPdfEsce() {
    let dati = Exporter.pdf(sessions: [sessione([
      prova(),
      prova(interrotta: true, motivo: "la finestra e' passata in secondo piano"),
      prova(saltato: true),
    ])], learner: Learner(name: "Mario"), title: "Referto")
    #expect(dati.count > 1000, "il PDF non è stato disegnato")
    #expect(dati.starts(with: Data("%PDF".utf8)), "non è un PDF")
  }

  // MARK: Chi aveva già usato l'app

  @Test("Una prova salvata prima che questi campi esistessero si legge ancora")
  func iDatiVecchiSiLeggono() throws {
    // Scritto a mano nel formato di ieri, non generato dal codice di oggi:
    // un JSON prodotto dall'encoder corrente non potrà mai mancare di un
    // campo corrente, quindi non proverebbe niente.
    let vecchio = #"""
    {"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","stimulus":"gatto","response":"gatto",
     "correct":true,"exposureMs":200,"errorKind":"nessuno"}
    """#
    let i = try JSONDecoder().decode(ItemRecord.self, from: Data(vecchio.utf8))
    #expect(i.stimulus == "gatto")
    #expect(i.interrotto == false)
    #expect(i.motivoInterruzione == nil)
    #expect(i.refreshHz == nil)
    #expect(i.frameSaltato == false)
  }

  @Test("E finisce nel file nuovo senza fingere di sapere quello che non sa")
  func iDatiVecchiNonInventano() {
    let testo = csv([prova(hz: nil)])
    let riga = testo.split(separator: "\n").last { !$0.hasPrefix("#") && !$0.hasPrefix("parola;") } ?? ""
    #expect(!riga.contains("60.0"),
      "una frequenza che non è stata misurata non può diventare 60: sarebbe un numero inventato")
    #expect(riga.hasSuffix("\"\";\"\";\"no\""),
      "il campo deve restare vuoto — motivo assente, hertz assenti, nessun fotogramma saltato")
  }
}
