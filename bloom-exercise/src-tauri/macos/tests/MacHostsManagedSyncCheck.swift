import Darwin
import Foundation

@main struct MacHostsManagedSyncCheck {
  static let profile = "10000000-0000-4000-8000-000000000001"
  static let session = "20000000-0000-4000-8000-000000000002"
  static func main() throws {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "child" {
      let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
      let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
      let fence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
      try store.syncManagedDomains(["parent3.example.com"], ownerUID: 501, profileID: profile,
        expectedFence: fence, now: 3000, boot: 7, afterPolicyCommit: { _ = kill(getpid(), SIGKILL) })
      preconditionFailure("child did not stop")
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let hosts = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n# other rules\n".utf8)
    try original.write(to: hosts)
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    let manual = ["manual.example.com", "shared.example.com"]
    let managed = ["parent1.example.com", "shared.example.com"]
    try store.setPersistentDomains(Array(Set(manual + managed)).sorted(), ownerUID: 501, profileID: profile,
      manualDomains: manual, managedDomains: managed)
    let originalFence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    let unchanged = try store.syncManagedDomains(managed.reversed().map { $0 }, ownerUID: 501,
      profileID: profile, expectedFence: originalFence, now: 1000, boot: 7)
    let unchangedFence = try store.currentPolicyFence()
    precondition(!unchanged && unchangedFence == originalFence)
    do {
      _ = try store.syncManagedDomains(["parent2.example.com"], ownerUID: 502, profileID: profile,
        expectedFence: originalFence, now: 1000, boot: 7)
      preconditionFailure("other owner synced rules")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session,
      boot: 7, now: 1000, deadline: 5000, expectedFence: originalFence)
    precondition((try? Data(contentsOf: hosts)) == original)
    let activeFence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    let changed = try store.syncManagedDomains(["parent2.example.com"], ownerUID: 501, profileID: profile,
      expectedFence: activeFence, now: 2000, boot: 7)
    precondition(changed && (try? Data(contentsOf: hosts)) == original)
    do {
      _ = try store.syncManagedDomains(["parent1.example.com"], ownerUID: 501, profileID: profile,
        expectedFence: activeFence, now: 2000, boot: 7)
      preconditionFailure("stale parent snapshot accepted")
    } catch MacHostsTransaction.Failure.stale {}
    let child = Process()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["child", root.path]
    child.standardOutput = Pipe(); child.standardError = Pipe()
    try child.run(); child.waitUntilExit()
    precondition(child.terminationReason == .uncaughtSignal && child.terminationStatus == SIGKILL)
    try store.reconcilePersistentDomains(now: 3000, boot: 7)
    precondition((try? Data(contentsOf: hosts)) == original)
    try store.reconcilePersistentDomains(now: 5000, boot: 7)
    let expected = try MacHostsPolicy.transform(original, domains: manual + ["parent3.example.com"])
    precondition((try? Data(contentsOf: hosts)) == expected)
    try store.setPersistentDomains(["legacy.example.com"], ownerUID: 501, profileID: profile)
    let legacyFence = try store.currentPolicyFence()
    do {
      _ = try store.syncManagedDomains([], ownerUID: 501, profileID: profile, expectedFence: legacyFence, now: 6000, boot: 7)
      preconditionFailure("legacy policy silently lost its rules")
    } catch MacHostsTransaction.Failure.needsEnrollment {}
    try store.setPersistentDomains(["parent-only.example.com"], ownerUID: 501, profileID: profile,
      manualDomains: [], managedDomains: ["parent-only.example.com"])
    let parentOnlyFence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    let nextSession = "30000000-0000-4000-8000-000000000003"
    try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: nextSession,
      boot: 7, now: 6000, deadline: 10000, expectedFence: parentOnlyFence)
    let beforeEmpty = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    _ = try store.syncManagedDomains([], ownerUID: 501, profileID: profile, expectedFence: beforeEmpty, now: 7000, boot: 7)
    precondition((try? Data(contentsOf: hosts)) == original)
    let emptyFence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    _ = try store.syncManagedDomains(["later.example.com"], ownerUID: 501, profileID: profile,
      expectedFence: emptyFence, now: 8000, boot: 7)
    precondition((try? Data(contentsOf: hosts)) == original)
    try store.reconcilePersistentDomains(now: 10000, boot: 7)
    let expectedLater = try MacHostsPolicy.transform(original, domains: ["later.example.com"])
    precondition((try? Data(contentsOf: hosts)) == expectedLater)
    print("macOS managed hosts synchronization checks passed")
  }
}
