import Darwin
import Foundation

@main struct MacHostsPersistentCheck {
  static func main() throws {
    if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "child" {
      let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
      let point = CommandLine.arguments[3]
      let domains = point.hasPrefix("cleanup") ? [] : ["example.com"]
      let crash = { _ = kill(getpid(), SIGKILL) }
      if point == "cleanup-complete" {
        try MacHostsTransaction(directory: root, expectedOwner: getuid()).setPersistentDomains([])
        return
      }
      if point == "window-after-policy" {
        try MacHostsTransaction(directory: root, expectedOwner: getuid()).installVerifiedWindow(ownerUID: 501,
          profileID: "10000000-0000-4000-8000-000000000001", sessionID: "20000000-0000-4000-8000-000000000002",
          boot: 7, now: 1000, deadline: 5000, afterWindowCommit: crash)
        preconditionFailure("child did not stop")
      }
      try MacHostsTransaction(directory: root, expectedOwner: getuid()).setPersistentDomains(domains,
        afterFenceCommit: point.hasSuffix("after-fence") ? crash : nil,
        beforePolicyCommit: point.hasSuffix("before-policy") ? crash : nil,
        afterPolicyCommit: point.hasSuffix("after-policy") ? crash : nil,
        afterHostsApply: point.hasSuffix("after-hosts") ? crash : nil)
      preconditionFailure("child did not stop")
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let path = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n# preserved fixture\n".utf8)
    try original.write(to: path)
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    try store.reconcilePersistentDomains()
    precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".bloom-hosts").path))
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: "10000000-0000-4000-8000-000000000001",
        sessionID: "20000000-0000-4000-8000-000000000002", boot: 7, now: 1000, deadline: 5000)
      preconditionFailure("missing policy accepted")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    func interrupt(_ operation: String) throws {
      let child = Process()
      child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      child.arguments = ["child", root.path, operation]
      child.standardOutput = Pipe(); child.standardError = Pipe()
      try child.run(); child.waitUntilExit()
      precondition(child.terminationReason == .uncaughtSignal && child.terminationStatus == SIGKILL)
    }
    let beforeCrashFence = try store.currentPolicyFence()
    try interrupt("enable-after-fence")
    precondition((try? Data(contentsOf: path)) == original)
    let afterCrashFence = try store.currentPolicyFence()
    precondition(beforeCrashFence != afterCrashFence)
    do {
      try store.setPersistentDomains(["example.com"], expectedFence: beforeCrashFence)
      preconditionFailure("crashed update did not invalidate older request")
    } catch MacHostsTransaction.Failure.stale {}
    try interrupt("enable-before-policy")
    try store.reconcilePersistentDomains()
    precondition((try? Data(contentsOf: path)) == original)
    let staging = root.appendingPathComponent(".bloom-hosts")
    let stagedFiles = try FileManager.default.contentsOfDirectory(atPath: staging.path)
    precondition(!stagedFiles.contains { $0.hasPrefix("policy-") && $0.hasSuffix(".tmp") })
    try interrupt("enable-after-policy")
    precondition((try? Data(contentsOf: path)) == original)
    try store.reconcilePersistentDomains()
    let blocked = try Data(contentsOf: path)
    precondition(blocked != original)
    try original.write(to: path)
    try store.reconcilePersistentDomains()
    precondition((try? Data(contentsOf: path)) == blocked)
    try interrupt("cleanup-before-policy")
    try store.reconcilePersistentDomains()
    precondition((try? Data(contentsOf: path)) == blocked)
    try interrupt("cleanup-after-policy")
    precondition((try? Data(contentsOf: path)) == blocked)
    try store.reconcilePersistentDomains()
    precondition((try? Data(contentsOf: path)) == original)
    let policy = root.appendingPathComponent(".bloom-hosts/desired-policy.json")
    precondition(!FileManager.default.fileExists(atPath: policy.path))
    try store.setPersistentDomains(["example.com"])
    try interrupt("cleanup-after-hosts")
    precondition((try? Data(contentsOf: path)) == original)
    precondition(FileManager.default.fileExists(atPath: policy.path))
    try store.reconcilePersistentDomains()
    precondition(!FileManager.default.fileExists(atPath: policy.path))
    let profile = "10000000-0000-4000-8000-000000000001"
    let staleEnrollmentFence = try store.currentPolicyFence()
    let cleanup = Process()
    cleanup.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    cleanup.arguments = ["child", root.path, "cleanup-complete"]
    cleanup.standardOutput = Pipe(); cleanup.standardError = Pipe()
    try cleanup.run(); cleanup.waitUntilExit()
    precondition(cleanup.terminationStatus == 0)
    do {
      try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile, expectedFence: staleEnrollmentFence)
      preconditionFailure("stale enrollment survived another process cleanup")
    } catch MacHostsTransaction.Failure.stale {}
    precondition((try? Data(contentsOf: path)) == original)
    let session = "20000000-0000-4000-8000-000000000002"
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile)
    let staleWindowFence = try store.currentPolicyFence()
    try store.setPersistentDomains([])
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile)
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session,
        boot: 7, now: 1000, deadline: 5000, expectedFence: staleWindowFence)
      preconditionFailure("stale window survived cleanup and re-enrollment")
    } catch MacHostsTransaction.Failure.stale {}
    do {
      try store.installVerifiedWindow(ownerUID: 502, profileID: profile, sessionID: session, boot: 7, now: 1000, deadline: 5000)
      preconditionFailure("wrong Mac owner accepted")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: "30000000-0000-4000-8000-000000000003", sessionID: session, boot: 7, now: 1000, deadline: 5000)
      preconditionFailure("wrong profile accepted")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    precondition((try? Data(contentsOf: path)) == blocked)
    try interrupt("window-after-policy")
    precondition((try? Data(contentsOf: path)) == blocked)
    try store.reconcilePersistentDomains(now: 2000, boot: 7)
    precondition((try? Data(contentsOf: path)) == original && FileManager.default.fileExists(atPath: policy.path))
    // Retrying a grant cannot extend its original deadline.
    try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session, boot: 7, now: 2000, deadline: 9000)
    try store.reconcilePersistentDomains(now: 4999, boot: 7)
    precondition((try? Data(contentsOf: path)) == original)
    try store.reconcilePersistentDomains(now: 5000, boot: 7)
    precondition((try? Data(contentsOf: path)) == blocked)
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session, boot: 7, now: 2000, deadline: 9000)
      preconditionFailure("expired grant reopened")
    } catch MacHostsTransaction.Failure.invalidGrant {}
    let nextSession = "40000000-0000-4000-8000-000000000004"
    try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: nextSession, boot: 7, now: 2000, deadline: 5000)
    precondition((try? Data(contentsOf: path)) == original)
    try store.reconcilePersistentDomains(now: 2000, boot: 8)
    precondition((try? Data(contentsOf: path)) == blocked)
    try store.reconcilePersistentDomains(now: nil, boot: nil)
    precondition((try? Data(contentsOf: path)) == blocked)
    try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: policy.path)
    do { try store.reconcilePersistentDomains(); preconditionFailure("unsafe policy accepted") }
    catch MacHostsTransaction.Failure.unsafeFile {}
    precondition((try? Data(contentsOf: path)) == blocked)
    print("macOS persistent hosts policy checks passed")
  }
}
