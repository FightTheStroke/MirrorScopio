import SwiftUI

struct StudioGuidedView: View {
  @ObservedObject var store: StudioStore
  @ObservedObject var tracker: StudioSessionTracker
  @ObservedObject var audio: StudioAudio
  let goHome: () -> Void
  @State private var showSupport = false

  private var run: StudioGuidedRun? { store.displayArchive.guidedRun }
  private var lesson: StudioLesson? {
    store.displayArchive.lessons.first { $0.id == run?.lessonID }
  }
  private var review: StudioReviewRun? { store.displayArchive.reviewRun }

  var body: some View {
    if let run, let lesson {
      VStack(alignment: .leading, spacing: 20) {
        Text(lesson.title).studioFont(.title, weight: .bold).accessibilityAddTraits(.isHeader)
        if !tracker.active, run.phase != .finished {
          Text("Sei in pausa. Il tuo punto è qui.")
          StudioButton("Riprendi", icon: "play.fill", id: "studio.guided.resume") {
            _ = tracker.start(lessonID: lesson.id)
          }.studioPrimary()
        } else {
          switch run.phase {
          case .reading: reading(lesson)
          case .recall: recall(lesson)
          case .finished: finished
          }
        }
        if run.phase != .finished {
          Divider()
          ViewThatFits(in: .horizontal) {
            HStack { supportActions }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading) { supportActions }
          }

        }
        if let message = audio.message { Text(message).studioMuted() }
      }
      .disabled(store.recovery || store.hasPendingSave)
      .sheet(isPresented: $showSupport) {
        NavigationStack {
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              Text("Il testo").studioFont(.headline)
              Text(lesson.source)
              Text("La mappa").studioFont(.headline)
              ForEach(Array(lesson.map.ideas.enumerated()), id: \.offset) { _, idea in
                if !idea.isEmpty { Text(idea) }
              }
              if !lesson.map.connection.isEmpty { Text(lesson.map.connection) }
              ForEach(lesson.procedures) { step in Text(step.text) }
              StudioButton("Ascolta il testo", icon: "speaker.wave.2") {
                speak(lesson.source)
              }
            }.padding(24).textSelection(.enabled)
          }
          .navigationTitle("I tuoi strumenti")
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Torna al passo") { audio.stop(); showSupport = false }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("studio.guided.support.close")
            }
          }
        }
        #if os(macOS)
        .frame(idealWidth: 600, idealHeight: 600)
        #endif
        .onDisappear { audio.stop() }
      }
    } else {
      Text("Il passo è stato salvato.")
      StudioButton("Torna a casa", icon: "house", action: goHome)
    }
  }

  @ViewBuilder private var supportActions: some View {
    StudioButton("Mi fermo qui", icon: "pause", id: "studio.guided.pause") {
      audio.stop(); tracker.pause(); goHome()
    }
    StudioButton("Un aiuto", icon: "book", id: "studio.guided.support") {
      audio.stop()
      if run?.phase == .recall {
        guard store.change({
          let help = ($0.reviewRun?.help ?? .none).adding(.source)
          $0.reviewRun?.help = help
        }) else { return }
      }
      showSupport = true
    }
  }

  private func reading(_ lesson: StudioLesson) -> some View {
    let position = run?.position ?? 0
    let positions = lesson.readablePositions
    let ordinal = positions.firstIndex(of: position) ?? 0
    return VStack(alignment: .leading, spacing: 20) {
      StudioInstructionsView(.reading,
        automaticallyExpanded: StudioOrientation.showsInstructions(in: store.displayArchive),
        listen: { speak(StudioInstruction.reading.explanation) })
      Text("Una parte alla volta · \(ordinal + 1) di \(positions.count)")
        .studioFont(.headline).studioMuted()
      Text(lesson.segments[position].text.trimmingCharacters(in: .whitespacesAndNewlines))
        .studioFont(.title2).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("studio.guided.text")
      listen(lesson.segments[position].text)
      StudioButton(ordinal + 1 < positions.count ? "Avanti" : "Continua",
                   icon: "arrow.right", id: "studio.guided.next") {
        audio.stop()
        _ = store.advanceGuided()
      }.studioPrimary()
      if ordinal > 0 {
        StudioButton("Rivedi la parte prima", icon: "arrow.left") {
          audio.stop(); _ = store.previousGuidedPart()
        }
      }
    }
  }

  @ViewBuilder private func recall(_ lesson: StudioLesson) -> some View {
    if let review, let id = review.remaining.first,
       let card = store.displayArchive.cards.first(where: { $0.id == id && $0.approved }) {
      StudioInstructionsView(review.revealed ? .comparison : .recall,
        automaticallyExpanded: StudioOrientation.showsInstructions(in: store.displayArchive),
        listen: { speak((review.revealed ? StudioInstruction.comparison : .recall).explanation) })
      Text(card.question).studioFont(.title2).accessibilityIdentifier("studio.guided.question")
      if !review.revealed {
        Text("Rispondi a voce. Il microfono resta spento.")
        listen(card.question)
        StudioButton("Vedi la risposta", icon: "text.bubble", id: "studio.guided.reveal") {
          audio.stop(); _ = store.change { $0.reviewRun?.revealed = true }
        }.studioPrimary()
      } else {
        Text(card.answer).studioFont(.title3).accessibilityIdentifier("studio.guided.answer")
        listen(card.answer)
        Text("Com'è andata per te? Non è un voto.")
        ForEach(StudioRecall.allCases, id: \.self) { choice in
          StudioButton(StudioOrientation.label(for: choice),
                       icon: choice == .again ? "arrow.counterclockwise" : "hand.raised",
                       id: "studio.guided.\(choice)") {
            audio.stop()
            if store.record(cardID: card.id, text: review.text, help: review.help, recall: choice, now: Date()),
               store.displayArchive.reviewRun?.remaining.isEmpty == true {
              _ = store.advanceGuided()
            }
          }
        }
      }
    } else {
      Text("Hai attraversato questo ripasso.")
      StudioButton("Continua", icon: "arrow.right", id: "studio.guided.next") {
        _ = store.advanceGuided()
      }.studioPrimary()
    }
  }

  private var finished: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label("Un passo fatto", systemImage: "checkmark.circle").studioFont(.largeTitle, weight: .bold)
        .accessibilityIdentifier("studio.guided.finished")
      Text("Per oggi può bastare. Quello che hai fatto resta qui.")
      Text("Premi Torna a casa. La prossima volta troverai già indicato da dove ripartire.")
        .studioMuted()
      StudioButton("Torna a casa", icon: "house.fill", id: "studio.guided.finish") {
        audio.stop()
        if store.displayArchive.currentSession != nil, !tracker.finish(.completed) { return }
        if store.finishGuided() { goHome() }
      }.studioPrimary()
    }
  }

  @ViewBuilder private func listen(_ text: String) -> some View {
    if audio.state == .stopped {
      StudioButton("Ascolta", icon: "speaker.wave.2", id: "studio.guided.listen") {
        speak(text)
      }
    } else {
      StudioButton(audio.state == .paused ? "Riprendi l'ascolto" : "Pausa ascolto", icon: "pause",
                   id: "studio.guided.audio.pause") { audio.togglePause() }
      StudioButton("Ferma l'ascolto", icon: "stop") { audio.stop() }
    }
  }

  private func speak(_ text: String) {
    audio.speak(text, settings: store.displayArchive.settings)
    if audio.state == .speaking, !store.change({ $0.currentSession?.mode = .mixed }) {
      audio.stop()
      tracker.pause()
    }
  }
}
