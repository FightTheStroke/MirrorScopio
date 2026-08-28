import Foundation
import Testing
@testable import MirrorScopio

/// Che cosa succede ai dati quando qualcosa va storto.
///
/// Sono le prove del difetto peggiore trovato in questa app: non uno che la fa
/// smettere di funzionare — quelli si vedono — ma uno che **cancellava mesi di
/// allenamento in silenzio**. Se il file dei dati non si riusciva a leggere,
/// l'app ripartiva vuota come al primo giorno e al primo salvataggio ci
/// scriveva sopra. Nessun messaggio, nessuna copia, nessun modo di tornare
/// indietro.
@MainActor
@Suite("I dati salvati non si perdono di nascosto")
struct DatiCheNonSiPerdono {

  /// Una cartella nuova per ogni prova: qui dentro non deve mai finire la
  /// cartella vera, dove c'è il nome di un bambino e ogni suo errore.
  private func cartellaDiProva() -> URL {
    let u = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("mirrorscopio-prova-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }

  @Test("Un file illeggibile non viene sovrascritto")
  func fileRottoNonSiPerde() throws {
    let cartella = cartellaDiProva()
    let learners = cartella.appendingPathComponent("learners.json")
    let spazzatura = Data("questo non e' JSON {{{".utf8)
    try spazzatura.write(to: learners)

    let store = Store(folder: cartella)

    #expect(store.scritturaSospesa, "con un file illeggibile non si deve poter scrivere")
    #expect(store.guastoNeiDati != nil, "e la cosa va detta, non taciuta")

    // Il salvataggio deve essere un nulla di fatto: è la differenza fra
    // perdere la sessione di oggi e perdere quelle di sei mesi.
    store.save()
    // Si legge dal percorso, non dall'URL, come fa `Store`: le funzioni che
    // leggono un URL accettano anche un indirizzo di rete, e il controllo
    // automatico che tiene la rete fuori da questo programma non sa
    // distinguere i due casi guardando il codice. Una prova non è una buona
    // ragione per aprire un'eccezione alla promessa.
    let dopo = FileManager.default.contents(atPath: learners.path)
    #expect(dopo == spazzatura, "il file di partenza deve essere ancora lì, intatto")
  }

  @Test("Del file illeggibile resta una copia")
  func restaUnaCopia() throws {
    let cartella = cartellaDiProva()
    try Data("rotto".utf8).write(to: cartella.appendingPathComponent("history.json"))

    _ = Store(folder: cartella)

    let copie = try FileManager.default
      .contentsOfDirectory(atPath: cartella.path)
      .filter { $0.contains("illeggibile") }
    #expect(copie.count == 1, "una copia con la data, per poterci tornare")
  }

  @Test("Solo una scelta esplicita ricomincia da capo")
  func ricominciareEUnaScelta() throws {
    let cartella = cartellaDiProva()
    let learners = cartella.appendingPathComponent("learners.json")
    try Data("rotto".utf8).write(to: learners)

    let store = Store(folder: cartella)
    #expect(store.scritturaSospesa)

    store.ricominciaDaCapo()
    #expect(!store.scritturaSospesa)
    #expect(store.guastoNeiDati == nil)

    // Adesso, e solo adesso, il file è stato riscritto in forma leggibile.
    let dopo = try #require(FileManager.default.contents(atPath: learners.path))
    #expect((try? JSONDecoder().decode([Learner].self, from: dopo)) != nil)
  }

  @Test("Dati scritti da una versione più recente non si toccano")
  func formatoDalFuturo() throws {
    let cartella = cartellaDiProva()
    try Data("{\"versione\": 99}".utf8)
      .write(to: cartella.appendingPathComponent("formato.json"))

    let store = Store(folder: cartella)
    #expect(store.scritturaSospesa, "un'app vecchia non deve riscrivere dati nuovi")
    #expect(store.guastoNeiDati?.contains("recente") == true)
  }

  @Test("Un file che c'è ma non si può leggere non viene sovrascritto")
  func permessiNegatiNonSonoUnPrimoAvvio() throws {
    // È il caso che il primo tentativo di correzione lasciava aperto: leggere
    // un file protetto dà lo stesso risultato di un file che non c'è, e l'app
    // lo scambiava per un primo avvio. Poi ci scriveva sopra.
    let cartella = cartellaDiProva()
    let learners = cartella.appendingPathComponent("learners.json")
    try Data("{}".utf8).write(to: learners)
    try FileManager.default.setAttributes([.posixPermissions: 0],
                                          ofItemAtPath: learners.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                             ofItemAtPath: learners.path)
    }

    let store = Store(folder: cartella)
    #expect(store.scritturaSospesa, "un file che non si legge è un guasto, non una cartella vuota")

    store.save()
    try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                          ofItemAtPath: learners.path)
    let dopo = FileManager.default.contents(atPath: learners.path)
    #expect(dopo == Data("{}".utf8), "il file doveva restare quello di prima")
  }

