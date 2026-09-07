import SwiftUI

struct StudioProgramView: View {
  @ObservedObject var store: StudioStore
  @ObservedObject var tracker: StudioSessionTracker
  @ObservedObject var audio: StudioAudio
  let lesson: StudioLesson
  let program: StudioProgramLesson
  @State private var showWriting = false
  @State private var showHelp = false
  @AccessibilityFocusState private var headingFocused: Bool
  private var step: StudioProgramStep? { store.displayArchive.guidedRun?.programStep }

  var body: some View {
    if let step, program.activities.indices.contains(step.position) {
      let activity = program.activities[step.position]
      VStack(alignment: .leading, spacing: 20) {
        Text("Tappa \(program.stage) · Incontro \(program.session) di 5")
          .studioMuted().accessibilityIdentifier("studio.program.position")
        Text(activity.block.rawValue).studioFont(.headline)
        Text(activity.instruction).studioFont(.title2)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("studio.program.instruction")
          .accessibilityFocused($headingFocused)
        if !step.revealed {
          if !activity.material.isEmpty {
            if !step.hidden {
              Text(activity.material).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled).accessibilityIdentifier("studio.program.material")
            } else {
              Label("Testo coperto. Puoi riaprirlo quando vuoi.", systemImage: "book.closed")
            }
            if activity.kind != .reading {
              StudioButton(step.hidden ? "Riapri il testo" : "Copri il testo, se vuoi",
                icon: step.hidden ? "book" : "book.closed", id: "studio.program.cover") {
                audio.stop()
                _ = store.change {
                  $0.guidedRun?.programStep?.hidden.toggle()
                  if $0.guidedRun?.programStep?.hidden == false {
                    let help = ($0.guidedRun?.programStep?.help ?? .none).adding(.source)
                    $0.guidedRun?.programStep?.help = help
                  }
                }
              }
            }
          }
          listen(activity.instruction + (step.hidden ? "" : "\n" + activity.material))
          responseInput(activity, step: step)
          StudioButton(activity.kind == .reading ? "Ho letto, avanti" :
            activity.kind == .open ? "Ho provato: confronta" : "Confronta",
            icon: activity.kind == .reading ? "arrow.right" : "text.bubble",
            id: "studio.program.compare") {
              audio.stop()
              guard store.flushStaged(), store.revealProgramStep() else { return }
              if activity.kind == .reading { _ = store.advanceProgramStep() }
            }
            .studioPrimary()
            .disabled((activity.kind == .choice || activity.kind == .sequence)
              && step.selection.count != activity.answer.count)
        } else {
          comparison(activity, step: step)
        }
        if activity.kind != .reading {
          DisclosureGroup("Un aiuto per questo passo", isExpanded: Binding(
            get: { showHelp }, set: { value in
              if value {
                guard store.change({
                  let help = ($0.guidedRun?.programStep?.help ?? .none).adding(.source)
                  $0.guidedRun?.programStep?.help = help
                }) else { return }
              }
              showHelp = value
            })) {
            VStack(alignment: .leading, spacing: 12) {
              Text(activity.support).textSelection(.enabled)
              StudioButton("Ascolta l'aiuto", icon: "speaker.wave.2") {
                speak(activity.support)
              }
              let adultHelp = step.help.adding(.adult)
              StudioButton(adultHelp == step.help ? "Aiuto di una persona registrato" :
                "Anche una persona mi ha aiutato", icon: "person",
                id: "studio.program.adultHelp") {
                _ = store.change { $0.guidedRun?.programStep?.help = adultHelp }
              }.disabled(adultHelp == step.help)
            }.padding(.vertical, 8)
          }
          .accessibilityIdentifier("studio.program.help")
        }
        Text("Passo \(step.position + 1) di \(program.activities.count). Non serve finirli tutti adesso.")
          .studioMuted()
      }
      .onChange(of: step.position) { _, _ in
        showWriting = false
        showHelp = false
        headingFocused = true
      }
    }
  }

  @ViewBuilder private func responseInput(_ activity: StudioProgramActivity, step: StudioProgramStep) -> some View {
    switch activity.kind {
    case .reading: EmptyView()
    case .open:
      Text("Puoi rispondere a voce: il microfono resta spento. Non c'è una correzione automatica.")
      StudioButton(showWriting ? "Nascondi la scrittura" : step.text.isEmpty ? "Preferisco scrivere" : "Riapri le mie parole",
                   icon: "pencil", id: "studio.program.write") { showWriting.toggle() }
      if showWriting {
        StudioTextEditor(title: "Le mie parole", text: Binding(
          get: { store.displayArchive.guidedRun?.programStep?.text ?? "" },
          set: { value in store.stage { $0.guidedRun?.programStep?.text = value } }),
          id: "studio.program.response")
      }
    case .sequence, .choice:
      if activity.kind == .sequence {
        Text("Scegli \(activity.answer.count) elementi. Il primo tocco viene per primo.")
        if !step.selection.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(step.selection.enumerated()), id: \.offset) { index, id in
              if let option = activity.options.first(where: { $0.id == id }) {
                Text("\(index + 1). \(option.text)")
              }
            }
          }.accessibilityIdentifier("studio.program.selection")
        }
      }
      ForEach(activity.options) { option in
        StudioButton(option.text,
          icon: step.selection.contains(option.id) ? "checkmark.circle" : "circle",
          id: "studio.program.option.\(option.id)") {
            _ = store.change {
              guard var current = $0.guidedRun?.programStep else {
                throw StudioFailure("Riprendi prima l'attività.")
              }
              if activity.kind == .choice {
                current.selection = [option.id]
              } else {
                current.selection.append(option.id)
              }
              if !current.hidden && !activity.material.isEmpty { current.help = current.help.adding(.source) }
              $0.guidedRun?.programStep = current
            }
          }
          .disabled(activity.kind == .sequence &&
            (step.selection.contains(option.id) || step.selection.count == activity.answer.count))
          .accessibilityAddTraits(step.selection.contains(option.id) ? [.isSelected] : [])
      }
      if !step.selection.isEmpty {
        StudioButton("Ricomincia la scelta", icon: "arrow.counterclockwise",
                     id: "studio.program.clear") {
          _ = store.change { $0.guidedRun?.programStep?.selection = [] }
        }
      }
    }
  }

  @ViewBuilder private func comparison(_ activity: StudioProgramActivity, step: StudioProgramStep) -> some View {
    if let matched = StudioProgramEngine.matches(activity, selection: step.selection) {
      Label(matched ? "La scelta coincide" : "Ancora: guarda il confronto",
        systemImage: matched ? "checkmark.circle" : "arrow.counterclockwise")
        .studioFont(.headline).accessibilityIdentifier("studio.program.result")
      Text("Confronto delle scelte, non un voto sulla memoria o sulla comprensione.").studioMuted()
    } else {
      Text("Un esempio con cui confrontarti").studioFont(.headline)
      if !step.text.isEmpty { Text("Le tue parole: \(step.text)") }
      Text("Puoi usare parole diverse. Sei tu a dire com'è andata; l'app non valuta questa risposta.")
    }
    Text(activity.reference).fixedSize(horizontal: false, vertical: true)
      .textSelection(.enabled).accessibilityIdentifier("studio.program.reference")
    listen(activity.reference)
    if activity.kind == .open {
      Text("Com'è andata per te?")
      ForEach(StudioRecall.allCases, id: \.self) { choice in
        StudioButton(StudioOrientation.label(for: choice),
          icon: step.selfAssessment == choice ? "checkmark.circle" :
            choice == .again ? "arrow.counterclockwise" : "hand.raised",
          id: "studio.program.self.\(choice)") {
            _ = store.change { $0.guidedRun?.programStep?.selfAssessment = choice }
          }
      }
    }
    StudioButton("Avanti", icon: "arrow.right", id: "studio.program.next") {
      audio.stop()
      _ = store.advanceProgramStep()
    }.studioPrimary().disabled(activity.kind == .open && step.selfAssessment == nil)
    if activity.kind != .reading {
      StudioButton("Riprovo con il riferimento", icon: "arrow.counterclockwise",
                   id: "studio.program.again") {
        _ = store.change {
          $0.guidedRun?.programStep?.revealed = false
          $0.guidedRun?.programStep?.selection = []
          $0.guidedRun?.programStep?.selfAssessment = nil
          $0.guidedRun?.programStep?.usedReference = true
          let help = ($0.guidedRun?.programStep?.help ?? .none).adding(.source)
          $0.guidedRun?.programStep?.help = help
        }
      }
    }
  }

  @ViewBuilder private func listen(_ text: String) -> some View {
    if audio.state == .stopped {
      StudioButton("Ascolta, se vuoi", icon: "speaker.wave.2", id: "studio.program.listen") { speak(text) }
    } else {
      StudioButton(audio.state == .paused ? "Riprendi l'ascolto" : "Pausa ascolto",
                   icon: "pause") { audio.togglePause() }
      StudioButton("Ferma l'ascolto", icon: "stop") { audio.stop() }
    }
  }

  private func speak(_ text: String) {
    audio.speak(text, settings: store.displayArchive.settings)
    if audio.state == .speaking, !store.change({
      $0.currentSession?.mode = .mixed
      let help = ($0.guidedRun?.programStep?.help ?? .none).adding(.source)
      $0.guidedRun?.programStep?.help = help
    }) {
      audio.stop()
      tracker.pause()
    }
  }
}

