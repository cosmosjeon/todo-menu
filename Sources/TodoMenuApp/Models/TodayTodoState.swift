import Foundation
import TodoDomain

public struct TodayTodoItem: Equatable, Sendable, Identifiable {
  public let reference: TodoItemReference
  public let text: String
  public let isChecked: Bool

  public init(reference: TodoItemReference, text: String, isChecked: Bool) {
    self.reference = reference
    self.text = text
    self.isChecked = isChecked
  }

  public var id: String {
    [
      reference.sectionName,
      String(reference.occurrenceIndex),
      reference.normalizedText,
      reference.isChecked ? "1" : "0",
    ].joined(separator: "::")
  }
}

public struct TodayTodoSection: Equatable, Sendable, Identifiable {
  public let section: ManagedSection
  public let items: [TodayTodoItem]

  public init(section: ManagedSection, items: [TodayTodoItem]) {
    self.section = section
    self.items = items
  }

  public init(name: String, items: [TodayTodoItem]) {
    self.section = ManagedSection(rawValue: name) ?? .others
    self.items = items
  }

  public var id: String { section.rawValue }
  public var name: String { section.rawValue }
}
