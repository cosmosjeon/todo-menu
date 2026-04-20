import Foundation

public struct ConfigService {
  public enum ConfigError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidDirectory(URL)
    case invalidScaffold(URL)

    public var errorDescription: String? {
      switch self {
      case .missingConfiguration:
        return "Choose a daily notes folder and optionally a daily template to get started."
      case .invalidDirectory(let url):
        return "Daily notes folder does not exist: \(url.path)"
      case .invalidScaffold(let url):
        return "Daily template file does not exist: \(url.path)"
      }
    }
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  public let configURL: URL
  private let fileManager: FileManager

  public init(configURL: URL, fileManager: FileManager = .default) {
    self.configURL = configURL
    self.fileManager = fileManager
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  public static func defaultConfigURL(fileManager: FileManager = .default) -> URL {
    let baseDirectory =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Application Support", isDirectory: true)
    return
      baseDirectory
      .appendingPathComponent("TodoMenu", isDirectory: true)
      .appendingPathComponent("config.json", isDirectory: false)
  }

  public func load() throws -> AppConfiguration {
    guard fileManager.fileExists(atPath: configURL.path) else {
      throw ConfigError.missingConfiguration
    }

    let data = try Data(contentsOf: configURL)
    return try decoder.decode(AppConfiguration.self, from: data)
  }

  public func save(_ configuration: AppConfiguration) throws {
    try validate(configuration)
    try fileManager.createDirectory(
      at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode(configuration)
    try data.write(to: configURL, options: .atomic)
  }

  public func validate(_ configuration: AppConfiguration) throws {
    var isDirectory: ObjCBool = false
    guard
      fileManager.fileExists(
        atPath: configuration.dailyNotesDirectory.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ConfigError.invalidDirectory(configuration.dailyNotesDirectory)
    }
    if let scaffold = configuration.dailyScaffoldFile,
      !fileManager.fileExists(atPath: scaffold.path)
    {
      throw ConfigError.invalidScaffold(scaffold)
    }
  }
}
