import Foundation

enum StudioCodec {
  static func encode(_ archive: StudioArchive) throws -> Data {
    try validate(archive)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(archive)
    guard data.count <= StudioLimits.fileBytes else {
      throw StudioFailure("Archivio oltre 20 MB: esporta i dati e rimuovi le lezioni che non servono.")
    }
    return data
  }

  static func decode(_ data: Data) throws -> StudioArchive {
    guard data.count <= StudioLimits.fileBytes else { throw StudioFailure("Il backup supera 20 MB.") }
    struct Header: Decodable { let version: Int }
    let decoder = JSONDecoder()
    let header = try decoder.decode(Header.self, from: data)
    guard header.version == 1 else {
      throw StudioFailure("Formato Studio non supportato (versione \(header.version)). Il file non è stato modificato.")
    }
    let archive = try decoder.decode(StudioArchive.self, from: data)
    try validate(archive)
    return archive
  }

  static func validate(_ archive: StudioArchive) throws {
    try StudioPathEngine.validate(archive)
    try StudioProgramEngine.validate(archive)
    func require(_ condition: Bool, _ message: String) throws {
      if !condition { throw StudioFailure(message) }
    }
    func unique<T: Identifiable>(_ items: [T]) -> Bool where T.ID: Hashable {
      Set(items.map(\.id)).count == items.count
    }
    func bounded(_ text: String, _ max: Int, required: Bool = false) -> Bool {
      text.count <= max && (!required || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    func validDate(_ date: Date) -> Bool {
      (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
    }
    try require(archive.version == 1, "Formato Studio non supportato.")
    try require(archive.lessons.count <= StudioLimits.lessons && unique(archive.lessons),
                "Massimo 100 lezioni, senza identificatori duplicati.")
    try require(archive.cards.count <= StudioLimits.cards && unique(archive.cards),
                "Massimo 2.000 carte, senza identificatori duplicati.")
    try require(archive.attempts.count <= StudioLimits.records && unique(archive.attempts)
                && archive.sessions.count <= StudioLimits.records && unique(archive.sessions),
                "Troppi resoconti (massimo 20.000), oppure identificatori duplicati.")
    let lessons = Dictionary(uniqueKeysWithValues: archive.lessons.map { ($0.id, $0) })
    let allSegments = archive.lessons.flatMap(\.segments)
    try require(unique(allSegments), "Identificatori di segmenti duplicati.")
    for lesson in archive.lessons {
      try require(bounded(lesson.title, 200, required: true) && bounded(lesson.subject, 100),
                  "Titolo obbligatorio (200 caratteri); materia fino a 100 caratteri.")
      try require(validDate(lesson.createdAt), "Data della lezione non valida.")
      try require(bounded(lesson.source, StudioLimits.text, required: true)
                  && !lesson.segments.isEmpty && lesson.segments.count <= StudioLimits.text
                  && lesson.segments.allSatisfy { !$0.text.isEmpty && $0.text.count <= StudioLimits.segment }
                  && lesson.segments.map(\.text).joined() == lesson.source,
                  "Testo e segmenti non corrispondono, oppure superano i limiti.")
      try require(lesson.segments.indices.contains(lesson.position), "Posizione della lezione non valida.")
      try require(lesson.map.ideas.count == 3 && lesson.map.ideas.allSatisfy { bounded($0, 2_000) }
                  && bounded(lesson.map.connection, 5_000), "La mappa richiede tre idee, fino a 2.000 caratteri ciascuna.")
      try require(lesson.procedures.count <= 50 && unique(lesson.procedures)
                  && lesson.procedures.allSatisfy { bounded($0.text, 2_000) }, "Massimo 50 passi da 2.000 caratteri.")
    }
    func validReference(_ lessonID: UUID, _ segmentID: UUID) -> Bool {
      lessons[lessonID]?.segments.contains { $0.id == segmentID } == true
    }
    let cards = Dictionary(uniqueKeysWithValues: archive.cards.map { ($0.id, $0) })
    for card in archive.cards {
      try require(validReference(card.lessonID, card.segmentID)
                  && bounded(card.question, 2_000, required: card.approved)
                  && bounded(card.answer, 5_000, required: card.approved)
                  && (0..<5).contains(card.stage) && validDate(card.due),
                  "Carta non valida: controlla domanda, risposta, fonte e data.")
    }
    for attempt in archive.attempts {
      let card = cards[attempt.cardID]
      try require(card?.lessonID == attempt.lessonID && card?.segmentID == attempt.segmentID
                  && validReference(attempt.lessonID, attempt.segmentID)
                  && bounded(attempt.question, 2_000, required: true) && bounded(attempt.answer, 5_000, required: true)
                  && bounded(attempt.text, 5_000) && validDate(attempt.date),
                  "Tentativo senza carta o fonte valida, oppure testo troppo lungo.")
    }
    let sessions = archive.sessions + (archive.currentSession.map { [$0] } ?? [])
    try require(unique(sessions), "Identificatori di sessioni duplicati.")
    for session in sessions {
      try require(lessons[session.lessonID] != nil && session.activeSeconds.isFinite && session.activeSeconds >= 0
                  && session.activeSeconds <= Double(Int.max / (StudioLimits.records + 1))
                  && (session.fatigue == nil || (1...5).contains(session.fatigue!))
                  && bounded(session.adultHelp, 2_000) && session.events.count <= 10_000,
                  "Resoconto non valido: controlla lezione, durata, fatica, aiuti o numero di eventi.")
      try require(validDate(session.startedAt)
                  && session.events.allSatisfy { validDate($0.date)
                    && $0.activeSeconds.isFinite && $0.activeSeconds >= 0
                    && $0.activeSeconds <= session.activeSeconds },
                  "Date o tempi attivi non validi.")
      if let ended = session.endedAt {
        try require(validDate(ended) && ended >= session.startedAt, "Fine sessione non valida.")
      }
    }
    try require(archive.sessions.allSatisfy { $0.outcome != .ongoing && $0.endedAt != nil }
                && (archive.currentSession == nil || (archive.currentSession?.outcome == .ongoing
                  && archive.currentSession?.endedAt == nil)), "Stato della sessione non valido.")
    let settings = archive.settings
    try require(settings.rate.isFinite && (0.2...0.6).contains(settings.rate) && bounded(settings.voiceID, 500)
                && bounded(settings.intervalDraft, 100)
                && settings.intervals.count == 5 && settings.intervals.allSatisfy { (1...365).contains($0) }
                && zip(settings.intervals, settings.intervals.dropFirst()).allSatisfy { $0 < $1 },
                "Scegli cinque intervalli crescenti tra 1 e 365 giorni e una velocità tra 0,2 e 0,6.")
    try require(bounded(archive.draft.title, 200) && bounded(archive.draft.subject, 100)
                && bounded(archive.draft.source, StudioLimits.text), "La bozza supera i limiti di testo.")
    let draft = archive.cardDraft
    try require(bounded(draft.question, 2_000) && bounded(draft.answer, 5_000),
                "Domanda fino a 2.000 caratteri e risposta fino a 5.000.")
    if let lessonID = draft.lessonID {
      try require(lessons[lessonID] != nil
                  && (draft.segmentID == nil || validReference(lessonID, draft.segmentID!)),
                  "La fonte della domanda non è valida.")
    } else { try require(draft.segmentID == nil, "Scegli prima la lezione.") }
    if let run = archive.reviewRun {
      try require(lessons[run.lessonID] != nil && run.remaining.count <= 20
                  && Set(run.remaining).count == run.remaining.count
                  && run.remaining.allSatisfy { cards[$0]?.lessonID == run.lessonID && cards[$0]?.approved == true }
                  && bounded(run.text, 5_000), "Ripasso in corso non valido.")
    }
  }
}
