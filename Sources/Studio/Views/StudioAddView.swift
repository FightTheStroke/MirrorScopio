import SwiftUI
import Combine
import UniformTypeIdentifiers

struct StudioAddView: View {
  @ObservedObject var store: StudioStore
  @ObservedObject var importer: StudioImporter
  let onSave: (UUID) -> Void
  @State private var filePicker = false
  @State private var camera = false
  @State private var message: String?
  @State private var acceptExtraction = false
  @State private var pendingLessonID: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("La nuova lezione").font(.title.bold())
      Text("Incolla il testo oppure scegli un file. Il testo estratto si rilegge e si corregge prima di salvare.")
      Text(StudioLimits.description).font(.callout)
      TextField("Titolo", text: store.binding(\.draft.title))
        .frame(minHeight: 44).accessibilityIdentifier("studio.title")
      TextField("Materia (facoltativa)", text: store.binding(\.draft.subject))
        .frame(minHeight: 44).accessibilityIdentifier("studio.subject")
      StudioTextEditor(title: "Testo della lezione", text: store.binding(\.draft.source), id: "studio.source")
      StudioButton("Importa TXT, PDF o immagine", icon: "doc.badge.plus") { filePicker = true }
        .disabled(importer.busy || store.hasPendingSave)
      #if os(iOS)
      StudioButton("Fotografa una pagina", icon: "camera") { camera = true }
        .disabled(importer.busy || store.hasPendingSave)
      #endif
      if let text = importer.message { Text(text).accessibilityIdentifier("studio.importStatus") }
      if importer.busy {
        ProgressView("Lettura del documento").frame(minHeight: 44)
        StudioButton("Annulla importazione", icon: "xmark") { importer.cancel() }
      }
      if let extracted = importer.extracted {
        Text("Anteprima del testo estratto").font(.headline)
        Text(extracted).textSelection(.enabled)
        StudioButton("Usa questo testo nella bozza", icon: "doc.on.clipboard") { acceptExtraction = true }
        StudioButton("Scarta l'estrazione e tieni la bozza", icon: "arrow.uturn.backward") { importer.extracted = nil }
      }
      if let message { Text(message) }
      StudioButton("Salva la lezione riletta", icon: "checkmark", id: "studio.save") {
        do {
          let draft = store.displayArchive.draft
          let lesson = try StudioLesson(title: draft.title, subject: draft.subject, source: draft.source)
          if store.change({
            $0.lessons.append(lesson)
            try $0.enrollLesson(lesson.id)
            $0.draft = StudioLessonDraft()
          }) {
            importer.extracted = nil
            onSave(lesson.id)
          } else if store.hasPendingSave {
            pendingLessonID = lesson.id
          }
        } catch { message = error.localizedDescription }
      }.disabled(importer.busy || importer.extracted != nil || store.hasPendingSave || store.recovery)
    }
    .disabled(store.recovery || store.hasPendingSave)
    .onChange(of: store.hasPendingSave) { _, pending in
      if !pending, let id = pendingLessonID, store.archive.lessons.contains(where: { $0.id == id }) {
        pendingLessonID = nil
        importer.extracted = nil
        onSave(id)
      }
    }
    .fileImporter(isPresented: $filePicker, allowedContentTypes: [.plainText, .pdf, .png, .jpeg, .heic]) { result in
      switch result {
      case .success(let url): importer.start(url: url)
      case .failure(let error): message = "File non importato: \(error.localizedDescription)"
      }
    }
    .confirmationDialog("Sostituire il testo della bozza con quello estratto?", isPresented: $acceptExtraction, titleVisibility: .visible) {
      Button("Usa il testo estratto") {
        if let text = importer.extracted, store.change({ $0.draft.source = text }) { importer.extracted = nil }
      }
      Button("Annulla", role: .cancel) {}
    } message: { Text("Titolo e materia restano. Poi puoi correggere il testo prima di salvare la lezione.") }
    #if os(iOS)
    .sheet(isPresented: $camera) {
      StudioCamera { result in
        camera = false
        switch result {
        case .success(let data): if let data { importer.start(image: data) }
        case .failure(let error): message = error.localizedDescription
        }
      }.interactiveDismissDisabled()
    }
    #endif
  }
}

#if os(iOS)
import UIKit
import AVFoundation

struct StudioCamera: View {
  let completion: (Result<Data?, Error>) -> Void
  @State private var ready = false
  @State private var message: String?
  var body: some View {
    Group {
      if ready { StudioCameraPicker(completion: completion).ignoresSafeArea() }
      else {
        VStack(spacing: 20) {
          Text(message ?? "Preparazione della fotocamera…")
          StudioButton("Torna alla lezione", icon: "arrow.backward") { completion(.success(nil)) }
        }.padding()
      }
    }.task {
      guard UIImagePickerController.isSourceTypeAvailable(.camera),
            Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
        message = "La fotocamera non è disponibile qui. Puoi importare una foto salvata."
        return
      }
      let authorized: Bool
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: authorized = true
      case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
      default: authorized = false
      }
      if authorized { ready = true }
      else { message = "Fotocamera non autorizzata. Puoi abilitarla nelle impostazioni del dispositivo o importare una foto." }
    }
  }
}

struct StudioCameraPicker: UIViewControllerRepresentable {
  let completion: (Result<Data?, Error>) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let completion: (Result<Data?, Error>) -> Void
    init(completion: @escaping (Result<Data?, Error>) -> Void) { self.completion = completion }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(.success(nil)) }
    func imagePickerController(_ picker: UIImagePickerController,
                              didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) else {
        completion(.failure(StudioFailure("La foto non si può leggere. Prova di nuovo oppure importa un file.")))
        return
      }
      completion(.success(data))
    }
  }
}
#endif
