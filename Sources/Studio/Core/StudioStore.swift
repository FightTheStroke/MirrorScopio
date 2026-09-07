import Foundation
import Combine

@MainActor
final class StudioStore: ObservableObject {
  @Published private(set) var archive = StudioArchive()
  @Published private(set) var error: String?
  @Published private(set) var recovery = false
  @Published private(set) var hasPendingSave = false
  @Published private(set) var staged: StudioArchive?
  @Published var rejectedEdit: String?
  let fileURL: URL
  private let writer: (Data, URL) throws -> Void
  private var pending: StudioArchive?
  private var draftTask: Task<Void, Never>?
  private var stagedData: Data?
  private var configurationError: String?
  var displayArchive: StudioArchive { staged ?? pending ?? archive }

  init(folder: URL? = nil, environment: [String: String]? = nil,
       writer: @escaping (Data, URL) throws -> Void = StudioStore.atomicWrite) {
    let environment = environment ?? (folder == nil ? ProcessInfo.processInfo.environment : [:])
    var base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MirrorScopio", isDirectory: true)
    var invalidFolder = !base.isFileURL
    #if os(macOS)
    if folder == nil, let path = environment["MIRRORSCOPIO_CARTELLA_DATI"] {
      invalidFolder = !path.hasPrefix("/")
      if !invalidFolder { base = URL(fileURLWithPath: path, isDirectory: true) }
    }
    #endif
    let testID = environment["MIRRORSCOPIO_STUDIO_TEST_ID"]
    let identifier = testID.flatMap(UUID.init(uuidString:))
    let name = invalidFolder ? "Studio-Prove-configurazione-non-valida" :
      testID == nil ? "Studio" : "Studio-Prove-\(identifier?.uuidString ?? "identificatore-non-valido")"
    fileURL = base.appendingPathComponent(name, isDirectory: true).appendingPathComponent("studio.json")
    self.writer = writer
    if invalidFolder {
      recovery = true
      configurationError = "La cartella Studio deve avere un percorso locale assoluto. Nessun dato è stato aperto."
      error = configurationError
      return
    }
    if let testID, identifier?.uuidString.caseInsensitiveCompare(testID) != .orderedSame {
      recovery = true
      configurationError = "Identificatore delle prove non valido. Nessun dato personale è stato aperto."
      error = configurationError
      return
    }
    reload()
  }

  nonisolated static func atomicWrite(_ data: Data, _ url: URL) throws {
    try StudioFileStorage.write(data, to: url)
  }

  func reload() {
    guard configurationError == nil else { error = configurationError; return }
    guard !hasPendingSave, staged == nil else { return }
    do {
      do {
        let loaded = try StudioCodec.decode(Self.readFile(fileURL))
        try StudioFileStorage.protectExisting(fileURL)
        archive = loaded
      } catch let failure as CocoaError where failure.code == .fileReadNoSuchFile || failure.code == .fileNoSuchFile {
        archive = StudioArchive()
      }
      recovery = false
      error = nil
    } catch {
      recovery = true
      self.error = "Non posso aprire i dati Studio: \(error.localizedDescription) L'originale resta intatto. Riprova o importa una copia valida."
    }
  }

  nonisolated static func readFile(_ url: URL) throws -> Data {
    try StudioFileStorage.read(url)
  }

