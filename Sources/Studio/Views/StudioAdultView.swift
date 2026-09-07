import SwiftUI
import Combine
import UniformTypeIdentifiers

struct StudioAdultView: View {
  private enum Panel { case settings, cards, data }
  @ObservedObject var store: StudioStore
  @ObservedObject var tracker: StudioSessionTracker
  @ObservedObject var audio: StudioAudio
  let onLegacy: (() -> Void)?
  var onSettings: (() -> Void)? = nil
  @State private var panel: Panel = .settings
  @State private var selectedCard: UUID?
  @State private var deleteID: UUID?
  @State private var showDelete = false
  @State private var showImport = false
  @State private var showReplace = false
  @State private var pendingBackup: Data?
  @State private var transfer = StudioTransferDocument(data: Data())
  @State private var exportType: UTType = .json
  @State private var exportName = "Studio-backup"
  @State private var showExport = false
  @State private var message: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Studio: domande e dati").studioFont(.title, weight: .bold)
      Text(StudioReport.disclaimer)
      Picker("Area", selection: $panel) {
        Text("Ripasso").tag(Panel.settings)
        Text("Domande e fonti").tag(Panel.cards)
        Text("Dati e copie").tag(Panel.data)
      }.frame(minHeight: 44)
      if let message { Text(message).textSelection(.enabled) }
      switch panel {
      case .settings: settings
      case .cards: cards
      case .data: data
      }
      if let onLegacy {
        Divider()
        StudioButton("Apri il tachistoscopio", icon: "arrow.up.forward.app") {
          audio.stop(); tracker.pause(); onLegacy()
        }
        Text("È un'attività separata: non decide se puoi studiare.")
      }
    }
    .fileExporter(isPresented: $showExport, document: transfer, contentType: exportType,
                  defaultFilename: exportName) { result in
      switch result {
      case .success: message = "File esportato nella posizione scelta."
      case .failure(let error): message = "Esportazione non riuscita: \(error.localizedDescription)"
      }
    }
    .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let content = try StudioStore.readFile(url)
        let candidate = try StudioCodec.decode(content)
        pendingBackup = content
        message = "Copia valida: \(candidate.lessons.count) lezioni, \(candidate.cards.count) carte. Nulla è stato sostituito."
        showReplace = true
      } catch { message = "Copia non importata: \(error.localizedDescription)" }
    }
    .confirmationDialog("Sostituire tutti i dati Studio con questa copia?", isPresented: $showReplace, titleVisibility: .visible) {
      Button("Sostituisci i dati Studio", role: .destructive) {
        audio.stop(); tracker.pause()
        if let pendingBackup, store.replace(with: pendingBackup) {
          selectedCard = nil
          message = "Copia importata. Il file precedente è conservato nella cartella Studio."
        }
        pendingBackup = nil
      }
      Button("Annulla", role: .cancel) { pendingBackup = nil }
    } message: {
      Text("Lezioni, domande, appunti e resoconti Studio saranno sostituiti. Una copia dell'originale resterà sul dispositivo. Le altre attività non vengono toccate.")
    }
    .confirmationDialog("Eliminare la lezione e tutti i suoi dati Studio?", isPresented: $showDelete, titleVisibility: .visible) {
      Button("Elimina lezione e dati collegati", role: .destructive) {
        if let deleteID {
          audio.stop()
          if store.displayArchive.currentSession?.lessonID == deleteID { tracker.pause() }
          _ = store.change { $0.deleteLesson(deleteID) }
        }
        deleteID = nil
      }
      Button("Annulla", role: .cancel) { deleteID = nil }
    } message: { Text("Verranno tolti mappa, formulario, carte, tentativi e sessioni di questa lezione. Esporta prima una copia se vuoi conservarli.") }
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let onSettings {
        Text("Voce, caratteri, dimensioni e colori si scelgono nelle impostazioni di MirrorScopio. Valgono anche qui.")
        StudioButton("Apri le impostazioni", icon: "gearshape.fill", action: onSettings)
      } else {
      Toggle("Testo doppio", isOn: store.binding(\.settings.largeText)).frame(minHeight: 44)
        .accessibilityIdentifier("studio.textSize")
      Text("Il testo segue anche la dimensione scelta nelle impostazioni del dispositivo.")
      Picker("Voce italiana installata", selection: store.binding(\.settings.voiceID)) {
        Text("Scegli automaticamente tra le voci installate").tag("")
        ForEach(Speaker.italianVoices(), id: \.identifier) { voice in
          Text("\(voice.name), \(Speaker.qualityLabel(voice))").tag(voice.identifier)
        }
        if !store.displayArchive.settings.voiceID.isEmpty,
           !Speaker.italianVoices().contains(where: { $0.identifier == store.displayArchive.settings.voiceID }) {
          Text("Voce scelta non più disponibile").tag(store.displayArchive.settings.voiceID)
        }
      }.frame(minHeight: 44)
      Text("Nessun download dall'app. Se manca una voce, puoi usare quelle già presenti o gestirle nelle impostazioni di sistema.")
      Text("Velocità di lettura")
      Text("Voce e velocità si applicano alla prossima lettura. Puoi fermare e ripetere quella in corso.")
      Slider(value: store.binding(\.settings.rate), in: 0.2...0.6, step: 0.05)
        .frame(minHeight: 44).accessibilityLabel("Velocità di lettura")
      StudioButton("Prova la voce", icon: "speaker.wave.2") {
        audio.speak("Puoi ascoltare una parte del testo e poi fermarti, quando vuoi.", settings: store.displayArchive.settings)
      }
      StudioButton("Ferma la voce", icon: "stop") { audio.stop() }
      if let audioMessage = audio.message { Text(audioMessage) }
      }
      Text("Quando proporre di nuovo le domande").studioFont(.headline)
      Text("Cinque intervalli crescenti in giorni. La proposta iniziale è 1, 3, 7, 14, 30: puoi cambiarla. Non è una prescrizione.")
      TextField("Giorni separati da virgole", text: store.binding(\.settings.intervalDraft)).frame(minHeight: 44)
      StudioButton("Salva gli intervalli", icon: "checkmark") {
        let parts = store.displayArchive.settings.intervalDraft.split(separator: ",", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 5, values.count == 5 else {
          message = "Scrivi cinque numeri interi separati da virgole."
          return
        }
        if store.change({ $0.settings.intervals = values }) {
          message = "Intervalli salvati: saranno usati per i prossimi tentativi, senza cambiare le date già proposte."
        }
      }
      Text("“Ricordato” senza aiuti avanza nell'elenco; “Con aiuto” torna indietro di un passo; “Ancora” riparte dal primo. Gli aiuti restano disponibili in ogni caso.")
    }.disabled(store.recovery || store.hasPendingSave)
  }

  private var cards: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Domande scritte e controllate da una persona").studioFont(.headline)
      Text("La risposta deve essere sostenuta dal segmento indicato. L'app non ne giudica il significato e non inventa domande.")
      Picker("Lezione", selection: Binding(get: { store.displayArchive.cardDraft.lessonID }, set: { id in
        selectedCard = nil
        _ = store.change {
          $0.cardDraft.lessonID = id
          $0.cardDraft.segmentID = $0.lessons.first { $0.id == id }?.segments.first?.id
        }
      })) {
        Text("Scegli una lezione").tag(UUID?.none)
        ForEach(store.displayArchive.lessons) { Text($0.title).tag(Optional($0.id)) }
      }.frame(minHeight: 44)
      if let lesson = store.displayArchive.lessons.first(where: { $0.id == store.displayArchive.cardDraft.lessonID }) {
        Picker("Fonte della nuova domanda", selection: store.binding(\.cardDraft.segmentID)) {
          Text("Scegli una parte").tag(UUID?.none)
          ForEach(Array(lesson.segments.enumerated()), id: \.element.id) { index, segment in
            Text("Parte \(index + 1)").tag(Optional(segment.id))
          }
        }.frame(minHeight: 44)
        if let source = lesson.segments.first(where: { $0.id == store.displayArchive.cardDraft.segmentID }) {
          Text(source.text).textSelection(.enabled)
        }
        StudioTextEditor(title: "Nuova domanda", text: store.binding(\.cardDraft.question), id: "studio.card.question")
        StudioTextEditor(title: "Risposta modello", text: store.binding(\.cardDraft.answer), id: "studio.card.answer")
        Text("Domanda fino a 2.000 caratteri, risposta fino a 5.000. La bozza resta salvata anche se cambi area.")
        StudioButton("Ho controllato la fonte: aggiungi e approva", icon: "checkmark", id: "studio.card.save") {
          let draft = store.displayArchive.cardDraft
          guard let segmentID = draft.segmentID else { message = "Scegli la parte del testo che sostiene la risposta."; return }
          let card = StudioCard(lessonID: lesson.id, segmentID: segmentID, question: draft.question,
                                answer: draft.answer, approved: true)
          if store.change({ $0.cards.append(card); $0.cardDraft.question = ""; $0.cardDraft.answer = "" }) {
            message = "Domanda approvata e disponibile per il ripasso."
          }
        }
        Divider()
        Text("Domande della lezione").studioFont(.headline)
        ForEach(store.displayArchive.cards.filter { $0.lessonID == lesson.id }) { card in
          StudioButton(card.question, icon: card.approved ? "checkmark.circle" : "pencil") {
            selectedCard = selectedCard == card.id ? nil : card.id
          }
          if selectedCard == card.id {
            Text("Fonte: \(lesson.segments.first { $0.id == card.segmentID }?.text ?? "")").textSelection(.enabled)
            StudioTextEditor(title: "Domanda", text: cardBinding(card, \.question))
            StudioTextEditor(title: "Risposta", text: cardBinding(card, \.answer))
            Text(card.approved ? "Approvata dall'adulto." : "Modificata: controlla la fonte e approva di nuovo.")
            StudioButton("Conferma la risposta e approva", icon: "checkmark") {
              _ = store.change {
                if let index = $0.cards.firstIndex(where: { $0.id == card.id }) { $0.cards[index].approved = true }
              }
            }
          }
        }
      }
    }.disabled(store.recovery || store.hasPendingSave)
  }

  private var data: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(StudioReport.summary(store.displayArchive))
      Text("Il tempo viene contato solo dopo Inizia/Riprendi e mentre l'app è in primo piano. In caso di chiusura improvvisa possono mancare gli ultimi 15 secondi: non si aggiunge mai il tempo a app chiusa.")
      Text("Esportare crea una copia dei testi e delle risposte, non protetta dall'app. Puoi salvarla o condividerla, anche tramite File o AirDrop: la destinazione scelta può portarla fuori dal dispositivo.")
      Text("Studio è escluso dai backup automatici di sistema. Prima di cambiare o ripristinare il dispositivo, esporta una copia JSON e conservala al sicuro.")
      #if os(iOS)
      Text("L'archivio usa la protezione del dispositivo dopo il primo sblocco. L'app può ancora salvare mentre lo schermo è bloccato: serve a completare un salvataggio, non a continuare l'ascolto.")
      #else
      Text("Cartella e file Studio sono accessibili soltanto al tuo utente Mac.")
      #endif
      Text("Ogni ripristino conserva l'originale nella cartella Studio: queste copie occupano spazio e non vengono cancellate automaticamente.")
      StudioButton("Esporta copia JSON", icon: "square.and.arrow.up", id: "studio.backup.export") {
        do { export(try StudioCodec.encode(store.displayArchive), type: .json, name: "Studio-backup") }
        catch { message = error.localizedDescription }
      }.disabled(store.recovery)
      StudioButton("Importa copia JSON", icon: "square.and.arrow.down", id: "studio.backup.import") { showImport = true }
        .disabled(store.hasPendingSave)
      StudioButton("Esporta resoconto CSV", icon: "tablecells", id: "studio.report.export") {
        export(StudioReport.csv(store.displayArchive), type: .commaSeparatedText, name: "Studio-resoconto")
      }.disabled(store.recovery)
      if store.recovery {
        StudioButton("Esporta l'originale da recuperare", icon: "doc") {
          do { export(try StudioStore.readFile(store.fileURL), type: .json, name: "Studio-originale-da-recuperare") }
          catch { message = "Originale non esportato: \(error.localizedDescription)" }
        }
      }
      ForEach(store.displayArchive.sessions.reversed()) { session in
        DisclosureGroup("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) — \(session.outcome.rawValue)") {
          VStack(alignment: .leading, spacing: 8) {
            Text(store.displayArchive.lessons.first { $0.id == session.lessonID }?.title ?? "")
            Text("\(Int(session.activeSeconds)) secondi attivi registrati · \(session.mode.rawValue)")
            Text("Fatica dichiarata: \(session.fatigue.map(String.init) ?? "non indicata")")
            Text("Aiuti adulti: \(session.adultHelp.isEmpty ? "non indicati" : session.adultHelp)")
            Text("Avvii, pause e fine registrati: \(session.events.count)")
          }.padding(.vertical, 8)
        }.frame(minHeight: 44)
      }
      ForEach(store.displayArchive.attempts.reversed()) { attempt in
        DisclosureGroup("\(attempt.date.formatted(date: .abbreviated, time: .shortened)) — \(attempt.recall.rawValue)") {
          VStack(alignment: .leading, spacing: 8) {
            Text(attempt.question).studioFont(.headline)
            Text(attempt.text.isEmpty ? "Tentativo a voce o senza testo: contenuto non registrato." : attempt.text)
            Text("Aiuto dichiarato: \(attempt.help.rawValue)")
            Text("Modello consultato: \(attempt.answer)")
          }.padding(.vertical, 8)
        }.frame(minHeight: 44)
      }
      Divider()
      Text("Gestisci le lezioni").studioFont(.headline)
      ForEach(store.displayArchive.lessons) { lesson in
        StudioButton("Elimina «\(lesson.title)» e i dati collegati", icon: "trash") {
          deleteID = lesson.id; showDelete = true
        }.disabled(store.hasPendingSave || store.recovery)
      }
    }
  }

  private func export(_ content: Data, type: UTType, name: String) {
    transfer = StudioTransferDocument(data: content)
    exportType = type
    exportName = name
    showExport = true
  }

  private func cardBinding(_ card: StudioCard, _ path: WritableKeyPath<StudioCard, String>) -> Binding<String> {
    Binding(get: {
      store.displayArchive.cards.first(where: { $0.id == card.id })?[keyPath: path] ?? card[keyPath: path]
    }, set: { value in
      store.stage {
        guard let index = $0.cards.firstIndex(where: { $0.id == card.id }) else {
          throw StudioFailure("Questa domanda non è più disponibile.")
        }
        guard $0.reviewRun?.remaining.contains(card.id) != true else {
          throw StudioFailure("Termina il giro di ripasso aperto prima di modificare questa domanda.")
        }
        $0.cards[index][keyPath: path] = value
        $0.cards[index].approved = false
      }
    })
  }
}
