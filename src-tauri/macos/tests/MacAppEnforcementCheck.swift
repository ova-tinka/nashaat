import Foundation

@main struct MacAppEnforcementCheck {
  static func main() {
    var monitor = MacAppEnforcement(running: [1, 2])
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 0) == [.warn(1)])
    precondition(monitor.hasWarnings && monitor.hasUnconfirmedApps)
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 29_999).isEmpty)
    precondition(monitor.update(running: [1, 2, 3], blocked: [1, 3], now: 30_000) == [.quit(1), .quit(3)])
    precondition(!monitor.hasWarnings && monitor.hasUnconfirmedApps)
    precondition(monitor.update(running: [1, 2, 3], blocked: [1, 3], now: 32_000) == [.forceQuit(1), .forceQuit(3)])
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 37_000) == [.forceQuit(1)])
    precondition(monitor.update(running: [1, 2], blocked: [], now: 38_000).isEmpty)
    precondition(!monitor.hasUnconfirmedApps)
    // An access window ending makes a still-running process eligible for a new warning.
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 39_000) == [.warn(1)])
    monitor.restartWarnings(now: 100_000)
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 129_999).isEmpty)
    precondition(monitor.update(running: [1, 2], blocked: [1], now: 130_000) == [.quit(1)])
    precondition(monitor.update(running: [2], blocked: [], now: 131_000).isEmpty)
    precondition(!monitor.hasUnconfirmedApps)
    print("macOS app enforcement lifecycle checks passed")
  }
}
