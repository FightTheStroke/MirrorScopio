import SwiftUI
import Combine
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
private final class StudioRuntime {
  static let shared = StudioRuntime()
  let store: StudioStore
  let tracker: StudioSessionTracker
  let audio = StudioAudio()
  let importer = StudioImporter()
  private var terminationObserver: AnyCancellable?
  private init() {
    store = StudioStore()
    tracker = StudioSessionTracker(store: store)
    audio.onInterruption = { [weak self] in self?.tracker.pause() }
    #if os(macOS)
    let notification = NSApplication.willTerminateNotification
    #else
    let notification = UIApplication.willTerminateNotification
    #endif
    terminationObserver = NotificationCenter.default.publisher(for: notification).sink { [weak self] _ in
      _ = self?.store.flushStaged()
      self?.audio.stop()
      self?.tracker.pause()
    }
  }
}

struct StudioRootView: View {
  private enum Panel { case home, add, lesson(UUID), adult }
  @StateObject private var store: StudioStore
  @StateObject private var tracker: StudioSessionTracker
  @StateObject private var audio: StudioAudio
  @StateObject private var importer: StudioImporter
  @State private var panel: Panel = .home
  @State private var showHelp = false
  @Environment(\.scenePhase) private var scenePhase
  @ScaledMetric(relativeTo: .body) private var textSize = 17
  @ScaledMetric(relativeTo: .body) private var columnWidth = 760
  private let onLegacy: (() -> Void)?
  private let heartbeat = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

  init(onLegacy: (() -> Void)? = nil) {
    let runtime = StudioRuntime.shared
    _store = StateObject(wrappedValue: runtime.store)
    _tracker = StateObject(wrappedValue: runtime.tracker)
    _audio = StateObject(wrappedValue: runtime.audio)
    _importer = StateObject(wrappedValue: runtime.importer)
    self.onLegacy = onLegacy
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if case .home = panel {
          Text("Il mio studio").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
        } else {
          StudioButton("Le mie lezioni", icon: "house", id: "studio.home") { navigate(.home) }
        }
        if let error = store.error {
          VStack(alignment: .leading, spacing: 8) {
            Label("Dati da controllare", systemImage: "exclamationmark.triangle").font(.headline)
            Text(error).textSelection(.enabled)
            StudioButton("Riprova", icon: "arrow.clockwise") { store.retry() }
            if store.recovery {
              Text("Puoi recuperare una copia da Per l'adulto. Non verrà cancellato l'originale.")
            }
          }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        switch panel {
        case .home: home
        case .add:
          StudioAddView(store: store, importer: importer) { id in openLesson(id) }
        case .lesson(let id):
          if let lesson = store.displayArchive.lessons.first(where: { $0.id == id }) {
            StudioLessonView(store: store, tracker: tracker, audio: audio, lesson: lesson)
          } else { Text("La lezione non è disponibile. Torna alle tue lezioni.") }
        case .adult:
          StudioAdultView(store: store, tracker: tracker, audio: audio, onLegacy: onLegacy)
        }
      }
      .padding()
      .frame(maxWidth: columnWidth * (store.displayArchive.settings.largeText ? 2 : 1), alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .font(.system(size: textSize * (store.displayArchive.settings.largeText ? 2 : 1)))
    .buttonStyle(.bordered)
    .textFieldStyle(.roundedBorder)
    .onReceive(heartbeat) { _ in tracker.checkpoint() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { _ = store.flushStaged(); audio.background(); tracker.pause() }
    }
    .onDisappear { _ = store.flushStaged(); audio.stop(); tracker.pause() }
    .sheet(isPresented: $showHelp) { StudioHelpView(onClose: { showHelp = false }) }
    .alert("Modifica non accettata", isPresented: Binding(
      get: { store.rejectedEdit != nil },
      set: { if !$0 { store.rejectedEdit = nil } }
    )) {
      Button("Torna al testo") { store.rejectedEdit = nil }
    } message: {
      Text(store.rejectedEdit ?? "")
    }
  }

  private var home: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Un testo alla volta: puoi leggere, ascoltare o spiegare con parole tue.")
      Text("Studio salva qui, senza invii automatici. Se esporti una copia, scegli tu dove va.")
      Text("È uno strumento di aiuto allo studio, non una terapia o una valutazione. Non promette risultati: puoi scegliere ciò che ti aiuta.")
      StudioButton("Aggiungi una lezione", icon: "plus", id: "studio.add") { navigate(.add) }
        .disabled(store.recovery || store.hasPendingSave)
      StudioButton("Come funziona", icon: "questionmark.circle", id: "studio.help") {
        audio.stop(); tracker.pause(); showHelp = true
      }
      if let session = store.displayArchive.currentSession,
         let lesson = store.displayArchive.lessons.first(where: { $0.id == session.lessonID }) {
        Text("Puoi riprendere «\(lesson.title)». La pausa non è un problema.")
        StudioButton("Riprendi lo studio", icon: "play") { openLesson(lesson.id) }
      }
      if store.displayArchive.lessons.isEmpty { Text("Incolla un testo, importa un file o fotografa una pagina per cominciare.") }
      ForEach(store.displayArchive.lessons) { lesson in
        VStack(alignment: .leading, spacing: 4) {
          StudioButton(lesson.title, icon: "book", id: "studio.openLesson") { openLesson(lesson.id) }
          if !lesson.subject.isEmpty { Text(lesson.subject).foregroundStyle(.secondary) }
          Text("Parte \(lesson.position + 1) di \(lesson.segments.count)").font(.callout)
        }
      }
      StudioButton("Per l'adulto", icon: "person.crop.circle", id: "studio.adult") { navigate(.adult) }
    }
  }

  private func navigate(_ destination: Panel) {
    _ = store.flushStaged()
    audio.stop()
    tracker.pause()
    panel = destination
  }

  private func openLesson(_ id: UUID) {
    navigate(.lesson(id))
  }
}

struct StudioButton: View {
  @ScaledMetric(relativeTo: .body) private var tapSize = 44
  let title: String
  let icon: String
  let id: String
  let action: () -> Void
  init(_ title: String, icon: String, id: String = "", action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.id = id
    self.action = action
  }
  var body: some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .frame(minWidth: max(44, tapSize), minHeight: max(44, tapSize), alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }.accessibilityIdentifier(id)
  }
}

struct StudioTextEditor: View {
  @FocusState private var editing: Bool
  let title: String
  @Binding var text: String
  var id = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.headline)
      #if os(iOS)
      if editing {
        StudioButton("Fine scrittura", icon: "keyboard.chevron.compact.down", id: "studio.keyboard.done") {
          editing = false
        }
      }
      #endif
      TextEditor(text: $text)
        .focused($editing)
        .frame(minHeight: 140)
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
  }
}

extension StudioStore {
  func binding<Value>(_ path: WritableKeyPath<StudioArchive, Value>) -> Binding<Value> {
    Binding(get: { self.displayArchive[keyPath: path] }, set: { value in
      _ = self.change { $0[keyPath: path] = value }
    })
  }

  func binding(_ path: WritableKeyPath<StudioArchive, String>) -> Binding<String> {
    Binding(get: { self.displayArchive[keyPath: path] }, set: { value in
      self.stage { $0[keyPath: path] = value }
    })
  }
}

struct StudioTransferDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents, data.count <= StudioLimits.fileBytes else {
      throw StudioFailure("Scegli un file fino a 20 MB.")
    }
    self.data = data
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
