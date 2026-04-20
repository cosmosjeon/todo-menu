import Foundation
import Testing

@testable import TodoMenuApp

struct TodayFileResolverTests {
  @Test func fileNameUsesLocalCalendarDate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let resolver = TodayFileResolver(calendar: calendar)
    let date = ISO8601DateFormatter().date(from: "2026-04-20T05:00:00Z")!

    #expect(resolver.fileName(for: date) == "2026-04-20 TODO.md")
  }

  @Test func resolveCreatesExpectedURL() {
    let directory = URL(fileURLWithPath: "/tmp/dailies", isDirectory: true)
    let resolver = TodayFileResolver()
    let date = ISO8601DateFormatter().date(from: "2026-04-20T00:00:00Z")!

    let resolution = resolver.resolve(for: date, in: directory)

    #expect(resolution.fileURL.path.hasSuffix("TODO.md"))
    #expect(resolution.fileURL.deletingLastPathComponent() == directory)
  }
}
