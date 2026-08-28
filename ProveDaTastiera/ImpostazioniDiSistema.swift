import Foundation

/// Le due o tre cose che dipendono da come è messo il Mac, non dall'applicazione.
enum Accessibilita {

  /// Il Mac permette davvero di raggiungere tutti i comandi con il tasto Tab?
  ///
  /// Su macOS è un'impostazione di sistema («Navigazione da tastiera»): finché
  /// è spenta, Tab salta da un campo di testo all'altro e ignora i pulsanti.
  /// Nessuna applicazione può accenderla da sola, quindi una prova che la
  /// ignorasse racconterebbe una bugia in un verso o nell'altro: direbbe «non
  /// si naviga» quando invece si naviga, o passerebbe senza aver provato
  /// niente. La macchina che esegue le prove a ogni push la accende apposta.
  static var navigazioneDaTastieraAttiva: Bool {
    let globale = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
    let modo = (globale?["AppleKeyboardUIMode"] as? NSNumber)?.intValue ?? 0
    // Il bit 2 è «tutti i comandi», non solo i campi di testo.
    return modo & 2 != 0
  }
}
