import Foundation
import ServiceManagement

/// Registration is performed only from the explicit website-filter setup
/// action. macOS requires admin approval before this root broker can run.
@MainActor final class BloomPolicyBrokerController {
  static let shared = BloomPolicyBrokerController()
  static let plistName = "com.focusflow.focusFlowFlutter.policy-broker.plist"
  private let registrationFingerprintKey = "policyBrokerRegisteredExecutableFingerprint"

  private var service: SMAppService { SMAppService.daemon(plistName: Self.plistName) }

  func status() -> String {
    switch service.status {
    case .enabled: return "active"
    case .requiresApproval: return "needsApproval"
    case .notRegistered: return "notRegistered"
    case .notFound: return "notFound"
    @unknown default: return "unavailable"
    }
  }

  func ensureRegistered(forceRefresh: Bool = false) async throws -> String {
    let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/\(Self.plistName)")
    let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/BloomPolicyBroker")
    guard FileManager.default.isReadableFile(atPath: plist.path),
          FileManager.default.isExecutableFile(atPath: executable.path) else { return "notFound" }
    let fingerprint = try MacServiceRegistrationPolicy.fingerprint(at: executable)
    let wasRegistered = service.status == .enabled || service.status == .requiresApproval
    var refreshed = false
    if (forceRefresh && wasRegistered) || MacServiceRegistrationPolicy.shouldRefresh(isRegistered: wasRegistered,
      registeredFingerprint: UserDefaults.standard.string(forKey: registrationFingerprintKey),
      currentFingerprint: fingerprint) {
      UserDefaults.standard.removeObject(forKey: registrationFingerprintKey)
      try await service.unregister()
      refreshed = true
      for _ in 0..<20 {
        let current = service.status
        if current != .enabled && current != .requiresApproval { break }
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    let current = service.status
    if current != .enabled && current != .requiresApproval {
      do {
        try service.register()
      } catch {
        guard refreshed else { throw error }
        try? await Task.sleep(nanoseconds: 250_000_000)
        try service.register()
      }
    }
    for _ in 0..<20 {
      let registered = service.status
      if registered != .notFound && registered != .notRegistered {
        if registered == .enabled || registered == .requiresApproval {
          UserDefaults.standard.set(fingerprint, forKey: registrationFingerprintKey)
        }
        return status()
      }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    if service.status == .enabled || service.status == .requiresApproval {
      UserDefaults.standard.set(fingerprint, forKey: registrationFingerprintKey)
    }
    return status()
  }
}
