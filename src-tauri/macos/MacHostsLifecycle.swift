import Foundation

/// Serializes user-initiated native transitions across suspension points.
@MainActor final class MacHostsLifecycleGate {
  static let shared = MacHostsLifecycleGate()
  enum GateError: LocalizedError {
    case busy
    var errorDescription: String? { "Another protection update is in progress. Try again shortly." }
  }
  private var locked = false
  func acquire() throws {
    guard !locked else { throw GateError.busy }
    locked = true
  }

  func release() {
    precondition(locked)
    locked = false
  }
}

enum MacHostsFallbackDecision: Equatable {
  case use, skip, unavailable, otherAccount
  static func decide(status: String, expected: Bool, starting: Bool) -> Self {
    switch status {
    case "enrolled", "enrolledEmpty": return .use
    case "notConfigured": return .skip
    case "otherAccount": return starting ? .otherAccount : .skip
    case "unavailable": return expected ? .unavailable : .skip
    default: return .unavailable
    }
  }

  static func shouldRemember(status: String) -> Bool {
    status != "notConfigured" && status != "unavailable"
  }
}
