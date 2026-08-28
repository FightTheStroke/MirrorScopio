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
    let dopo = try Data(contentsOf: learners)
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
    let dopo = try Data(contentsOf: learners)
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
