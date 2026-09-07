import SwiftUI

struct StudioHomeView: View {
  @Environment(\.palette) private var palette
  let archive: StudioArchive
  let start: () -> Void
  let library: () -> Void
  let parent: () -> Void
  let help: () -> Void
  let games: (() -> Void)?
  var settings: (() -> Void)?

  private var next: StudioNextStep? { StudioPathEngine.next(in: archive, now: Date()) }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      ViewThatFits(in: .horizontal) {
        HStack {
          heading
          Spacer()
          settingsButton
        }.fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: 12) {
          heading
          settingsButton
        }
      }
      VStack(alignment: .leading, spacing: 18) {
        Label(next?.reason ?? (archive.lessons.isEmpty
          ? StudioOrientation.trialExplanation : "Il tuo percorso si prepara insieme a un adulto."),
          systemImage: "sun.max").studioMuted()
        Text(next?.title ?? (archive.lessons.isEmpty ? StudioOrientation.trialTitle : "Scegliamo da dove partire"))
          .studioFont(.title, weight: .bold)
          .accessibilityIdentifier("studio.suggestion")
        if next != nil || archive.lessons.isEmpty {
          StudioButton(next?.action ?? "Inizia", icon: "play.fill", id: "studio.start", action: start)
            .studioPrimary()
            .controlSize(.large)
        }
        Text(StudioOrientation.showsInstructions(in: archive)
             ? StudioOrientation.parentExplanation
             : "Ti accompagno io. Puoi leggere o ascoltare e fermarti quando vuoi.")
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggio))
      let completed = StudioPathEngine.path(in: archive).completedIDs.count
      if completed > 0 {
        Label("\(completed) \(completed == 1 ? "incontro concluso" : "incontri conclusi"). Restano tuoi anche se fai una pausa.",
              systemImage: "checkmark.circle")
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) { secondaryActions }.fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: 12) { secondaryActions }
      }
      Divider()
      ViewThatFits(in: .horizontal) {
        HStack { parentActions }.fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading) { parentActions }
      }
    }
  }

  private var heading: some View {
    Text("MirrorScopio").studioFont(.largeTitle, weight: .bold).accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder private var settingsButton: some View {
    if let settings {
      StudioButton("Impostazioni", icon: "gearshape.fill", id: "studio.shell.settings", action: settings)
    }
  }

  @ViewBuilder private var secondaryActions: some View {
    StudioButton("Le mie lezioni", icon: "books.vertical", id: "studio.library", action: library)
    if let games {
      StudioButton("Giochi ed esercizi", icon: "gamecontroller", id: "studio.games", action: games)
    }
  }

  @ViewBuilder private var parentActions: some View {
    StudioButton("Per il genitore", icon: "person.crop.circle", id: "studio.parent", action: parent)
    StudioButton("Aiuto", icon: "questionmark.circle", id: "studio.help", action: help)
  }
}

struct StudioPathEditor: View {
  @Environment(\.palette) private var palette
  @ObservedObject var store: StudioStore
  let add: () -> Void
  let generate: () -> Void
  let settings: () -> Void
  let open: (UUID) -> Void

  private var path: StudioPath { StudioPathEngine.path(in: store.displayArchive) }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Prepara il suo percorso").studioFont(.title, weight: .bold).accessibilityAddTraits(.isHeader)
      StudioInstructionsView(.parent,
        automaticallyExpanded: store.displayArchive.lessons.isEmpty)
      StudioProgramPreparation(store: store)
      StudioButton("Prepara con Apple Intelligence", icon: "sparkles", id: "studio.ai.open", action: generate)
        .studioPrimary()
      StudioButton("Aggiungi dal libro o da un testo", icon: "doc.badge.plus", id: "studio.add", action: add)
      Text("L'AI propone; tu controlli e approvi. Puoi sempre preparare il materiale senza AI.")
        .studioMuted()
      Divider()
      Text("Il percorso, in ordine").studioFont(.title2, weight: .bold)
      if path.lessonIDs.isEmpty {
        Text("Nessuna lezione scelta. Aggiungine una oppure scegli dalla biblioteca qui sotto.")
      }
      if path.lessonIDs.count == 1 {
        Text("Per sostituire l'ultima lezione, aggiungi prima quella nuova: resta sempre un passo pronto.")
          .studioMuted()
      }
      ForEach(Array(path.lessonIDs.enumerated()), id: \.element) { index, id in
        if let lesson = store.displayArchive.lessons.first(where: { $0.id == id }) {
          VStack(alignment: .leading, spacing: 10) {
            Label("\(index + 1). \(lesson.title)",
                  systemImage: path.completedIDs.contains(id) ? "checkmark.circle" : "circle")
              .studioFont(.headline)
            ViewThatFits(in: .horizontal) {
              HStack { controls(id, index: index) }.fixedSize(horizontal: true, vertical: false)
              VStack(alignment: .leading) { controls(id, index: index) }
            }
          }.padding().background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggio))
        }
      }
      let excluded = store.displayArchive.lessons.filter { !path.lessonIDs.contains($0.id) }
      if !excluded.isEmpty {
        Text("Altre lezioni disponibili").studioFont(.headline)
        ForEach(excluded) { lesson in
          StudioButton("Aggiungi «\(lesson.title)» al percorso", icon: "plus") {
            _ = store.includeInPath(lesson.id)
          }
        }
      }
      Divider()
      StudioButton("Domande e dati", icon: "slider.horizontal.3", id: "studio.adult", action: settings)
      Text("Nessuna durata obbligatoria, classifica o serie di giorni da mantenere. «Concluso» significa che ha attraversato l'incontro, non che l'ha imparato.")
        .studioMuted()
    }
    .disabled(store.recovery || store.hasPendingSave)
  }

  @ViewBuilder private func controls(_ id: UUID, index: Int) -> some View {
    StudioButton("Controlla", icon: "book") { open(id) }
    StudioButton("Prima", icon: "arrow.up") { move(id, offset: -1) }.disabled(index == 0)
    StudioButton("Dopo", icon: "arrow.down") { move(id, offset: 1) }.disabled(index + 1 == path.lessonIDs.count)
    StudioButton("Togli dal percorso", icon: "minus.circle") {
      _ = store.change {
        var value = StudioPathEngine.path(in: $0)
        value.lessonIDs.removeAll { $0 == id }
        $0.path = value
      }
    }
    .disabled(store.displayArchive.guidedRun?.lessonID == id || path.lessonIDs.count == 1)
  }

  private func move(_ id: UUID, offset: Int) {
    _ = store.change {
      var value = StudioPathEngine.path(in: $0)
      guard let index = value.lessonIDs.firstIndex(of: id), value.lessonIDs.indices.contains(index + offset) else {
        throw StudioFailure("Questa lezione non può essere spostata in quella posizione.")
      }
      value.lessonIDs.swapAt(index, index + offset)
      $0.path = value
    }
  }
}
