import Foundation
import Testing
import TodoDomain

@testable import TodoMenuApp

@MainActor
struct AppModelTests {
  @Test func refreshTodayFileCreatesDocumentForInjectedDate() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    let dailyDir = root.appendingPathComponent("daily", isDirectory: true)
    let templateFile = root.appendingPathComponent("template.md")
    let configFile = root.appendingPathComponent("config.json")
    try FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)
    try """
      [[실행 허브]]

      ### ROUTINE
      - [ ] Stretch

      ### SLIT

      ### SPEC

      ### OTHERS
      """.write(to: templateFile, atomically: true, encoding: .utf8)

    let configService = ConfigService(configURL: configFile)
    try configService.save(
      AppConfiguration(
        dailyNotesDirectory: dailyDir,
        dailyScaffoldFile: templateFile
      )
    )

    let fixedDate = ISO8601DateFormatter().date(from: "2026-04-20T00:00:00Z")!
    let model = AppModel(
      configService: configService,
      resolver: TodayFileResolver(),
      bootstrapper: DailyFileBootstrapper(),
      mutationService: TodoFileMutationService(),
      fileMonitor: TodayFileDirectoryMonitor(),
      nowProvider: { fixedDate }
    )

    model.loadConfiguration()
    model.refreshTodayFile()

    #expect(model.todayFileURL?.lastPathComponent == "2026-04-20 TODO.md")
    #expect(model.didCreateTodayFile)
    #expect(model.statusMessage == "Created today's file and materialized routines.")
    #expect(try String(contentsOf: model.todayFileURL!, encoding: .utf8).contains("- [ ] Stretch"))
    #expect(model.todaySections.map(\.name) == ["ROUTINE", "SLIT", "SPEC", "OTHERS"])
    #expect(model.todaySections.first?.items.map(\.text) == ["Stretch"])
  }

  @Test func toggleItemUpdatesFileAndLastUsedSection() throws {
    let harness = try makeHarness(contents: fixture(named: "canonical-full"))
    let model = harness.model

    let target = try #require(model.todaySections.first(where: { $0.name == "ROUTINE" })?.items.first)
    let didToggle = model.toggleItem(reference: target.reference)
    let saved = try harness.loadConfig()
    let fileContents = try String(contentsOf: harness.todayFileURL, encoding: .utf8)

    #expect(didToggle)
    #expect(saved.lastUsedSection == .routine)
    #expect(model.todaySections.first(where: { $0.name == "ROUTINE" })?.items.first?.isChecked == true)
    #expect(fileContents.contains("- [x] Morning review"))
  }

  @Test func addItemUsesLastUsedSectionAndPersistsIt() throws {
    let harness = try makeHarness(contents: fixture(named: "canonical-empty-sections"), lastUsedSection: .spec)
    let model = harness.model

    let didAdd = model.addItem(text: "Draft acceptance notes")
    let saved = try harness.loadConfig()
    let fileContents = try String(contentsOf: harness.todayFileURL, encoding: .utf8)

    #expect(didAdd)
    #expect(saved.lastUsedSection == .spec)
    #expect(model.todaySections.first(where: { $0.name == "SPEC" })?.items.map(\.text) == ["Draft acceptance notes"])
    #expect(fileContents.contains("### SPEC\n- [ ] Draft acceptance notes"))
  }

  @Test func staleToggleRefreshesModelInsteadOfMutatingWrongItem() throws {
    let harness = try makeHarness(contents: fixture(named: "ambiguous-duplicate-same-section"))
    let model = harness.model

    let original = try #require(model.todaySections.first(where: { $0.name == "SLIT" })?.items.last)
    try fixture(named: "conflict-reordered-lines").write(to: harness.todayFileURL, atomically: true, encoding: .utf8)

    let didToggle = model.toggleItem(reference: original.reference)
    let reloadedTexts = model.todaySections.first(where: { $0.name == "SLIT" })?.items.map(\.text) ?? []
    let fileContents = try String(contentsOf: harness.todayFileURL, encoding: .utf8)

    #expect(didToggle == false)
    #expect(model.statusMessage == "File changed externally. Refreshed to latest content.")
    #expect(reloadedTexts == ["Third item now moved first", "First item now moved second", "Second item now moved third"])
    #expect(fileContents.contains("- [ ] Third item now moved first"))
  }

  @Test func reloadTodayDocumentFromDiskPicksUpExternalEdit() throws {
    let harness = try makeHarness(contents: fixture(named: "canonical-full"))
    let model = harness.model

    try fixture(named: "conflict-external-edit-text-and-state").write(
      to: harness.todayFileURL,
      atomically: true,
      encoding: .utf8
    )

    try model.reloadTodayDocumentFromDiskForTesting(status: "Refreshed from disk.")

    #expect(model.statusMessage == "Refreshed from disk.")
    #expect(model.todaySections.first(where: { $0.name == "ROUTINE" })?.items.first?.text == "Review plan updated externally")
    #expect(model.todaySections.first(where: { $0.name == "ROUTINE" })?.items.first?.isChecked == true)
  }

  @Test func saveConfigurationSurfacesValidationError() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    let configService = ConfigService(configURL: root.appendingPathComponent("config.json"))
    let model = AppModel(configService: configService)

    model.dailyNotesDirectoryText = root.appendingPathComponent("missing-daily").path
    model.saveConfiguration()

    #expect(model.configuration == nil)
    #expect(model.statusMessage.contains("Daily notes folder does not exist"))
  }

  private func makeHarness(
    contents: String,
    lastUsedSection: ManagedSection = .others
  ) throws -> (model: AppModel, todayFileURL: URL, loadConfig: () throws -> AppConfiguration) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    let dailyDir = root.appendingPathComponent("daily", isDirectory: true)
    let configFile = root.appendingPathComponent("config.json")
    try FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)

    let configService = ConfigService(configURL: configFile)
    try configService.save(
      AppConfiguration(
        dailyNotesDirectory: dailyDir,
        lastUsedSection: lastUsedSection
      )
    )

    let fixedDate = ISO8601DateFormatter().date(from: "2026-04-20T00:00:00Z")!
    let todayFileURL = TodayFileResolver().resolve(for: fixedDate, in: dailyDir).fileURL
    try contents.write(to: todayFileURL, atomically: true, encoding: .utf8)

    let model = AppModel(
      configService: configService,
      resolver: TodayFileResolver(),
      bootstrapper: DailyFileBootstrapper(),
      mutationService: TodoFileMutationService(),
      fileMonitor: TodayFileDirectoryMonitor(),
      nowProvider: { fixedDate }
    )
    model.loadConfiguration()
    model.refreshTodayFile()

    return (model, todayFileURL, { try configService.load() })
  }

  private func fixture(named name: String) -> String {
    let resourceURL = Bundle.module.resourceURL!
    return try! String(contentsOf: resourceURL.appendingPathComponent("\(name).md"), encoding: .utf8)
  }
}
