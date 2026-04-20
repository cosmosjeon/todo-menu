import Foundation

@MainActor
public final class DayRolloverCoordinator {
  private var timer: Timer?
  private var lastObservedDay: Date
  private let calendar: Calendar
  private let onDateBoundary: @MainActor () -> Void

  public init(
    calendar: Calendar = .current, now: Date = .now, onDateBoundary: @escaping @MainActor () -> Void
  ) {
    self.calendar = calendar
    self.lastObservedDay = calendar.startOfDay(for: now)
    self.onDateBoundary = onDateBoundary
  }

  public func start() {
    stop()
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh(now: .now)
      }
    }
  }

  public func refresh(now: Date = .now) {
    let currentDay = calendar.startOfDay(for: now)
    guard currentDay != lastObservedDay else { return }
    lastObservedDay = currentDay
    onDateBoundary()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
