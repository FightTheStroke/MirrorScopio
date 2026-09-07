import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

extension StudioCoreTests {
  @Test("Una modifica oltre il limite viene rifiutata e la bozza precedente resta salvabile")
  func invalidDraftDoesNotReplaceValidText() throws {
    try temporary { directory in
      let store = StudioStore(folder: directory)
      store.stage { $0.draft.title = "Titolo da conservare" }
      store.stage { $0.draft.title = String(repeating: "a", count: 201) }
      #expect(store.rejectedEdit != nil)
      #expect(store.displayArchive.draft.title == "Titolo da conservare")
      #expect(store.flushStaged())
      #expect(StudioStore(folder: directory).archive.draft.title == "Titolo da conservare")
      store.stage { $0.draft.title = "Titolo corretto" }
      #expect(store.flushStaged())
      #expect(StudioStore(folder: directory).archive.draft.title == "Titolo corretto")
    }
  }

  @Test("La bozza rifiuta anche il limite complessivo prima di accettare una modifica")
  func oversizedDraftDoesNotTrapTheStore() throws {
    try temporary { directory in
      let store = StudioStore(folder: directory)
      #expect(store.change { $0.draft.title = "Archivio da conservare" })
      let source = String(repeating: "a", count: StudioLimits.text)
      let lessons = try (0..<100).map {
        try StudioLesson(title: "Lezione \($0)", subject: "", source: source)
      }
      store.stage { $0.lessons = lessons }
      #expect(store.rejectedEdit != nil)
      #expect(store.displayArchive.lessons.isEmpty)
      #expect(store.flushStaged())
      #expect(StudioStore(folder: directory).archive.draft.title == "Archivio da conservare")
    }
  }

  @Test("Archivio e copie precedenti mantengono permessi privati ed esclusione dai backup")
  func privateStorage() throws {
    try temporary { directory in
      let store = StudioStore(folder: directory)
      #expect(store.change { $0.draft.title = "Un esempio locale" })
      #expect(store.change { $0.draft.title = "Esempio aggiornato" })
      let before = try StudioStore.readFile(store.fileURL)
      #expect(try store.replace(with: StudioCodec.encode(StudioArchive())))
      let folder = store.fileURL.deletingLastPathComponent()
      let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
      let copy = try #require(names.first { $0.hasPrefix("prima-del-ripristino-") })
      #expect(try StudioStore.readFile(folder.appendingPathComponent(copy)) == before)
      let folderAttributes = try FileManager.default.attributesOfItem(atPath: folder.path)
      #expect((folderAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
      for name in ["studio.json", copy] {
        let url = folder.appendingPathComponent(name)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #if os(iOS) && !targetEnvironment(simulator)
        let protection = (attributes[.protectionKey] as? FileProtectionType)?.rawValue
          ?? (attributes[.protectionKey] as? String)
        #expect(protection == FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
        #endif
      }
      #expect(!names.contains { $0.hasPrefix(".scrittura-") })
      #expect(StudioStore(folder: directory).error == nil)
    }
  }

  @Test("La sostituzione atomica fallita lascia intatta la destinazione e pulisce il temporaneo")
  func atomicReplacementFailure() throws {
    try temporary { directory in
      let destination = directory.appendingPathComponent("destinazione", isDirectory: true)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
      let sentinel = destination.appendingPathComponent("da-conservare.txt")
      let original = Data("Esempio da conservare".utf8)
      try original.write(to: sentinel)
      #expect(throws: (any Error).self) { try StudioStore.atomicWrite(Data("Altri dati".utf8), destination) }
      #expect(try StudioStore.readFile(sentinel) == original)
      let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      #expect(!names.contains { $0.hasPrefix(".scrittura-") })
    }
  }

