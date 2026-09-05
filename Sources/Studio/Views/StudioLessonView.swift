import SwiftUI
import Combine

struct StudioLessonView: View {
  private enum Panel { case reading, map, procedures, review, ending }
  @ObservedObject var store: StudioStore
  @ObservedObject var tracker: StudioSessionTracker
  @ObservedObject var audio: StudioAudio
  let lesson: StudioLesson
  @State private var panel: Panel = .reading
  @State private var notice: String?

  private var segment: StudioSegment { lesson.segments[lesson.position] }
  private var isCurrent: Bool { store.displayArchive.currentSession?.lessonID == lesson.id }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(lesson.title).font(.title.bold()).accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("studio.lesson.title")
      if !lesson.subject.isEmpty { Text(lesson.subject).foregroundStyle(.secondary) }
      if let notice { Text(notice) }
      sessionControls
      if panel == .reading {
        StudioButton("La mia mappa", icon: "point.3.connected.trianglepath.dotted", id: "studio.map") { show(.map) }
        StudioButton("Il mio formulario", icon: "list.number", id: "studio.procedures") { show(.procedures) }
        StudioButton("Ripasso", icon: "rectangle.on.rectangle", id: "studio.review") { show(.review) }
      } else {
        StudioButton("Torna al testo", icon: "book", id: "studio.back") { show(.reading) }
      }
      switch panel {
      case .reading: reading
      case .map: map
      case .procedures: procedures
      case .review: review
      case .ending: ending
      }
    }.disabled(store.recovery || store.hasPendingSave)
  }

  private var sessionControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      if isCurrent {
        if tracker.active {
          StudioButton("Pausa libera", icon: "pause", id: "studio.session.pause") { audio.stop(); tracker.pause() }
        } else {
          Text("Sei in pausa. Puoi ripartire o fermarti qui, senza perdere il punto.")
          StudioButton("Riprendi lo studio", icon: "play", id: "studio.session.resume") { _ = tracker.resume() }
        }
        StudioButton("Mi fermo qui", icon: "stop", id: "studio.session.finish") {
          audio.stop(); tracker.pause(); panel = .ending
        }
      } else if store.displayArchive.currentSession != nil {
        Text("Hai una sessione aperta in un'altra lezione. Puoi riprenderla dalla biblioteca.")
        StudioButton("Concludi la precedente e inizia qui", icon: "arrow.right") {
          audio.stop()
          if tracker.finish(.interrupted) { _ = tracker.start(lessonID: lesson.id) }
        }
      } else {
        StudioButton("Inizia lo studio", icon: "play", id: "studio.session.start") { _ = tracker.start(lessonID: lesson.id) }
        Text("Premi Inizia per registrare il tempo attivo. Puoi anche consultare gli appunti senza registrarlo.")
      }
    }
  }

  private var reading: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Parte \(lesson.position + 1) di \(lesson.segments.count)").font(.headline)
      Text("Leggi, ascolta o spiega a voce con parole tue. La tua voce non viene registrata.")
      Text(segment.text).textSelection(.enabled).accessibilityIdentifier("studio.segment")
      Text("Ogni parte segue le frasi del testo, fino a 600 caratteri. Non ha una durata fissa.")
        .font(.callout).foregroundStyle(.secondary)
      StudioButton("Ascolta questa parte", icon: "speaker.wave.2", id: "studio.listen") {
        audio.speak(segment.text, settings: store.displayArchive.settings)
      }
      if audio.state != .stopped {
        StudioButton(audio.state == .paused ? "Riprendi ascolto" : "Pausa ascolto",
                     icon: audio.state == .paused ? "play" : "pause", id: "studio.pause") { audio.togglePause() }
        StudioButton("Ferma ascolto", icon: "stop") { audio.stop() }
      }
      StudioButton("Ripeti ascolto", icon: "arrow.counterclockwise", id: "studio.repeat") {
        audio.speak(segment.text, settings: store.displayArchive.settings)
      }
      if let message = audio.message { Text(message) }
      Text("L'ascolto si ferma alla fine di questa parte. La successiva parte solo se lo scegli.")
      StudioButton("Parte precedente", icon: "arrow.left", id: "studio.previous") { move(-1) }
        .disabled(lesson.position == 0)
      StudioButton("Parte successiva", icon: "arrow.right", id: "studio.next") { move(1) }
        .disabled(lesson.position == lesson.segments.count - 1)
    }
  }

  private var map: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("La mia mappa").font(.title2.bold())
      Text("Tre idee e un collegamento. Puoi cambiare tutto: sono appunti tuoi, non una prova.")
      Picker("Che tipo di testo?", selection: lessonBinding(\.map.schema)) {
        ForEach(StudioSchema.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }.frame(minHeight: 44)
      ForEach(0..<3) { index in
        StudioTextEditor(title: lesson.map.schema.prompts[index], text: Binding(
          get: { currentLesson.map.ideas[index] },
          set: { value in store.stageLesson(lesson.id) { $0.map.ideas[index] = value } }))
      }
      StudioTextEditor(title: "Come si collegano? Il mio riassunto", text: lessonBinding(\.map.connection))
      Text("Fino a 2.000 caratteri per idea e 5.000 per il collegamento. La mappa resta sempre disponibile.")
      StudioButton("Vai al ripasso", icon: "rectangle.on.rectangle", id: "studio.review") { show(.review) }
    }
  }

  private var procedures: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Il mio formulario").font(.title2.bold())
      Text("Scrivi una regola, una formula con il suo significato o i passi che ti aiutano.")
      ForEach(Array(lesson.procedures.enumerated()), id: \.element.id) { index, step in
        StudioTextEditor(title: "Passo \(index + 1)", text: Binding(get: {
          currentLesson.procedures.first(where: { $0.id == step.id })?.text ?? step.text
        }, set: { value in
          store.stageLesson(lesson.id) {
            if let position = $0.procedures.firstIndex(where: { $0.id == step.id }) { $0.procedures[position].text = value }
          }
        }))
        StudioButton("Togli passo \(index + 1)", icon: "trash") {
          _ = store.editLesson(lesson.id) { $0.procedures.removeAll { $0.id == step.id } }
        }
      }
      StudioButton("Aggiungi un passo", icon: "plus") {
        _ = store.editLesson(lesson.id) { $0.procedures.append(StudioProcedure()) }
      }.disabled(lesson.procedures.count >= 50)
      Text("Fino a 50 passi, da 2.000 caratteri. Il formulario resta disponibile anche nel ripasso.")
      StudioButton("Vai al ripasso", icon: "rectangle.on.rectangle", id: "studio.review") { show(.review) }
    }
  }

  private var review: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Ripasso con calma").font(.title2.bold())
      Text("Prova prima con parole tue, anche a voce. Poi confronta con una risposta controllata da un adulto. Solo tu scegli come è andata.")
      if let run = store.displayArchive.reviewRun, !run.remaining.isEmpty {
        if run.lessonID == lesson.id,
           let card = store.displayArchive.cards.first(where: { $0.id == run.remaining.first }) {
          Text("\(run.remaining.count) domande ancora in questo giro. Puoi fermarti quando vuoi.")
          Text(card.question).font(.headline).accessibilityIdentifier("studio.review.question")
          StudioTextEditor(title: "Il mio tentativo (puoi lasciarlo vuoto e parlare)", text: reviewBinding(\.text, default: ""))
            .disabled(run.revealed)
          Picker("Quale aiuto ho usato?", selection: reviewBinding(\.help, default: .none)) {
            ForEach(StudioHelp.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }.frame(minHeight: 44)
          StudioButton("Consulta la mappa", icon: "point.3.connected.trianglepath.dotted", id: "studio.map") { show(.map) }
          StudioButton("Consulta il formulario", icon: "list.number", id: "studio.procedures") { show(.procedures) }
          if run.revealed {
            Text("Risposta modello dell'adulto").font(.headline)
            Text(card.answer).textSelection(.enabled).accessibilityIdentifier("studio.review.model")
            Text("Fonte nel testo").font(.headline)
            Text(lesson.segments.first { $0.id == card.segmentID }?.text ?? "")
            ForEach(StudioRecall.allCases, id: \.self) { recall in
              StudioButton(recall.rawValue, icon: recall == .again ? "arrow.counterclockwise" : "hand.raised",
                           id: "studio.review.\(recall)") {
                _ = store.record(cardID: card.id, text: run.text, help: run.help, recall: recall, now: Date())
              }
            }
          } else {
            StudioButton("Ho provato: mostra il modello", icon: "text.bubble", id: "studio.review.reveal") {
              _ = store.change { $0.reviewRun?.revealed = true }
            }
            StudioButton("Consulta il testo di questa domanda", icon: "book") {
              if let position = lesson.segments.firstIndex(where: { $0.id == card.segmentID }) {
                _ = store.editLesson(lesson.id) { $0.position = position }
                show(.reading)
              }
            }
          }
        } else { Text("Il ripasso aperto è in un'altra lezione. Ritrovi tutto tornando alle tue lezioni.") }
        StudioButton("Termina questo giro di ripasso", icon: "stop") {
          _ = store.change { $0.reviewRun = nil }
        }
      } else {
        let due = StudioSchedule.due(in: store.displayArchive, lessonID: lesson.id, now: Date())
        Text(due.isEmpty ? "Per ora non ci sono domande da riprendere. Puoi sempre usare testo, mappa e formulario."
             : "\(due.count) domande disponibili da riprendere, quando vuoi.")
        Text("Ogni giro contiene al massimo 20 domande, ognuna una sola volta. Nessuna scadenza toglie i tuoi strumenti.")
        StudioButton("Inizia un giro di ripasso", icon: "play", id: "studio.review.start") {
          _ = store.beginReview(lessonID: lesson.id, now: Date())
        }.disabled(due.isEmpty)
        Text("Le domande si scrivono e si approvano in Per l'adulto. Nessuna risposta è generata automaticamente.")
      }
    }
  }

  private var ending: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Per oggi può bastare").font(.title2.bold())
      if isCurrent {
        Picker("Come hai studiato?", selection: sessionBinding(\.mode, default: .reading)) {
          ForEach(StudioMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.frame(minHeight: 44)
        Picker("Fatica, se vuoi dirlo", selection: sessionBinding(\.fatigue, default: nil)) {
          Text("Non la indico").tag(Int?.none)
          ForEach(1...5, id: \.self) { Text("\($0) — \($0 == 1 ? "poca" : $0 == 5 ? "molta" : "intermedia")").tag(Optional($0)) }
        }.frame(minHeight: 44)
        StudioTextEditor(title: "Aiuti di un adulto (facoltativi)", text: sessionBinding(\.adultHelp, default: ""))
        StudioButton("Ho concluso ciò che volevo", icon: "checkmark", id: "studio.session.completed") {
          if tracker.finish(.completed) { notice = "Sessione salvata. I tuoi appunti restano qui."; panel = .reading }
        }
        StudioButton("Mi fermo, riprenderò quando voglio", icon: "pause", id: "studio.session.interrupted") {
          if tracker.finish(.interrupted) { notice = "Punto e appunti salvati. Puoi tornare quando vuoi."; panel = .reading }
        }
        Text("“Concluso” descrive la tua scelta, non misura quanto hai capito.")
      }
    }
  }

  private func show(_ destination: Panel) {
    audio.stop()
    _ = store.flushStaged()
    if store.displayArchive.reviewRun?.lessonID == lesson.id,
       store.displayArchive.reviewRun?.remaining.isEmpty == false {
      let help: StudioHelp? = destination == .map ? .map : destination == .procedures ? .procedure
        : destination == .reading ? .source : nil
      if let help {
        _ = store.change {
          let combined = ($0.reviewRun?.help ?? .none).adding(help)
          $0.reviewRun?.help = combined
        }
      }
    }
    panel = destination
  }

  private func move(_ offset: Int) {
    audio.stop()
    _ = store.editLesson(lesson.id) { $0.position += offset }
  }

  private func lessonBinding<Value>(_ path: WritableKeyPath<StudioLesson, Value>) -> Binding<Value> {
    Binding(get: { currentLesson[keyPath: path] }, set: { value in
      _ = store.editLesson(lesson.id) { $0[keyPath: path] = value }
    })
  }

  private func reviewBinding<Value>(_ path: WritableKeyPath<StudioReviewRun, Value>, default fallback: Value) -> Binding<Value> {
    Binding(get: { store.displayArchive.reviewRun?[keyPath: path] ?? fallback }, set: { value in
      _ = store.change { $0.reviewRun?[keyPath: path] = value }
    })
  }

  private func sessionBinding<Value>(_ path: WritableKeyPath<StudioSession, Value>, default fallback: Value) -> Binding<Value> {
    Binding(get: { store.displayArchive.currentSession?[keyPath: path] ?? fallback }, set: { value in
      _ = store.change { $0.currentSession?[keyPath: path] = value }
    })
  }

  private func lessonBinding(_ path: WritableKeyPath<StudioLesson, String>) -> Binding<String> {
    Binding(get: { currentLesson[keyPath: path] }, set: { value in
      store.stageLesson(lesson.id) { $0[keyPath: path] = value }
    })
  }

  private func reviewBinding(_ path: WritableKeyPath<StudioReviewRun, String>, default fallback: String) -> Binding<String> {
    Binding(get: { store.displayArchive.reviewRun?[keyPath: path] ?? fallback }, set: { value in
      store.stage { $0.reviewRun?[keyPath: path] = value }
    })
  }

  private func sessionBinding(_ path: WritableKeyPath<StudioSession, String>, default fallback: String) -> Binding<String> {
    Binding(get: { store.displayArchive.currentSession?[keyPath: path] ?? fallback }, set: { value in
      store.stage { $0.currentSession?[keyPath: path] = value }
    })
  }

  // Una battuta può arrivare prima del nuovo disegno della vista: legge già la bozza aggiornata.
  private var currentLesson: StudioLesson {
    store.displayArchive.lessons.first(where: { $0.id == lesson.id }) ?? lesson
  }
}
