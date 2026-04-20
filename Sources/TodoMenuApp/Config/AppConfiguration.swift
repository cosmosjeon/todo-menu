import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
  public var dailyNotesDirectory: URL
  public var routineTemplateFile: URL
  public var dailyScaffoldFile: URL?
  public var lastUsedSection: ManagedSection

  public init(
    dailyNotesDirectory: URL,
    routineTemplateFile: URL,
    dailyScaffoldFile: URL? = nil,
    lastUsedSection: ManagedSection = .others
  ) {
    self.dailyNotesDirectory = dailyNotesDirectory
    self.routineTemplateFile = routineTemplateFile
    self.dailyScaffoldFile = dailyScaffoldFile
    self.lastUsedSection = lastUsedSection
  }
}
