import Foundation

/// Tracks individual processes so an already-open app receives a warning,
/// while later launches are asked to quit promptly. A request is not proof of
/// termination: callers must continue to report degradation while it runs.
struct MacAppEnforcement {
  enum Action: Equatable { case warn(Int32), quit(Int32), forceQuit(Int32) }
  private enum Phase { case warning(Double), quitting(Double), forcing(Double) }
  private var phases: [Int32: Phase] = [:]
  private var known: Set<Int32>

  init(running: Set<Int32>) { known = running }

  mutating func update(running: Set<Int32>, blocked: Set<Int32>, now: Double) -> [Action] {
    phases = phases.filter { running.contains($0.key) && blocked.contains($0.key) }
    var actions: [Action] = []
    for pid in blocked.intersection(running).sorted() {
      switch phases[pid] {
      case nil:
        if known.contains(pid) {
          phases[pid] = .warning(now + 30_000)
          actions.append(.warn(pid))
        } else {
          phases[pid] = .quitting(now + 2_000)
          actions.append(.quit(pid))
        }
      case .warning(let deadline) where now >= deadline:
        phases[pid] = .quitting(now + 2_000)
        actions.append(.quit(pid))
      case .quitting(let deadline) where now >= deadline:
        phases[pid] = .forcing(now + 5_000)
        actions.append(.forceQuit(pid))
      case .forcing(let retry) where now >= retry:
        phases[pid] = .forcing(now + 5_000)
        actions.append(.forceQuit(pid))
      default: break
      }
    }
    known = running
    return actions
  }

  var hasWarnings: Bool { phases.values.contains { if case .warning = $0 { return true }; return false } }
  var hasUnconfirmedApps: Bool { !phases.isEmpty }

  // A warning cannot be relied on while the session is asleep or inactive.
  mutating func restartWarnings(now: Double) {
    for (pid, phase) in phases {
      if case .warning = phase { phases[pid] = .warning(now + 30_000) }
    }
  }
}