  @Test("Le prove usano Studio-Prove-UUID al posto di Studio, senza leggere né modificare l'originale")
  func isolatedStorage() throws {
    try temporary { directory in
      let original = StudioStore(folder: directory)
      #expect(original.change { $0.draft.title = "Archivio sintetico da preservare" })
      let before = try StudioStore.readFile(original.fileURL)
      let identifier = UUID().uuidString
      let environment = ["MIRRORSCOPIO_STUDIO_TEST_ID": identifier]
      let isolated = StudioStore(folder: directory, environment: environment)
      #expect(isolated.fileURL == directory.appendingPathComponent("Studio-Prove-\(identifier)/studio.json"))
      #expect(isolated.archive.draft.title.isEmpty)
      #expect(isolated.change { $0.draft.title = "Solo una prova" })
      #expect(StudioStore(folder: directory, environment: environment).archive.draft.title == "Solo una prova")
      #expect(try StudioStore.readFile(original.fileURL) == before)
      let backup = try StudioCodec.encode(StudioArchive())
      for invalid in ["", "../Studio", identifier + " "] {
        let rejected = StudioStore(folder: directory, environment: ["MIRRORSCOPIO_STUDIO_TEST_ID": invalid])
        #expect(rejected.recovery && rejected.error != nil)
        #expect(!rejected.change { $0.draft.title = "Non scrivere" })
        rejected.retry()
        #expect(rejected.recovery)
        #expect(!rejected.replace(with: backup))
        #expect(!FileManager.default.fileExists(atPath: rejected.fileURL.path))
      }
      #expect(try StudioStore.readFile(original.fileURL) == before)
    }
  }

  #if os(macOS)
  @Test("Su Mac la cartella esplicita resta locale e può contenere una prova isolata")
  func macFolderOverride() throws {
    try temporary { directory in
      let identifier = UUID().uuidString
      let store = StudioStore(environment: [
        "MIRRORSCOPIO_CARTELLA_DATI": directory.path,
        "MIRRORSCOPIO_STUDIO_TEST_ID": identifier
      ])
      #expect(store.fileURL == directory.appendingPathComponent("Studio-Prove-\(identifier)/studio.json"))
      #expect(store.change { $0.draft.title = "Prova locale" })
      #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
  }
  #endif

  @Test("Lettura locale a blocchi: byte integri, limite esplicito e rifiuto di cartelle")
  func boundedFileRead() throws {
    try temporary { directory in
      let url = directory.appendingPathComponent("pagina.txt")
      let bytes = Data(repeating: 195, count: 140_000)
      try bytes.write(to: url)
      #expect(try StudioStore.readFile(url) == bytes)
      #expect(throws: StudioFailure.self) { try StudioStore.readFile(directory) }
      try Data(repeating: 32, count: StudioLimits.fileBytes + 1).write(to: url)
      #expect(throws: StudioFailure.self) { try StudioStore.readFile(url) }
    }
  }

  @Test("Solo tempo attivo osservato, pausa e rilancio esclusi; nessuna attribuzione clinica")
  func activeTimeAndReport() throws {
    try temporary { directory in
      var uptime = 100.0
      let now = Date(timeIntervalSince1970: 1_700_000_000)
      let store = StudioStore(folder: directory)
      let lesson = try lesson()
      #expect(store.change { $0.lessons = [lesson] })
      let tracker = StudioSessionTracker(store: store, uptime: { uptime }, now: { now })
      #expect(tracker.start(lessonID: lesson.id))
      uptime += 10
      tracker.pause()
      uptime += 3_000
      #expect(store.archive.currentSession?.activeSeconds == 10)
      #expect(tracker.resume())
      uptime += 5
      tracker.checkpoint()
      let reopened = StudioStore(folder: directory)
      let relaunched = StudioSessionTracker(store: reopened, uptime: { uptime }, now: { now })
      #expect(!relaunched.active)
      #expect(reopened.archive.currentSession?.activeSeconds == 15)
      #expect(relaunched.finish(.interrupted))
      let session = try #require(reopened.archive.sessions.first)
      #expect(session.activeSeconds == 15 && session.outcome == .interrupted)
      #expect(session.events.map(\.kind) == [.start, .pause, .resume, .finish])
      let report = String(decoding: StudioReport.csv(reopened.archive), as: UTF8.self)
      #expect(report.contains("non è una valutazione clinica"))
      #expect(report.contains("Tempo e tocchi non misurano la comprensione"))
      #expect(!report.contains("%") && !report.contains("QI"))
      #expect(StudioReport.summary(reopened.archive).contains("autovalutazioni"))
    }
  }
}
