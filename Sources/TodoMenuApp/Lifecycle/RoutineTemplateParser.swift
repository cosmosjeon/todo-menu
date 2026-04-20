import Foundation

public struct RoutineTemplateParser {
  public init() {}

  public func parseItems(from text: String) -> [TodoItem] {
    text
      .split(whereSeparator: \.isNewline)
      .compactMap { rawLine in
        let line = String(rawLine).trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("- [") else { return nil }
        if line.hasPrefix("- [ ] ") {
          return TodoItem(text: String(line.dropFirst(6)), isChecked: false)
        }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
          return TodoItem(text: String(line.dropFirst(6)), isChecked: true)
        }
        return nil
      }
  }

  public func parseItems(fromFile url: URL) throws -> [TodoItem] {
    let text = try String(contentsOf: url, encoding: .utf8)
    return parseItems(from: text)
  }
}
