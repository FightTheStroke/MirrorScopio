import Foundation
import Darwin

enum StudioFileStorage {
  static func write(_ data: Data, to url: URL) throws {
    guard url.isFileURL else { throw StudioFailure("Scegli un file locale.") }
    let folder = url.deletingLastPathComponent()
    try prepareFolder(folder)
    let temporary = folder.appendingPathComponent(".scrittura-\(UUID().uuidString).tmp")
    do {
      #if os(iOS)
      let options: Data.WritingOptions = [.withoutOverwriting, .completeFileProtectionUntilFirstUserAuthentication]
      #else
      let options: Data.WritingOptions = [.withoutOverwriting]
      #endif
      try data.write(to: temporary, options: options)
      try protectFile(temporary)
      // Permessi e protezione precedono la sostituzione atomica: se falliscono,
      // il file originale non viene toccato.
      let result = temporary.path.withCString { source in
        url.path.withCString { destination in
          let status = Darwin.rename(source, destination)
          return (status, errno)
        }
      }
      guard result.0 == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(result.1)) }
    } catch let original {
      do { try FileManager.default.removeItem(at: temporary) }
      catch let cleanup as CocoaError where cleanup.code == .fileNoSuchFile || cleanup.code == .fileReadNoSuchFile {}
      catch {
        throw StudioFailure("Scrittura non riuscita: \(original.localizedDescription) Non posso rimuovere il file temporaneo: \(error.localizedDescription)")
      }
      throw original
    }
  }

  static func protectExisting(_ url: URL) throws {
    guard url.isFileURL else { throw StudioFailure("Scegli un file locale.") }
    try prepareFolder(url.deletingLastPathComponent())
    try protectFile(url)
  }

  private static func prepareFolder(_ folder: URL) throws {
    let permissions: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: permissions)
    try FileManager.default.setAttributes(permissions, ofItemAtPath: folder.path)
    #if os(iOS)
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                         ofItemAtPath: folder.path)
    #endif
    try excludeFromBackup(folder)
  }

  private static func protectFile(_ file: URL) throws {
    var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
    #if os(iOS)
    attributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
    #endif
    try FileManager.default.setAttributes(attributes, ofItemAtPath: file.path)
    try excludeFromBackup(file)
  }

  private static func excludeFromBackup(_ url: URL) throws {
    var localURL = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try localURL.setResourceValues(values)
  }

  static func read(_ url: URL) throws -> Data {
    guard url.isFileURL else { throw StudioFailure("Scegli un file locale.") }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular else {
      throw StudioFailure("Scegli un file di testo, un documento o un'immagine, non una cartella o un collegamento.")
    }
    guard let size = attributes[.size] as? NSNumber, size.intValue <= StudioLimits.fileBytes else {
      throw StudioFailure("Il file supera 20 MB.")
    }
    let handle = try FileHandle(forReadingFrom: url)
    var data = Data()
    do {
      while data.count <= StudioLimits.fileBytes {
        let count = min(65_536, StudioLimits.fileBytes + 1 - data.count)
        guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
        data.append(chunk)
      }
    } catch {
      try handle.close()
      throw error
    }
    try handle.close()
    guard data.count <= StudioLimits.fileBytes else { throw StudioFailure("Il file supera 20 MB.") }
    return data
  }
}
