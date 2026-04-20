import Foundation

public struct DailyFileBootstrapper {
  public let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  public func ensureTodayFile(
    at url: URL,
    scaffoldURL: URL?,
    sections: [ManagedSection] = ManagedSection.defaultOrder
  ) throws -> Bool {
    if fileManager.fileExists(atPath: url.path) {
      return false
    }

    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let document = buildDocument(scaffoldURL: scaffoldURL, sections: sections)
    try atomicWrite(document, to: url)
    return true
  }

  func buildDocument(scaffoldURL: URL?, sections: [ManagedSection]) -> String {
    guard let scaffoldURL else {
      return buildDefaultDocument(sections: sections)
    }

    guard let text = try? String(contentsOf: scaffoldURL, encoding: .utf8) else {
      return buildDefaultDocument(sections: sections)
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return buildDefaultDocument(sections: sections)
    }
    return trimmed + "\n"
  }

  func buildDefaultDocument(sections: [ManagedSection]) -> String {
    var chunks: [String] = ["[[실행 허브]]"]

    for section in sections {
      chunks.append(section.headingLine)
    }

    return
      chunks
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n") + "\n"
  }

  func atomicWrite(_ document: String, to url: URL) throws {
    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(UUID().uuidString).tmp")
    try document.write(to: tempURL, atomically: true, encoding: .utf8)
    _ = try fileManager.replaceItemAt(
      url, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
  }
}
