import Foundation
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@Suite("Istruzioni per i primi utilizzi")
struct StudioOrientationTests {
  @Test("Le istruzioni restano aperte per le prime tre sessioni concluse",
        arguments: [0, 1, 2, 3, 4])
  func primiUtilizzi(completate: Int) {
    var archive = StudioArchive()
    archive.sessions = (0..<completate).map { _ in
      StudioSession(lessonID: UUID(), startedAt: Date(), outcome: .completed)
    }
    #expect(StudioOrientation.showsInstructions(in: archive) == (completate < 3))
  }

  @Test("Fermarsi o riprendere non fa sparire le istruzioni")
  func pauseNonContano() {
    var archive = StudioArchive()
    archive.sessions = (0..<5).map { _ in
      StudioSession(lessonID: UUID(), startedAt: Date(), outcome: .interrupted)
    }
    archive.currentSession = StudioSession(lessonID: UUID(), startedAt: Date())
    #expect(StudioOrientation.showsInstructions(in: archive))
  }
}
