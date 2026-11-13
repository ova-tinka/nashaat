import Foundation

@main struct MacHostsRecoveryCoordinatorCheck {
  static func main() {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let lock = NSLock()
    var calls: [String] = []
    func record(_ value: String) { lock.lock(); calls.append(value); lock.unlock() }
    let coordinator = MacHostsRecoveryCoordinator(recover: { record("recover") }, reconcile: { record("reconcile") })
    coordinator.restore { status in precondition(status == "clear"); finished.signal() }
    precondition(finished.wait(timeout: .now() + 5) == .success)
    coordinator.update({
      record("update-start"); started.signal(); release.wait(); record("update-end")
      return "recoveryRequired"
    }, reply: { result in precondition(result == "recoveryRequired"); finished.signal() })
    precondition(started.wait(timeout: .now() + 5) == .success)
    coordinator.check { status in precondition(status == "clear"); finished.signal() }
    release.signal()
    precondition(finished.wait(timeout: .now() + 5) == .success)
    precondition(finished.wait(timeout: .now() + 5) == .success)
    lock.lock(); let observed = calls; lock.unlock()
    precondition(observed == ["reconcile", "update-start", "update-end", "recover", "reconcile"])
    coordinator.update({ "uncertain" }, reply: { _ in finished.signal() })
    precondition(finished.wait(timeout: .now() + 5) == .success)
    coordinator.check { status in precondition(status == "clear"); finished.signal() }
    precondition(finished.wait(timeout: .now() + 5) == .success)
    var generation: UInt64 = 0
    coordinator.currentGeneration { value in generation = value; finished.signal() }
    precondition(finished.wait(timeout: .now() + 5) == .success)
    coordinator.update({ "updated" }, reply: { _ in finished.signal() })
    precondition(finished.wait(timeout: .now() + 5) == .success)
    coordinator.update(expectedGeneration: generation, { preconditionFailure("stale enrollment ran") }, reply: {
      precondition($0 == "stale"); finished.signal()
    })
    precondition(finished.wait(timeout: .now() + 5) == .success)
    let tick = DispatchSemaphore(value: 0)
    let monitor = MacHostsRecoveryCoordinator(recover: {}, reconcile: { tick.signal() })
    monitor.startMonitoring()
    precondition(tick.wait(timeout: .now() + 5) == .success)
    print("macOS hosts recovery coordination checks passed")
  }
}
