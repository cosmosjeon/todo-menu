import Foundation

public struct TodayFileResolution: Equatable, Sendable {
  public let date: Date
  public let fileURL: URL
  public let exists: Bool
}

public struct TodayFileResolver {
  public let calendar: Calendar
  public let fileManager: FileManager

  public init(calendar: Calendar = .current, fileManager: FileManager = .default) {
    self.calendar = calendar
    self.fileManager = fileManager
  }

  public func fileName(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return "\(formatter.string(from: date)) TODO.md"
  }

  public func resolve(for date: Date, in directory: URL) -> TodayFileResolution {
    let fileURL = directory.appendingPathComponent(fileName(for: date), isDirectory: false)
    return TodayFileResolution(
      date: date, fileURL: fileURL, exists: fileManager.fileExists(atPath: fileURL.path))
  }
}
