import SwiftUI
import Combine

struct StudioGenerationView: View {
  @ObservedObject var store: StudioStore
  let onApproved: (UUID) -> Void
  @StateObject private var generation = StudioGeneration()
  @State private var input = StudioGenerationInput()
  @State private var initialized = false
  @State private var unavailable: String?
  @State private var showSource = false
  @State private var editing = false
  @Environment(\.scenePhase) private var scenePhase

  init(store: StudioStore, onApproved: @escaping (UUID) -> Void) {
    self.store = store
    self.onApproved = onApproved
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Prepara con Apple Intelligence").font(.title.bold()).accessibilityAddTraits(.isHeader)
      Text("Scrivi un argomento. Preparo una proposta sul dispositivo; tu rileggi e approvi.")
      Text("Finché non confermi, il ragazzo non la vede. Uscendo, la proposta non confermata viene persa.")
        .font(.callout).foregroundStyle(.secondary)
      if let unavailable { Text(unavailable).accessibilityIdentifier("studio.ai.availability") }
      if let message = generation.message { Text(message).accessibilityIdentifier("studio.ai.status") }
      if let error = store.error { Text(error) }
      if generation.draft == nil {
        preparation
      } else {
        review
      }
      if generation.approval != nil && store.hasPendingSave {
        Text("Conferma ricevuta, ma il salvataggio non è riuscito. La proposta resta qui per riprovare.")
        StudioButton("Riprova il salvataggio", icon: "arrow.clockwise", id: "studio.ai.retry") {
          generation.retryApproval(in: store)
          finishApproval()
        }
      }
      if generation.busy {
        ProgressView(generation.progress).frame(minHeight: 44)
        StudioButton("Annulla preparazione", icon: "stop", id: "studio.ai.cancel") { generation.cancel() }
      }
    }
    .onAppear {
      if !initialized {
        let existing = store.displayArchive.draft
        input = StudioGenerationInput(topic: existing.title, subject: existing.subject, source: existing.source)
        showSource = input.hasSource
        initialized = true
      }
      unavailable = StudioGeneration.unavailableMessage
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { unavailable = StudioGeneration.unavailableMessage }
    }
    .onChange(of: store.hasPendingSave) { _, pending in
      if !pending { finishApproval() }
    }
    .onDisappear { generation.cancel() }
  }

  private var preparation: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("1. Scegli da dove partire").font(.title2.bold())
      TextField("Argomento", text: $input.topic)
        .frame(minHeight: 44).accessibilityLabel("Argomento").accessibilityIdentifier("studio.ai.topic")
      DisclosureGroup("Usa il testo del libro (facoltativo)", isExpanded: $showSource) {
        TextField("Materia (facoltativa)", text: $input.subject)
          .frame(minHeight: 44).accessibilityLabel("Materia facoltativa")
        StudioTextEditor(title: "Testo fonte", text: $input.source, id: "studio.ai.source")
        Text("\(input.source.count) caratteri nella fonte.")
        if !store.displayArchive.draft.source.isEmpty {
          StudioButton("Usa il testo già importato nella bozza", icon: "doc.on.clipboard") {
            input.source = store.displayArchive.draft.source
          }
        }
        Text("Puoi incollare il testo, oppure importare un documento da «Aggiungi dal libro o da un testo» e ritrovare qui la bozza.")
      }.frame(minHeight: 44)
      Text(input.hasSource ? StudioGenerationValidation.sourceLabel : StudioGenerationValidation.syntheticLabel)
        .font(.callout).foregroundStyle(.secondary)
      StudioButton("Prepara la proposta", icon: "sparkles", id: "studio.ai.generate") {
        editing = false
        unavailable = StudioGeneration.unavailableMessage
        generation.start(input)
      }.buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(unavailable != nil || store.recovery || store.hasPendingSave)
      DisclosureGroup("Limiti e dati sul dispositivo") {
        Text(StudioGenerationInput.limitMessage).font(.callout)
        Text("MirrorScopio non scarica modelli e non usa servizi remoti. L'AI prepara materiale, non valuta apprendimento o QI.")
      }.frame(minHeight: 44)
      if unavailable != nil {
        StudioButton("Controlla di nuovo Apple Intelligence", icon: "arrow.clockwise") {
          unavailable = StudioGeneration.unavailableMessage
        }
      }
    }.disabled(generation.busy)
  }

  private var review: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("2. Rileggi e modifica").font(.title2.bold())
      Text(generation.draft?.provenance ?? "")
      Text("Controlla spiegazione, idee, risposte e citazioni. Il controllo automatico verifica soltanto la struttura e che le citazioni esistano, non che le risposte siano accurate.")
      if let draft = generation.draft, draft.input.hasSource {
        DisclosureGroup("Fonte originale, conservata senza modifiche") {
          Text(draft.input.source).textSelection(.enabled)
        }.frame(minHeight: 44)
        Text("La fonte resta il testo della lezione. La spiegazione preparata si trova nella mappa, insieme alle tre idee.")
      }
      if !editing, let draft = generation.draft {
        readablePreview(draft)
      }
      StudioButton(editing ? "Rileggi la proposta" : "Modifica la proposta", icon: "pencil",
                   id: "studio.ai.edit") { editing.toggle() }
      if editing {
        editors
      }
      StudioButton("Cambia argomento o fonte", icon: "arrow.uturn.backward") { generation.reviseInput() }
      Text("3. Conferma solo dopo aver riletto").font(.title2.bold())
      Text("La conferma aggiunge tutta la lezione e le sue domande insieme.")
      StudioButton("Ho controllato: aggiungi al percorso", icon: "checkmark", id: "studio.ai.approve") {
        if generation.approve(in: store) { finishApproval() }
      }.buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(store.recovery || store.hasPendingSave)
    }
    .disabled(generation.approval != nil)
  }

  private func readablePreview(_ draft: StudioGenerationDraft) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(draft.content.explanation).textSelection(.enabled)
        .accessibilityIdentifier("studio.ai.preview")
      Text("Le tre idee").font(.headline)
      ForEach(Array(draft.content.ideas.enumerated()), id: \.offset) { _, idea in Text(idea) }
      Text(draft.content.connection)
      ForEach(Array(draft.content.procedures.enumerated()), id: \.offset) { index, step in
        Text("\(index + 1). \(step)")
      }
      Text("Le domande da riprendere").font(.headline)
      ForEach(Array(draft.cards.enumerated()), id: \.offset) { index, card in
        VStack(alignment: .leading, spacing: 8) {
          Text("\(index + 1). \(card.question)").font(.headline)
          Text(card.answer)
          if !card.hint.isEmpty { Text("Spunto: \(card.hint)") }
          Text("Riferimento: «\(card.quote)»").font(.callout).foregroundStyle(.secondary)
        }
      }
    }
  }

  private var editors: some View {
    VStack(alignment: .leading, spacing: 16) {
      StudioTextEditor(title: "Spiegazione", text: contentBinding(\.explanation), id: "studio.ai.explanation")
      ForEach(0..<3) { index in
        StudioTextEditor(title: "Idea \(index + 1)", text: ideaBinding(index))
      }
      StudioTextEditor(title: "Collegamento della mappa", text: contentBinding(\.connection))
      if let draft = generation.draft {
        ForEach(draft.content.procedures.indices, id: \.self) { index in
          StudioTextEditor(title: "Passo utile \(index + 1)", text: procedureBinding(index))
          StudioButton("Togli passo \(index + 1)", icon: "minus.circle") {
            if generation.draft?.content.procedures.indices.contains(index) == true {
              generation.draft?.content.procedures.remove(at: index)
            }
          }
        }
        ForEach(draft.cards.indices, id: \.self) { index in
          cardReview(index)
        }
      }
      Text("Se cambi la spiegazione senza una fonte, ricontrolla anche le parti e le citazioni delle domande.")
    }
  }

  private func cardReview(_ index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Domanda \(index + 1)").font(.headline)
      StudioTextEditor(title: "Domanda", text: cardBinding(index, \.question))
      StudioTextEditor(title: "Risposta da controllare", text: cardBinding(index, \.answer))
      StudioTextEditor(title: "Spunto (facoltativo)", text: cardBinding(index, \.hint))
      if let draft = generation.draft {
        referencePicker(draft, index: index)
      }
      StudioTextEditor(title: "Citazione esatta dalla parte scelta", text: cardBinding(index, \.quote))
    }
  }

  @ViewBuilder
  private func referencePicker(_ draft: StudioGenerationDraft, index: Int) -> some View {
    let result = Result { try draft.referenceParts() }
    switch result {
    case .success(let parts):
      Picker("Parte di riferimento", selection: cardBinding(index, \.segmentNumber, default: 0)) {
        Text("Scegli una parte").tag(0)
        ForEach(parts.indices, id: \.self) { Text("Parte \($0 + 1)").tag($0 + 1) }
      }.frame(minHeight: 44)
      if draft.cards.indices.contains(index) {
        let selected = draft.cards[index].segmentNumber
        if selected > 0, selected <= parts.count {
          Text(parts[selected - 1]).textSelection(.enabled)
        } else {
          Text("Il riferimento non esiste: scegli una parte e ricopia la citazione.")
        }
      }
    case .failure(let error):
      Text(error.localizedDescription)
    }
  }

  private func contentBinding(_ path: WritableKeyPath<StudioGeneratedLesson, String>) -> Binding<String> {
    Binding(get: { generation.draft?.content[keyPath: path] ?? "" },
            set: { generation.draft?.content[keyPath: path] = $0 })
  }

  private func ideaBinding(_ index: Int) -> Binding<String> {
    Binding(get: {
      guard let draft = generation.draft, draft.content.ideas.indices.contains(index) else { return "" }
      return draft.content.ideas[index]
    }, set: { value in
      generation.draft?.content.ideas[index] = value
    })
  }

  private func procedureBinding(_ index: Int) -> Binding<String> {
    Binding(get: {
      guard let draft = generation.draft, draft.content.procedures.indices.contains(index) else { return "" }
      return draft.content.procedures[index]
    }, set: { value in
      if generation.draft?.content.procedures.indices.contains(index) == true {
        generation.draft?.content.procedures[index] = value
      }
    })
  }

  private func cardBinding(_ index: Int, _ path: WritableKeyPath<StudioGeneratedCard, String>) -> Binding<String> {
    cardBinding(index, path, default: "")
  }

  private func cardBinding<Value>(_ index: Int, _ path: WritableKeyPath<StudioGeneratedCard, Value>,
                                  default fallback: Value) -> Binding<Value> {
    Binding(get: {
      guard let draft = generation.draft, draft.cards.indices.contains(index) else { return fallback }
      return draft.cards[index][keyPath: path]
    }, set: { value in
      if generation.draft?.cards.indices.contains(index) == true {
        generation.draft?.cards[index][keyPath: path] = value
      }
    })
  }

  private func finishApproval() {
    if let id = generation.takeApprovedID(in: store) { onApproved(id) }
  }
}