struct StudioProgramPreparation: View {
  @ObservedObject var store: StudioStore
  @State private var load = StudioProgramLoad()
  @State private var expanded = false
  @State private var selectedStage = 1
  @State private var preview: [StudioLesson] = []
  @State private var error: String?
  @State private var confirmation: String?
  private var installed: Int { store.displayArchive.lessons.filter { $0.program != nil }.count }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioButton("Percorso di 8 settimane", icon: expanded ? "chevron.up" : "list.bullet.rectangle",
                   id: "studio.program.prepare") { expanded.toggle() }
      if expanded {
      VStack(alignment: .leading, spacing: 16) {
        Text(StudioProgramEngine.explanation)
        Text("Quattro blocchi: prepararsi, comprendere, scegliere una strategia e recuperare. Se serve una traccia: 5, 10, 5 e 5 minuti. Circa 25 minuti e 5 incontri alla settimana sono solo una proposta; non c'è un conto alla rovescia.")
        Text("Le attività di memoria accompagnano la comprensione: non promettono aumenti delle capacità generali. Gli aiuti non si ritirano a una data prestabilita.")
          .studioMuted()
        Text("Carico scelto dall'adulto").studioFont(.headline)
        loadControl("Elementi", value: $load.memory, range: 2...4)
        loadControl("Consegne", value: $load.instructions, range: 2...3)
        loadControl("Frasi del riassunto", value: $load.sentences, range: 2...5)
        Text("Prima la comprensione, poi eventualmente più materiale. Cambia una sola richiesta alla volta; non serve aumentare la velocità. Nessun aumento automatico con il passare dei giorni.")
        if installed > 0 {
          Text("\(installed) incontri già presenti. Aggiungerli di nuovo non duplica nulla e non cambia il carico né le risposte salvate.")
          StudioButton("Applica il carico agli incontri non iniziati", icon: "slider.horizontal.3",
                       id: "studio.program.load") {
            confirmation = nil
            if store.updateProgramLoad(load) {
              confirmation = "Carico aggiornato solo per gli incontri ancora da iniziare."
              preparePreview()
            } else { error = store.error }
          }
        }
        Picker("Tappa da esplorare", selection: $selectedStage) {
          ForEach(1...8, id: \.self) { stage in
            Text("\(stage). \(StudioProgramCatalog.stageTitles[stage - 1])").tag(stage)
          }
        }.accessibilityIdentifier("studio.program.preview.stage")
        Text(StudioProgramCatalog.goals[selectedStage - 1])
        ForEach(preview.filter { $0.program?.stage == selectedStage }) { lesson in
          DisclosureGroup(lesson.title) {
            VStack(alignment: .leading, spacing: 12) {
              ForEach(lesson.program?.activities ?? []) { activity in
                VStack(alignment: .leading, spacing: 6) {
                  Text("\(activity.block.rawValue) · \(activity.instruction)").studioFont(.headline)
                  if !activity.material.isEmpty { Text(activity.material) }
                  Text("Riferimento: \(activity.reference)").studioMuted()
                  if activity.kind == .open { Text("Confronto e autovalutazione, non correzione automatica.") }
                }
              }
            }.padding(.vertical, 8)
          }
        }
        if let error { Label(error, systemImage: "exclamationmark.triangle") }
        if let confirmation { Label(confirmation, systemImage: "checkmark.circle") }
        StudioButton("Attiva come prossimo percorso", icon: "play.fill", id: "studio.program.activate") {
          install(activate: true)
        }.studioPrimary()
        StudioButton("Aggiungi in fondo al percorso", icon: "plus", id: "studio.program.append") {
          install(activate: false)
        }
        Text("Le lezioni manuali e quelle preparate con AI restano nella biblioteca e nel percorso. Un incontro in pausa non viene sostituito.")
        if installed > 0 {
          StudioProgramReportView(archive: store.displayArchive)
        }
      }.padding(.vertical, 12)
      }
    }
    .onChange(of: expanded) { _, value in
      if value {
        if let existing = store.displayArchive.lessons.first(where: { $0.program != nil })?.program?.load {
          load = existing
        }
        preparePreview()
      }
    }
    .onChange(of: load) { _, _ in preparePreview() }
  }

  private func preparePreview() {
    do {
      preview = try StudioProgramCatalog.lessons(load: load).map { candidate in
        store.displayArchive.lessons.first { $0.program?.catalogID == candidate.program?.catalogID } ?? candidate
      }
      error = nil
    } catch { self.error = error.localizedDescription }
  }

  private func loadControl(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(title): fino a \(value.wrappedValue)").studioFont(.headline)
      ViewThatFits(in: .horizontal) {
        HStack {
          loadButtons(title, value: value, range: range)
        }.fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading) {
          loadButtons(title, value: value, range: range)
        }
      }
    }
  }

  @ViewBuilder private func loadButtons(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    StudioButton("Meno: \(title.lowercased())", icon: "minus") { value.wrappedValue -= 1 }
      .disabled(value.wrappedValue <= range.lowerBound)
    StudioButton("Più: \(title.lowercased())", icon: "plus") { value.wrappedValue += 1 }
      .disabled(value.wrappedValue >= range.upperBound)
  }

  private func install(activate: Bool) {
    confirmation = nil
    if store.installProgram(load: load, activate: activate) {
      confirmation = activate ? "Percorso attivato. A casa, Inizia apre il prossimo passo."
        : "Incontri aggiunti in fondo. Il passo attuale resta al suo posto."
      preparePreview()
    } else {
      error = store.error ?? "Il percorso non è stato salvato. Riprova."
    }
  }
}

