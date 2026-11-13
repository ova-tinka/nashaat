import Darwin
import Foundation

@main struct MacHostsEarlyCloseCheck {
  static let profile = "10000000-0000-4000-8000-000000000001"
  static let session = "20000000-0000-4000-8000-000000000002"
  static func main() throws {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "child" {
      let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
      try MacHostsTransaction(directory: root, expectedOwner: getuid()).closeVerifiedWindow(ownerUID: 501,
        profileID: profile, sessionID: session, afterCloseCommit: { _ = kill(getpid(), SIGKILL) })
      preconditionFailure("close did not stop")
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let hosts = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n".utf8)
    try original.write(to: hosts)
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    let initiallyClosed = try store.closeVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session)
    precondition(!initiallyClosed)
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile)
    let blocked = try Data(contentsOf: hosts)
    let pendingFence = try store.policyFenceForOwner(ownerUID: 501, profileID: profile)
    do {
      _ = try store.closeVerifiedWindow(ownerUID: 502, profileID: profile, sessionID: session)
      preconditionFailure("other Mac user closed window")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    let closed = try store.closeVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session)
    precondition(closed)
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session,
        boot: 7, now: 1000, deadline: 5000, expectedFence: pendingFence)
      preconditionFailure("in-flight window reopened after close")
    } catch MacHostsTransaction.Failure.stale {}
    do {
      try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session, boot: 7, now: 1000, deadline: 5000)
      preconditionFailure("closed session reopened")
    } catch MacHostsTransaction.Failure.invalidGrant {}
    // Re-enrollment simulates a new configured policy and a new access window.
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile)
    try store.installVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session, boot: 7, now: 1000, deadline: 5000)
    do {
      _ = try store.closeVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: "30000000-0000-4000-8000-000000000003")
      preconditionFailure("another session closed current window")
    } catch MacHostsTransaction.Failure.invalidGrant {}
    precondition((try? Data(contentsOf: hosts)) == original)
    let child = Process()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["child", root.path]
    child.standardOutput = Pipe(); child.standardError = Pipe()
    try child.run(); child.waitUntilExit()
    precondition(child.terminationReason == .uncaughtSignal && child.terminationStatus == SIGKILL)
    precondition((try? Data(contentsOf: hosts)) == original)
    try store.reconcilePersistentDomains(now: 2000, boot: 7)
    precondition((try? Data(contentsOf: hosts)) == blocked)
    let closedAgain = try store.closeVerifiedWindow(ownerUID: 501, profileID: profile, sessionID: session)
    precondition(closedAgain)
    print("macOS early hosts window close checks passed")
  }
}
