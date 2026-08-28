import Foundation
import CoreAudio
import AVFoundation

/// Elenco e scelta dei dispositivi audio del Mac.
///
/// Esiste perché "non mi sente" quasi sempre non è un problema di riconoscimento
/// vocale: è il microfono sbagliato selezionato, o un ingresso muto. Senza poterlo
/// vedere e cambiare dall'app, non c'è modo di accorgersene.
struct AudioDevice: Identifiable, Hashable {
  let id: AudioDeviceID
  let name: String
  let uid: String
}

enum AudioDevices {

  // MARK: - Elenchi

  static func inputs() -> [AudioDevice] { all().filter { channels($0.id, input: true) > 0 } }
  static func outputs() -> [AudioDevice] { all().filter { channels($0.id, input: false) > 0 } }

  static func all() -> [AudioDevice] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)

    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size) == noErr else { return [] }
    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var ids = [AudioDeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                     &address, 0, nil, &size, &ids) == noErr else { return [] }

    return ids.compactMap { id in
      guard let name = string(id, kAudioObjectPropertyName) else { return nil }
      return AudioDevice(id: id, name: name, uid: string(id, kAudioDevicePropertyDeviceUID) ?? "")
    }
  }

  // MARK: - Predefiniti di sistema

  static func defaultInput() -> AudioDeviceID? { defaultDevice(kAudioHardwarePropertyDefaultInputDevice) }
  static func defaultOutput() -> AudioDeviceID? { defaultDevice(kAudioHardwarePropertyDefaultOutputDevice) }

  static func currentInputName() -> String? { defaultInput().flatMap { string($0, kAudioObjectPropertyName) } }
  static func currentOutputName() -> String? { defaultOutput().flatMap { string($0, kAudioObjectPropertyName) } }

  private static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(mSelector: selector,
                                             mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                     &address, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
    return id
  }

  /// Cambia l'ingresso predefinito del sistema.
  ///
  /// È la via lunga ma l'unica che funziona: cambiare il dispositivo
  /// direttamente sull'unità audio del motore la lascia viva ma muta — provato,
  /// consegna zero buffer.
  @discardableResult
  static func setDefaultInput(_ device: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                             mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    var id = device
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                      UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
  }

  /// Cambia l'uscita predefinita del sistema. Usata solo dalla sonda di
  /// verifica, che la ripristina subito dopo: l'app non tocca mai le
  /// impostazioni audio del Mac.
  @discardableResult
  static func setDefaultOutput(_ device: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                             mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    var id = device
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                      UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
  }

  // MARK: - Scelta del dispositivo per un motore audio

  /// Dice al motore audio da quale altoparlante uscire.
  @discardableResult
  static func setOutput(_ device: AudioDeviceID, on engine: AVAudioEngine) -> Bool {
    guard let unit = engine.outputNode.audioUnit else { return false }
    var id = device
    return AudioUnitSetProperty(unit,
                                kAudioOutputUnitProperty_CurrentDevice,
                                kAudioUnitScope_Global, 0,
                                &id, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr
  }

  // MARK: - Volume, per accorgersi di un'uscita a zero

  /// Volume dell'uscita, da 0 a 1. Nil quando il dispositivo non lo espone.
  static func outputVolume(_ device: AudioDeviceID) -> Float? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain)
    var value: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    guard AudioObjectHasProperty(device, &address),
          AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
    return value
  }

  static func isOutputMuted(_ device: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                             mScope: kAudioDevicePropertyScopeOutput,
                                             mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectHasProperty(device, &address),
          AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
    return value == 1
  }

  // MARK: - Utilità

  private static func channels(_ device: AudioDeviceID, input: Bool) -> Int {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain)

    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else { return 0 }

    let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return list.reduce(0) { $0 + Int($1.mNumberChannels) }
  }

  private static func string(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
    var address = AudioObjectPropertyAddress(mSelector: selector,
                                             mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    // CoreAudio scrive qui un riferimento a un oggetto, e passargli
    // direttamente l'indirizzo di una variabile `CFString` fa saltare le
    // regole di gestione della memoria di Swift: il compilatore lo segnala, e
    // ha ragione — nei casi peggiori si legge un oggetto gia liberato.
    // Passiamo un blocco di memoria grezza e prendiamo possesso del
    // riferimento una volta sola, esplicitamente.
    var size = UInt32(MemoryLayout<CFString?>.size)
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                  alignment: MemoryLayout<CFString?>.alignment)
    defer { buffer.deallocate() }
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else {
      return nil
    }
    guard let grezzo = buffer.load(as: UnsafeRawPointer?.self) else { return nil }
    // CoreAudio consegna la stringa gia trattenuta per noi (regola *Create*):
    // va rilasciata una volta sola, ed e questo che dice `takeRetainedValue`.
    // Con un semplice `load(as: CFString?.self)` quel conteggio restava
    // sbilanciato e ogni lettura perdeva un pezzo di memoria — e qui si legge
    // ogni tre secondi, per ogni dispositivo audio collegato.
    return Unmanaged<CFString>.fromOpaque(grezzo).takeRetainedValue() as String
  }
}

/// Tiene d'occhio il microfono mentre la sessione è in corso.
///
/// Staccare le cuffie a metà allenamento è normalissimo. Quello che non va
/// bene è che l'app continui a mostrare parole a un ragazzo che parla in un
/// microfono che non c'è più: le sue risposte finiscono nei dati come
/// "nessuna risposta", cioè come se non avesse letto. Il Mac lo sa subito che
/// il dispositivo è sparito, quindi lo si chiede al Mac.
@MainActor
final class SorveglianzaMicrofono {

  /// Chiamata quando il microfono su cui si stava ascoltando non c'è più.
  var suMicrofonoSparito: (() -> Void)?

  private var sorvegliato: AudioDeviceID?
  private var attiva = false
  private var indirizzo = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)

  /// Il blocco che CoreAudio richiama: arriva su una coda sua, quindi si
  /// rimbalza sul thread principale prima di toccare qualunque cosa.
  private lazy var ascoltatore: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
    Task { @MainActor in self?.controlla() }
  }

  func inizia(su dispositivo: AudioDeviceID?) {
    fermati()
    sorvegliato = dispositivo ?? AudioDevices.defaultInput()
    guard sorvegliato != nil else { return }
    let esito = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &indirizzo, .main, ascoltatore)
    attiva = esito == noErr
    if !attiva {
      // Non si può fallire in silenzio: senza questa sorveglianza un microfono
      // staccato diventa una fila di risposte mancate nel referto di un
      // bambino, e nessuno saprebbe perché.
      Log.warn("Non riesco a sorvegliare i dispositivi audio (errore \(esito)): un microfono staccato non verrà segnalato.")
    }
  }

  func fermati() {
    guard attiva else { return }
    AudioObjectRemovePropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &indirizzo, .main, ascoltatore)
    attiva = false
    sorvegliato = nil
  }

  private func controlla() {
    guard attiva, let atteso = sorvegliato else { return }
    let presenti = AudioDevices.inputs().map(\.id)
    guard !presenti.contains(atteso) else { return }
    fermati()
    suMicrofonoSparito?()
  }

  deinit { }
}
