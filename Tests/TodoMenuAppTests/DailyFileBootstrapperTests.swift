import Foundation
import Testing

@testable import TodoMenuApp

struct DailyFileBootstrapperTests {
  @Test func createsTodayFileFromSingleTemplate() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let dailyURL = root.appendingPathComponent("2026-04-20 TODO.md")
    let scaffoldURL = root.appendingPathComponent("template.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try """
      [[실행 허브]]

      ### ROUTINE
      - [ ] Stretch
      - [ ] Review day

      ### SLIT

      ### SPEC

      ### OTHERS
      """.write(
      to: scaffoldURL, atomically: true, encoding: .utf8)

    let bootstrapper = DailyFileBootstrapper()
    let created = try bootstrapper.ensureTodayFile(
      at: dailyURL, scaffoldURL: scaffoldURL)
    let text = try String(contentsOf: dailyURL, encoding: .utf8)

    #expect(created)
    #expect(text.contains("[[실행 허브]]"))
    #expect(text.contains("### ROUTINE"))
    #expect(text.contains("- [ ] Stretch"))
    #expect(text.contains("### OTHERS"))
  }

  @Test func existingFileIsNotOverwrittenOrReinjected() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let dailyURL = root.appendingPathComponent("2026-04-20 TODO.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "existing\n".write(to: dailyURL, atomically: true, encoding: .utf8)

    let bootstrapper = DailyFileBootstrapper()
    let created = try bootstrapper.ensureTodayFile(
      at: dailyURL, scaffoldURL: nil)
    let text = try String(contentsOf: dailyURL, encoding: .utf8)

    #expect(created == false)
    #expect(text == "existing\n")
  }
}
