import Foundation

public struct DailyFileBootstrapper {
  public let fileManager: FileManager
  public let parser: RoutineTemplateParser

  public init(
    fileManager: FileManager = .default, parser: RoutineTemplateParser = RoutineTemplateParser()
  ) {
    self.fileManager = fileManager
    self.parser = parser
  }

  public func ensureTodayFile(
    at url: URL,
    scaffoldURL: URL?,
    routineTemplateURL: URL,
    sections: [ManagedSection] = ManagedSection.defaultOrder
  ) throws -> Bool {
    if fileManager.fileExists(atPath: url.path) {
      return false
    }

    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let routineItems = try parser.parseItems(fromFile: routineTemplateURL)
    let preamble = try scaffoldPreamble(from: scaffoldURL)
    let document = buildDocument(preamble: preamble, routineItems: routineItems, sections: sections)
    try atomicWrite(document, to: url)
    return true
  }

  func scaffoldPreamble(from scaffoldURL: URL?) throws -> String {
    guard let scaffoldURL else {
      return "[[실행 허브]]"
    }

    let text = try String(contentsOf: scaffoldURL, encoding: .utf8)
    let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    let headingSet = Set(ManagedSection.defaultOrder.map(\.headingLine))

    let preambleLines = lines.prefix { line in
      !headingSet.contains(String(line).trimmingCharacters(in: .whitespaces))
    }

    let joined = preambleLines.map(String.init).joined(separator: "\n").trimmingCharacters(
      in: CharacterSet.whitespacesAndNewlines)
    return joined.isEmpty ? "[[실행 허브]]" : joined
  }

  func buildDocument(preamble: String, routineItems: [TodoItem], sections: [ManagedSection])
    -> String
  {
    var chunks: [String] = [preamble.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)]

    for section in sections {
      var lines: [String] = [section.headingLine]
      if section == .routine {
        let materialized = routineItems.map(\.markdownLine)
        lines.append(
          contentsOf: materialized.isEmpty ? ["- [ ] Routine placeholder"] : materialized)
      }
      chunks.append(lines.joined(separator: "\n"))
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