  @Test("Senza una copia di sicurezza non si propone di cancellare")
  func senzaCopiaNienteRicomincia() throws {
    let cartella = cartellaDiProva()
    try Data("rotto".utf8).write(to: cartella.appendingPathComponent("learners.json"))
    let store = Store(folder: cartella)
    #expect(store.ricominciareÈPossibile, "la copia c'è, quindi si può scegliere")
  }

  @Test("Dati di una versione più recente non offrono di ricominciare")
  func formatoFuturoNonSiCancella() throws {
    // Qui i file sono sani: proporre "Ricomincia da capo" vorrebbe dire offrire
    // di distruggere dati integri subito dopo aver promesso di non toccarli.
    let cartella = cartellaDiProva()
    try Data("{\"versione\": 99}".utf8)
      .write(to: cartella.appendingPathComponent("formato.json"))
    let store = Store(folder: cartella)
    #expect(store.scritturaSospesa)
    #expect(!store.ricominciareÈPossibile)
  }

  @Test("Il guasto si ridice a ogni salvataggio saltato")
  func nonSiDiceUnaVoltaSola() throws {
    let cartella = cartellaDiProva()
    try Data("rotto".utf8).write(to: cartella.appendingPathComponent("learners.json"))
    let store = Store(folder: cartella)

    store.mettiDaParteIlGuasto()
    #expect(store.guastoNeiDati == nil)

    // Chi ha chiuso l'avviso non deve allenarsi tutto il pomeriggio credendo
    // che il lavoro venga salvato.
    store.save()
    #expect(store.guastoNeiDati != nil, "il salvataggio saltato va ridetto")
    #expect(store.genereDelGuasto == .scrittura)
  }

  @Test("Una cartella vuota resta il primo avvio di sempre")
  func primoAvvioNormale() {
    let store = Store(folder: cartellaDiProva())
    #expect(!store.scritturaSospesa)
    #expect(store.guastoNeiDati == nil)
    #expect(store.learners.count == 1)
  }
}

/// Il file di numeri che finisce sul computer del logopedista.
///
/// Un referto clinico ha un obbligo che un foglio qualsiasi non ha: deve
/// contenere **quello che è successo davvero**. Prima, per non rompere le
/// colonne, l'esportazione sostituiva i punti e virgola con delle virgole
/// dentro le parole: il file si apriva bene e diceva una cosa diversa.
@Suite("Il file di numeri dice la verità")
struct EsportazioneFedele {

  private func riga(parola: String, risposta: String = "") -> String {
    var s = SessionRecord()
    s.items = [ItemRecord(stimulus: parola, response: risposta, correct: true,
                          exposureMs: 100, latencyMs: 200, errorKind: "")]
    return Exporter.csv(s, learner: Learner(name: "Mario"))
  }

  @Test("Il punto e virgola dentro una parola non la cambia")
  func puntoEVirgolaSopravvive() {
    let csv = riga(parola: "ciao;come")
    #expect(csv.contains("\"ciao;come\""), "il testo deve arrivare identico, fra virgolette")
    #expect(!csv.contains("ciao,come"), "e non deve essere stato modificato di nascosto")
  }

  @Test("Le virgolette dentro una parola si raddoppiano")
  func virgoletteRaddoppiate() {
    #expect(riga(parola: "il \"cane\"").contains("\"il \"\"cane\"\"\""))
  }

  @Test("Un a capo dentro una risposta non spezza la riga")
  func aCapoNonSpezza() {
    let csv = riga(parola: "gatto", risposta: "ga\ntto")
    #expect(csv.contains("\"ga\ntto\""), "dentro le virgolette l'a capo è legittimo")
  }

  @Test("Un numero negativo resta un numero")
  func numeriNonSiSporcano() {
    // La protezione dalle formule non deve a sua volta falsificare un dato:
    // -120 fra le latenze è un numero, non una formula.
    #expect(riga(parola: "gatto", risposta: "-120").contains("\"-120\""))
  }

  @Test("Una parola che comincia per uguale non diventa una formula")
  func nienteFormule() {
    // Excel e Numbers eseguono un campo che comincia per = + - @: in una lista
    // di parole scritte da un ragazzo ci finisce di tutto.
    for inizio in ["=", "+", "-", "@"] {
      let csv = riga(parola: "\(inizio)DDE()")
      #expect(csv.contains("\"'\(inizio)DDE()\""), "manca l'apostrofo che la disinnesca")
    }
  }
}
