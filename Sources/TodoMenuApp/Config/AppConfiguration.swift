import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
  public var dailyNotesDirectory: URL
  public var dailyScaffoldFile: URL?
  public var lastUsedSection: ManagedSection

  public init(
    dailyNotesDirectory: URL,
    dailyScaffoldFile: URL? = nil,
    lastUsedSection: ManagedSection = .others
  ) {
    self.dailyNotesDirectory = dailyNotesDirectory
    self.dailyScaffoldFile = dailyScaffoldFile
    self.lastUsedSection = lastUsedSection
  }
}
