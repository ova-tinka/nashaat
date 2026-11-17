import Foundation

@main struct MacHostsLifecycleCheck {
  @MainActor static func main() throws {
    let gate = MacHostsLifecycleGate()
    try gate.acquire()
    do { try gate.acquire(); preconditionFailure("overlapping transition accepted") }
    catch MacHostsLifecycleGate.GateError.busy {}
    gate.release()
    try gate.acquire()
    gate.release()
    precondition(MacHostsFallbackDecision.decide(status: "enrolled", expected: false, starting: true) == .use)
    precondition(MacHostsFallbackDecision.decide(status: "enrolledEmpty", expected: true, starting: false) == .use)
    precondition(MacHostsFallbackDecision.decide(status: "notConfigured", expected: true, starting: true) == .skip)
    precondition(MacHostsFallbackDecision.decide(status: "unavailable", expected: true, starting: true) == .unavailable)
    precondition(MacHostsFallbackDecision.decide(status: "unavailable", expected: false, starting: true) == .skip)
    precondition(MacHostsFallbackDecision.decide(status: "otherAccount", expected: true, starting: true) == .otherAccount)
    precondition(MacHostsFallbackDecision.decide(status: "otherAccount", expected: true, starting: false) == .skip)
    precondition(MacHostsFallbackDecision.decide(status: "cleanupPending", expected: false, starting: true) == .unavailable)
    for status in ["enrolled", "enrolledEmpty", "otherAccount", "needsEnrollment", "cleanupPending", "review", "unsafe", "busy"] {
      precondition(MacHostsFallbackDecision.shouldRemember(status: status), "\(status) must be remembered before broker loss")
    }
    precondition(!MacHostsFallbackDecision.shouldRemember(status: "notConfigured"))
    precondition(!MacHostsFallbackDecision.shouldRemember(status: "unavailable"))
    print("macOS hosts lifecycle checks passed")
  }
}
