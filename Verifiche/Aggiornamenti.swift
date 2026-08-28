import Testing
@testable import MirrorScopioCore

/// Il confronto fra due numeri di versione.
///
/// Sembra la cosa piu' innocua dell'app, ed e' invece quella che decide se chi
/// usa MirrorScopio viene a sapere che esiste una versione nuova. Se sbaglia in
/// un verso, l'app annuncia per sempre un aggiornamento che non esiste; se
/// sbaglia nell'altro, resta zitta per sempre. Il secondo caso e' peggiore:
/// nessuno se ne accorge, perche' un'app che tace sembra un'app aggiornata.
///
/// Il caso che rompe tutti i confronti scritti di fretta e' `0.10.0` contro
/// `0.9.0`: come testo «0.10.0» viene prima, come versione viene dopo. E' un
/// difetto che non si vede finche' non si arriva alla decima versione, cioe'
/// mesi dopo averlo scritto, quando nessuno lo sta piu' cercando.
@Suite("Il confronto fra versioni")
struct ConfrontoVersioni {

  @Test("Una versione piu' alta e' piu' nuova")
  func piuAlta() {
    #expect(Updates.isNewer("0.5.0", than: "0.4.0"))
    #expect(Updates.isNewer("1.0.0", than: "0.9.9"))
    #expect(Updates.isNewer("0.4.1", than: "0.4.0"))
  }

  @Test("Dieci viene dopo nove, non prima")
  func dieciDopoNove() {
    #expect(Updates.isNewer("0.10.0", than: "0.9.0"))
    #expect(Updates.isNewer("0.4.10", than: "0.4.9"))
    #expect(Updates.isNewer("10.0.0", than: "9.0.0"))
    #expect(!Updates.isNewer("0.9.0", than: "0.10.0"),
      "confrontate come testo «0.9.0» sembrerebbe piu' nuova: qui l'app annuncerebbe un aggiornamento all'indietro")
  }

  @Test("La stessa versione non e' un aggiornamento")
  func stessaVersione() {
    #expect(!Updates.isNewer("0.4.0", than: "0.4.0"),
      "chi e' gia' aggiornato non deve vedere nessun avviso")
    #expect(!Updates.isNewer("1.2.3", than: "1.2.3"))
  }

  @Test("Una versione piu' bassa non e' un aggiornamento")
  func piuBassa() {
    #expect(!Updates.isNewer("0.3.0", than: "0.4.0"))
    #expect(!Updates.isNewer("0.9.9", than: "1.0.0"))
  }

  @Test("I pezzi che mancano valgono zero")
  func pezziMancanti() {
    // Le release sono state chiamate a volte «0.4» e a volte «0.4.0»: le due
    // scritture devono voler dire la stessa cosa, o l'app annuncerebbe un
    // aggiornamento ogni volta che qualcuno abbrevia il numero.
    #expect(!Updates.isNewer("0.4", than: "0.4.0"))
    #expect(!Updates.isNewer("0.4.0", than: "0.4"))
    #expect(Updates.isNewer("0.4.1", than: "0.4"))
    #expect(Updates.isNewer("1", than: "0.9.9"))
  }

  @Test("I suffissi tipo «-beta» non fanno saltare il confronto")
  func suffissi() {
    // Oggi il pezzo dopo il trattino viene ignorato: «0.5.0-beta» conta come
    // «0.5.0». Non e' il comportamento di semver, dove una beta viene prima
    // della versione finale — ma e' scritto qui perche' sia una scelta
    // dichiarata e non una sorpresa. Se un giorno pubblicheremo davvero delle
    // beta, questo test e' il posto dove la scelta va cambiata apposta.
    #expect(Updates.isNewer("0.5.0-beta", than: "0.4.0"))
    #expect(!Updates.isNewer("0.5.0-beta", than: "0.5.0"))
    #expect(!Updates.isNewer("0.4.0-rc1", than: "0.5.0"))
  }

  @Test("Una risposta senza numeri non annuncia niente")
  func spazzatura() {
    // Se GitHub rispondesse con un tag strano, il peggio che puo' succedere e'
    // che l'app non dica niente. Non deve mai annunciare un aggiornamento che
    // non sa dove porta.
    #expect(!Updates.isNewer("", than: "0.4.0"))
    #expect(!Updates.isNewer("boh", than: "0.4.0"))
    #expect(!Updates.isNewer("latest", than: "0.4.0"))
  }
}