struct StudioProgramReportView: View {
  let archive: StudioArchive
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Uno sguardo ogni due tappe").studioFont(.headline)
      Text("Un riepilogo descrittivo, non una misura clinica. Le risposte aperte sono autovalutazioni; le scelte chiuse sono confronti con il riferimento, anche con aiuti.")
      ForEach([1, 3, 5, 7], id: \.self) { first in
        let ids = archive.lessons.filter {
          guard let stage = $0.program?.stage else { return false }
          return (first...(first + 1)).contains(stage)
        }.map(\.id)
        let sessions = archive.sessions.filter { ids.contains($0.lessonID) }
        let responses = sessions.flatMap { $0.programResponses ?? [] }
        let closed = responses.filter { $0.matched != nil }
        let open = responses.filter { $0.kind == .open }
        DisclosureGroup("Tappe \(first)–\(first + 1): \(sessions.count) incontri registrati") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Scelte coincidenti: \(closed.filter { $0.matched == true }.count) su \(closed.count). Non significa «ricordate senza aiuto».")
            Text("Elementi nella posizione attesa: \(closed.reduce(0) { $0 + ($1.matchedUnits ?? 0) }) su \(closed.reduce(0) { $0 + ($1.totalUnits ?? 0) }).")
            Text("Autovalutazioni: \(open.count). Con aiuti registrati: \(responses.filter { $0.help != .none }.count) attività.")
            Text("Con aiuto di una persona dichiarato: \(responses.filter { $0.help.adding(.adult) == $0.help }.count) attività.")
            ForEach(Array(open.enumerated()), id: \.offset) { _, response in
              Text("\(response.instruction)\n\(response.text.isEmpty ? "Risposta a voce, non registrata." : response.text)\nAutovalutazione: \(response.selfAssessment?.rawValue ?? "Non disponibile")")
            }
          }.padding(.vertical, 8)
        }
      }
    }
  }
}
