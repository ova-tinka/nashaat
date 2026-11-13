import Foundation

/// Serializes host mutations and their reported state inside the broker. The
/// filesystem lock also protects against another broker process during upgrade.
final class MacHostsRecoveryCoordinator {
  private let queue = DispatchQueue(label: "com.focusflow.hosts.recovery", qos: .utility)
  private let recover: () throws -> Void
  private let reconcile: () throws -> Void
  private var restoreStatus = "busy"
  private var timer: DispatchSourceTimer?
  private var generation: UInt64 = 0

  init(recover: @escaping () throws -> Void, reconcile: @escaping () throws -> Void) {
    self.recover = recover
    self.reconcile = reconcile
  }

  func inspect(_ operation: @escaping () -> String, reply: @escaping (String) -> Void) {
    queue.async { reply(operation()) }
  }

  func currentGeneration(reply: @escaping (UInt64) -> Void) {
    queue.async { reply(self.generation) }
  }

  func update(expectedGeneration: UInt64? = nil, _ operation: @escaping () -> String, reply: @escaping (String) -> Void) {
    queue.async {
      guard expectedGeneration == nil || expectedGeneration == self.generation else { reply("stale"); return }
      let result = operation()
      if ["updated", "uncertain", "recoveryRequired", "unsafe", "unavailable"].contains(result) {
        self.generation &+= 1
      }
      switch result {
      case "updated": self.restoreStatus = "clear"
      case "recoveryRequired": self.restoreStatus = "review"
      case "unsafe": self.restoreStatus = "unsafe"
      case "busy", "denied", "invalid", "expired", "stale", "inactive", "unchanged", "needsEnrollment": break
      case "uncertain":
        self.restoreStatus = "unavailable"
        self.restore { _ in }
      default: self.restoreStatus = "unavailable"
      }
      reply(result)
    }
  }

  func restore(reply: @escaping (String) -> Void) {
    queue.async {
      let status = MacHostsRecovery.status(self.reconcile)
      if status == "busy" {
        self.queue.asyncAfter(deadline: .now() + 3) { self.restore(reply: reply) }
      } else {
        self.restoreStatus = status
        reply(status)
      }
    }
  }

  /// The daemon, not the app window, restores rules when a saved access
  /// window expires. The filesystem operation remains serialized with updates.
  func startMonitoring() {
    queue.async { [self] in
      guard self.timer == nil else { return }
      let timer = DispatchSource.makeTimerSource(queue: self.queue)
      timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
      timer.setEventHandler { [weak self] in
        guard let self else { return }
        let status = MacHostsRecovery.status(self.reconcile)
        if status != "busy" { self.restoreStatus = status }
      }
      self.timer = timer
      timer.resume()
    }
  }

  func check(reply: @escaping (String) -> Void) {
    queue.async {
      let status = MacHostsRecovery.status(self.recover)
      if status == "clear" && self.restoreStatus != "clear" {
        self.restoreStatus = MacHostsRecovery.status(self.reconcile)
      }
      reply(status == "clear" ? self.restoreStatus : status)
    }
  }
}
