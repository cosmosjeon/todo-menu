import AppKit
import Foundation
import Observation
import TodoDomain

@MainActor
@Observable
public final class AppModel {
  public private(set) var configuration: AppConfiguration?
  public private(set) var todayFileURL: URL?
  public private(set) var statusMessage =
    "Configure a daily notes folder and optionally a daily template to begin."
  public private(set) var didCreateTodayFile = false
  public private(set) var todaySections: [TodayTodoSection] = []
  public private(set) var todaySnapshot: TodoDocumentSnapshot?

  public var dailyNotesDirectoryText = ""
  public var quickAddText = ""
  public var quickAddSection: ManagedSection = .others
  public var dailyScaffoldFileText = ""

  private let configService: ConfigService
  private let resolver: TodayFileResolver
  private let bootstrapper: DailyFileBootstrapper
  private let mutationService: TodoFileMutationService
  private let nowProvider: () -> Date
  private let fileMonitor: TodayFileDirectoryMonitor
  private var rolloverCoordinator: DayRolloverCoordinator?

  public init(
    configService: ConfigService = ConfigService(configURL: ConfigService.defaultConfigURL()),
    resolver: TodayFileResolver = TodayFileResolver(),
    bootstrapper: DailyFileBootstrapper = DailyFileBootstrapper(),
    mutationService: TodoFileMutationService = TodoFileMutationService(),
    fileMonitor: TodayFileDirectoryMonitor = TodayFileDirectoryMonitor(),
    nowProvider: @escaping () -> Date = { .now }
  ) {
    self.configService = configService
    self.resolver = resolver
    self.bootstrapper = bootstrapper
    self.mutationService = mutationService
    self.fileMonitor = fileMonitor
    self.nowProvider = nowProvider
  }

  public func start() {
    loadConfiguration()
    configureRolloverIfNeeded()
    refreshTodayFile()
  }

  public func loadConfiguration() {
    do {
      let configuration = try configService.load()
      self.configuration = configuration
      quickAddSection = configuration.lastUsedSection
      syncTextFields(with: configuration)
      statusMessage = "Configuration loaded."
    } catch {
      configuration = nil
      statusMessage = error.localizedDescription
      todaySections = []
      todaySnapshot = nil
      stopMonitoringTodayFile()
    }
  }

  public func saveConfiguration() {
    do {
      let configuration = AppConfiguration(
        dailyNotesDirectory: URL(fileURLWithPath: dailyNotesDirectoryText),
        dailyScaffoldFile: dailyScaffoldFileText.isEmpty
          ? nil : URL(fileURLWithPath: dailyScaffoldFileText),
        lastUsedSection: configuration?.lastUsedSection ?? quickAddSection
      )
      try configService.save(configuration)
      self.configuration = configuration
      statusMessage = "Configuration saved."
      refreshTodayFile()
    } catch {
      statusMessage = error.localizedDescription
    }
  }

  public func refreshTodayFile() {
    guard let configuration else {
      todaySections = []
      todaySnapshot = nil
      todayFileURL = nil
      stopMonitoringTodayFile()
      return
    }

    let resolution = resolver.resolve(for: nowProvider(), in: configuration.dailyNotesDirectory)
    do {
      didCreateTodayFile = try bootstrapper.ensureTodayFile(
        at: resolution.fileURL,
        scaffoldURL: configuration.dailyScaffoldFile
      )
      todayFileURL = resolution.fileURL
      let baseStatus = didCreateTodayFile
        ? "Created today's file and materialized routines."
        : "Using today's existing file."
      try reloadTodayDocument(from: resolution.fileURL, status: baseStatus)
      startMonitoringTodayFile(at: resolution.fileURL)
    } catch {
      todayFileURL = resolution.fileURL
      todaySections = []
      todaySnapshot = nil
      statusMessage = error.localizedDescription
    }
  }

  public func reloadTodayDocumentFromDiskForTesting(status: String = "Refreshed from disk.") throws {
    guard let todayFileURL else { return }
    try reloadTodayDocument(from: todayFileURL, status: status)
  }

  public func addQuickItem() {
    guard addItem(text: quickAddText, preferredSection: quickAddSection) else { return }
    quickAddText = ""
  }

  @discardableResult
  public func addItem(text: String, preferredSection: ManagedSection? = nil) -> Bool {
    guard let todayFileURL, let snapshot = todaySnapshot else {
      statusMessage = "No today file loaded."
      return false
    }

    do {
      let result = try mutationService.addItem(
        at: todayFileURL,
        request: TodoAddRequest(
          text: text,
          preferredSection: preferredSection?.rawValue,
          lastUsedSection: configuration?.lastUsedSection.rawValue
        ),
        expectedFingerprint: snapshot.fingerprint
      )
      apply(snapshot: result.snapshot)
      persistLastUsedSection(named: result.reference.sectionName)
      statusMessage = "Added todo to \(result.reference.sectionName)."
      return true
    } catch {
      handleMutationError(error)
      return false
    }
  }

