import Foundation
import Testing

@testable import TodoMenuApp

struct ConfigServiceTests {
  @Test func saveAndLoadRoundTripsConfiguration() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let dailyDir = root.appendingPathComponent("daily", isDirectory: true)
    let templateFile = root.appendingPathComponent("template.md")
    try FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)
    try "[[실행 허브]]\n\n### ROUTINE\n- [ ] Stretch\n".write(
      to: templateFile, atomically: true, encoding: .utf8)

    let configURL = root.appendingPathComponent("config.json")
    let service = ConfigService(configURL: configURL)
    let configuration = AppConfiguration(
      dailyNotesDirectory: dailyDir, dailyScaffoldFile: templateFile)

    try service.save(configuration)
    let loaded = try service.load()

    #expect(loaded == configuration)
  }
}
