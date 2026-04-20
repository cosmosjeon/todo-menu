import Foundation

public enum ManagedSection: String, CaseIterable, Codable, Sendable {
  case routine = "ROUTINE"
  case slit = "SLIT"
  case spec = "SPEC"
  case others = "OTHERS"

  public static let defaultOrder: [ManagedSection] = [.routine, .slit, .spec, .others]

  public var headingLine: String { "### \(rawValue)" }
}

public struct TodoItem: Equatable, Codable, Sendable, Identifiable {
  public let id: UUID
  public var text: String
  public var isChecked: Bool

  public init(id: UUID = UUID(), text: String, isChecked: Bool = false) {
    self.id = id
    self.text = text
    self.isChecked = isChecked
  }

  public var markdownLine: String {
    "- [\(isChecked ? "x" : " ")] \(text)"
  }
}
