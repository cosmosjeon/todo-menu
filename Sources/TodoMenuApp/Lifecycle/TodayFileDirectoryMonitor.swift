import Dispatch
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public final class TodayFileDirectoryMonitor {
  private let queue = DispatchQueue(label: "TodoMenu.TodayFileDirectoryMonitor")
  private var source: DispatchSourceFileSystemObject?
  private var descriptor: CInt = -1
  private var monitoredDirectoryURL: URL?

  public init() {}

  deinit {
    stop()
  }

  public func startMonitoring(directoryURL: URL, onChange: @escaping @Sendable () -> Void) {
    guard monitoredDirectoryURL != directoryURL || source == nil else { return }
    stop()

    let descriptor = open(directoryURL.path, O_EVTONLY)
    guard descriptor >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .delete, .rename, .extend, .attrib],
      queue: queue
    )

    source.setEventHandler(handler: onChange)
    source.setCancelHandler {
      close(descriptor)
    }
    source.resume()

    self.descriptor = descriptor
    self.source = source
    self.monitoredDirectoryURL = directoryURL
  }

  public func stop() {
    source?.cancel()
    source = nil
    descriptor = -1
    monitoredDirectoryURL = nil
  }
}