  @discardableResult
  func change(_ edit: (inout StudioArchive) throws -> Void) -> Bool {
    guard !recovery, !hasPendingSave else {
      if error == nil { error = "Risolvi prima il problema di salvataggio." }
      return false
    }
    var candidate = staged ?? archive
    do {
      try edit(&candidate)
      let encoded = try StudioCodec.encode(candidate)
      return persist(candidate, encoded: encoded)
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  /// Le battute aggiornano la bozza visibile, non il dato confermato su disco.
  func stage(_ edit: (inout StudioArchive) throws -> Void) {
    guard !recovery, !hasPendingSave else {
      if error == nil { error = "Risolvi prima il problema di salvataggio: il testo non è stato modificato." }
      return
    }
    var candidate = staged ?? archive
    do {
      try edit(&candidate)
      stagedData = try StudioCodec.encode(candidate)
    } catch {
      rejectedEdit = "\(error.localizedDescription) L'ultima modifica non è stata accettata; il testo precedente resta disponibile."
      return
    }
    staged = candidate
    draftTask?.cancel()
    draftTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(400)) }
      catch is CancellationError { return }
      catch { self?.error = error.localizedDescription; return }
      _ = self?.flushStaged()
    }
  }

  @discardableResult
  func flushStaged() -> Bool {
    guard let staged else { return !hasPendingSave }
    return persist(staged, encoded: stagedData)
  }

  private func persist(_ candidate: StudioArchive, encoded: Data? = nil) -> Bool {
    draftTask?.cancel()
    do {
      let data = try encoded ?? StudioCodec.encode(candidate)
      try writer(data, fileURL)
      archive = candidate
      staged = nil
      stagedData = nil
      pending = nil
      hasPendingSave = false
      recovery = false
      error = nil
      return true
    } catch {
      staged = nil
      stagedData = nil
      pending = candidate
      hasPendingSave = true
      self.error = "Non ho salvato: \(error.localizedDescription) I dati precedenti sono intatti; la modifica resta qui per riprovare."
      return false
    }
  }

  func retry() {
    if let pending { _ = persist(pending) }
    else if staged != nil { _ = flushStaged() }
    else { reload() }
  }

  func notePendingPause(at date: Date) {
    guard var candidate = pending, var session = candidate.currentSession else { return }
    session.events.append(StudioSessionEvent(kind: .pause, date: date, activeSeconds: session.activeSeconds))
    candidate.currentSession = session
    pending = candidate
  }

  /// La sostituzione viene chiamata soltanto dopo la conferma esplicita nell'interfaccia.
  @discardableResult
  func replace(with data: Data) -> Bool {
    guard configurationError == nil else { error = configurationError; return false }
    do {
      let candidate = try StudioCodec.decode(data)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        let copy = fileURL.deletingLastPathComponent()
          .appendingPathComponent("prima-del-ripristino-\(UUID().uuidString).json")
        try Self.atomicWrite(Self.readFile(fileURL), copy)
      }
      let wasRecovery = recovery
      if persist(candidate) {
        recovery = false
        return true
      }
      recovery = wasRecovery
      return false
    } catch {
      self.error = "Copia non importata: \(error.localizedDescription)"
      return false
    }
  }

  @discardableResult
  func editLesson(_ id: UUID, _ edit: (inout StudioLesson) -> Void) -> Bool {
    change { archive in
      guard let index = archive.lessons.firstIndex(where: { $0.id == id }) else {
        throw StudioFailure("Questa lezione non è più disponibile.")
      }

      edit(&archive.lessons[index])
    }
  }

  func stageLesson(_ id: UUID, _ edit: (inout StudioLesson) -> Void) {
    stage { archive in
      guard let index = archive.lessons.firstIndex(where: { $0.id == id }) else {
        throw StudioFailure("Questa lezione non è più disponibile.")
      }
      edit(&archive.lessons[index])
    }
  }

  func record(cardID: UUID, text: String, help: StudioHelp, recall: StudioRecall, now: Date) -> Bool {
    change { archive in
      guard let run = archive.reviewRun, run.remaining.first == cardID else {
        throw StudioFailure("Questa domanda non è più quella aperta. La risposta già registrata resta salvata.")
      }
      guard run.revealed else {
        throw StudioFailure("Prova prima con parole tue, poi apri il modello prima dell'autovalutazione.")
      }
      guard let index = archive.cards.firstIndex(where: { $0.id == cardID && $0.approved }) else {
        throw StudioFailure("La domanda deve essere approvata da un adulto.")
      }
      let card = archive.cards[index]
      archive.attempts.append(StudioAttempt(cardID: card.id, lessonID: card.lessonID,
        segmentID: card.segmentID, question: card.question, answer: card.answer,
        text: text, help: help, recall: recall, date: now))
      let next = StudioSchedule.next(stage: card.stage, recall: recall, help: help,
                                    intervals: archive.settings.intervals, now: now)
      archive.cards[index].stage = next.stage
      archive.cards[index].due = next.due
      if archive.reviewRun?.remaining.first == cardID {
        archive.reviewRun?.remaining.removeFirst()
        archive.reviewRun?.text = ""
        archive.reviewRun?.help = .none
        archive.reviewRun?.revealed = false
      }
    }
  }

  func beginReview(lessonID: UUID, now: Date) -> Bool {
    change {
      if let run = $0.reviewRun, !run.remaining.isEmpty {
        guard run.lessonID == lessonID else {
          throw StudioFailure("C'è un ripasso aperto in un'altra lezione. Puoi riprenderlo oppure terminarlo liberamente.")
        }
        return
      }
      let cards = StudioSchedule.due(in: $0, lessonID: lessonID, now: now)
      $0.reviewRun = StudioReviewRun(lessonID: lessonID, remaining: Array(cards.prefix(20).map(\.id)))
    }
  }
}
