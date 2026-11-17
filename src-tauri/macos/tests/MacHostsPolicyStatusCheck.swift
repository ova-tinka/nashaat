import Darwin
import Foundation

@main struct MacHostsPolicyStatusCheck {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let hosts = root.appendingPathComponent("hosts")
    try Data("127.0.0.1 localhost\n".utf8).write(to: hosts)
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    let profile = "10000000-0000-4000-8000-000000000001"
    func status(_ uid: UInt32 = 501, _ id: String? = nil) throws -> String {
      try store.policyStatus(ownerUID: uid, profileID: id ?? profile)
    }
    let missing = try status()
    precondition(missing == "notConfigured")
    precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".bloom-hosts").path))
    try store.setPersistentDomains(["legacy.example.com"])
    let legacy = try status()
    precondition(legacy == "needsEnrollment")
    try store.setPersistentDomains(["legacy.example.com"], ownerUID: 501, profileID: profile)
    let ownedLegacy = try status()
    let other = try status(502)
    precondition(ownedLegacy == "needsEnrollment" && other == "otherAccount")
    let enrollmentFence = try store.enrollmentFence(ownerUID: 501, profileID: profile, now: 1000, boot: 7)
    precondition(!enrollmentFence.isEmpty)
    do {
      _ = try store.enrollmentFence(ownerUID: 502, profileID: profile, now: 1000, boot: 7)
      preconditionFailure("another account captured the enrollment fence")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    do {
      try store.setPersistentDomains(["replacement.example.com"], ownerUID: 502,
        profileID: "20000000-0000-4000-8000-000000000002", expectedFence: enrollmentFence,
        manualDomains: ["replacement.example.com"], managedDomains: [], now: 1000, boot: 7)
      preconditionFailure("another account replaced the enrolled policy")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile,
      manualDomains: ["example.com"], managedDomains: [])
    let enrolled = try status()
    precondition(enrolled == "enrolled")
    try store.setPersistentDomains([], ownerUID: 501, profileID: profile, manualDomains: [], managedDomains: [])
    let empty = try status()
    precondition(empty == "enrolledEmpty")
    enum Interrupt: Error { case stopped }
    do {
      try store.setPersistentDomains([], afterPolicyCommit: { throw Interrupt.stopped })
      preconditionFailure("interruption ignored")
    } catch Interrupt.stopped {}
    let pending = try status()
    precondition(pending == "cleanupPending")
    do {
      _ = try store.enrollmentFence(ownerUID: 501, profileID: profile, now: 1000, boot: 7)
      preconditionFailure("cleanup-pending policy was enrolled over")
    } catch MacHostsTransaction.Failure.needsEnrollment {}
    try store.reconcilePersistentDomains()
    let cleaned = try status()
    precondition(cleaned == "notConfigured")
    print("macOS hosts policy status checks passed")
  }
}