  @discardableResult
  public func toggleItem(_ item: TodayTodoItem) -> Bool {
    toggleItem(reference: item.reference)
  }

  @discardableResult
  public func toggleItem(reference: TodoItemReference) -> Bool {
    guard let todayFileURL, let snapshot = todaySnapshot else {
      statusMessage = "No today file loaded."
      return false
    }

    do {
      let updated = try mutationService.toggleItem(
        at: todayFileURL,
        target: reference,
        expectedFingerprint: snapshot.fingerprint
      )
      apply(snapshot: updated)
      persistLastUsedSection(named: reference.sectionName)
      statusMessage = "Updated \(reference.sectionName)."
      return true
    } catch {
      handleMutationError(error)
      return false
    }
  }

  public func openTodayFile() {
    guard let todayFileURL else { return }
    NSWorkspace.shared.open(todayFileURL)
  }

  public func revealDailyDirectory() {
    guard let configuration else { return }
    NSWorkspace.shared.activateFileViewerSelecting([configuration.dailyNotesDirectory])
  }

  public func pickDailyNotesDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK {
      dailyNotesDirectoryText = panel.url?.path ?? dailyNotesDirectoryText
    }
  }

  public func pickDailyScaffoldFile() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    if panel.runModal() == .OK {
      dailyScaffoldFileText = panel.url?.path ?? dailyScaffoldFileText
    }
  }

  private func reloadTodayDocument(from url: URL, status: String) throws {
    let snapshot = try mutationService.loadDocument(at: url)
    apply(snapshot: snapshot)
    statusMessage = status
  }

  private func apply(snapshot: TodoDocumentSnapshot) {
    todaySnapshot = snapshot
    todaySections = makeSections(from: snapshot.document)
  }

  private func makeSections(from document: TodoDocument) -> [TodayTodoSection] {
    let pairs: [(ManagedSection, TodayTodoSection)] = document.sections.compactMap { section in
      guard let managed = ManagedSection(rawValue: section.name) else { return nil }
      return (
        managed,
        TodayTodoSection(
          section: managed,
          items: section.checklistItems.map {
            TodayTodoItem(reference: $0.reference, text: $0.text, isChecked: $0.isChecked)
          }
        )
      )
    }
    let grouped = Dictionary(uniqueKeysWithValues: pairs)

    return ManagedSection.defaultOrder.map { section in
      grouped[section] ?? TodayTodoSection(section: section, items: [])
    }
  }

  private func persistLastUsedSection(named name: String) {
    guard let section = ManagedSection(rawValue: name), var configuration else { return }
    guard configuration.lastUsedSection != section else { return }

    configuration.lastUsedSection = section
    do {
      try configService.save(configuration)
      self.configuration = configuration
      quickAddSection = configuration.lastUsedSection
    } catch {
      statusMessage = error.localizedDescription
    }
  }

  private func handleMutationError(_ error: Error) {
    switch error {
    case TodoMutationError.itemResolutionFailed, TodoMutationError.ambiguousItem, TodoMutationError.staleSnapshot:
      do {
        try reloadTodayDocumentFromDiskForTesting(status: "File changed externally. Refreshed to latest content.")
      } catch {
        statusMessage = error.localizedDescription
      }
    default:
      statusMessage = error.localizedDescription
    }
  }

  private func startMonitoringTodayFile(at fileURL: URL) {
    fileMonitor.startMonitoring(directoryURL: fileURL.deletingLastPathComponent()) { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        guard self.todayFileURL == fileURL else { return }
        do {
          try self.reloadTodayDocument(from: fileURL, status: "Refreshed from disk.")
        } catch {
          self.statusMessage = error.localizedDescription
        }
      }
    }
  }

  private func stopMonitoringTodayFile() {
    fileMonitor.stop()
  }

  private func syncTextFields(with configuration: AppConfiguration) {
    dailyNotesDirectoryText = configuration.dailyNotesDirectory.path
    dailyScaffoldFileText = configuration.dailyScaffoldFile?.path ?? ""
  }

  private func configureRolloverIfNeeded() {
    guard rolloverCoordinator == nil else { return }
    let coordinator = DayRolloverCoordinator { [weak self] in
      self?.refreshTodayFile()
    }
    coordinator.start()
    rolloverCoordinator = coordinator

    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.rolloverCoordinator?.refresh()
        self?.refreshTodayFile()
      }
    }
  }
}
