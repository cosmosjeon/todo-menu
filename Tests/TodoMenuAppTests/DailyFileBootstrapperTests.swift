import Foundation
import Testing

@testable import TodoMenuApp

struct DailyFileBootstrapperTests {
  @Test func createsTodayFileWithPreambleAndRoutineMaterialization() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let dailyURL = root.appendingPathComponent("2026-04-20 TODO.md")
    let routineURL = root.appendingPathComponent("routine.md")
    let scaffoldURL = root.appendingPathComponent("scaffold.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "- [ ] Stretch\n- [ ] Review day\n".write(to: routineURL, atomically: true, encoding: .utf8)
    try "[[실행 허브]]\n\n### ROUTINE\n- [ ] old\n".write(
      to: scaffoldURL, atomically: true, encoding: .utf8)

    let bootstrapper = DailyFileBootstrapper()
    let created = try bootstrapper.ensureTodayFile(
      at: dailyURL, scaffoldURL: scaffoldURL, routineTemplateURL: routineURL)
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
    let routineURL = root.appendingPathComponent("routine.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "- [ ] Stretch\n".write(to: routineURL, atomically: true, encoding: .utf8)
    try "existing\n".write(to: dailyURL, atomically: true, encoding: .utf8)

    let bootstrapper = DailyFileBootstrapper()
    let created = try bootstrapper.ensureTodayFile(
      at: dailyURL, scaffoldURL: nil, routineTemplateURL: routineURL)
    let text = try String(contentsOf: dailyURL, encoding: .utf8)

    #expect(created == false)
    #expect(text == "existing\n")
  }
}
