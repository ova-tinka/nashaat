import Darwin
import Foundation

@main struct MacHostsVerifiedUsageCheck {
  static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let path = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n".utf8)
    try original.write(to: path)
    let profile = "10000000-0000-4000-8000-000000000001"
    let session = "20000000-0000-4000-8000-000000000002"
    let device = "30000000-0000-4000-8000-000000000003"
    let request = try JSONSerialization.data(withJSONObject: ["profileID": profile, "sessionID": session,
      "deviceKey": device, "accessToken": "synthetic-token"])
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    try store.setPersistentDomains(["example.com"], ownerUID: 501, profileID: profile)
    var clock = 1000.0
    var calls = 0
    let verifier = MacHostsVerifiedUsage(transaction: store, verify: { _, _, _, _, _ in
      calls += 1; clock = 2000
      return VerifiedUsageGrant(sessionId: session, budgetMillis: 10000, remainingMillis: 5000)
    }, now: { clock }, boot: { 7 })
    do {
      _ = try await verifier.prepare(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: 502, data: request)
      preconditionFailure("other user reached verification")
    } catch MacHostsTransaction.Failure.wrongOwner {}
    precondition(calls == 0)
    do {
      _ = try await verifier.prepare(peerIdentifier: "untrusted", peerUID: 501, data: request)
      preconditionFailure("other executable reached verification")
    } catch SupabaseUsageGrantError.rejected {}
    precondition(calls == 0)
    let prepared = try await verifier.prepare(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: 501, data: request)
    precondition(calls == 1 && prepared.deadline == 6000 && prepared.boot == 7)
    try store.installVerifiedWindow(ownerUID: prepared.ownerUID, profileID: prepared.profileID,
      sessionID: prepared.sessionID, boot: prepared.boot, now: clock, deadline: prepared.deadline, expectedFence: prepared.policyFence)
    precondition((try? Data(contentsOf: path)) == original)
    do {
      _ = try store.enrollmentFence(ownerUID: 501, profileID: profile, now: clock, boot: 7)
      preconditionFailure("enrollment interrupted an active access window")
    } catch MacHostsTransaction.Failure.invalidGrant {}
    try store.reconcilePersistentDomains(now: 6000, boot: 7)
    precondition((try? Data(contentsOf: path)) != original)
    let expired = MacHostsVerifiedUsage(transaction: store, verify: { _, _, _, _, _ in
      clock = 10000
      return VerifiedUsageGrant(sessionId: session, budgetMillis: 10000, remainingMillis: 1000)
    }, now: { clock }, boot: { 7 })
    do {
      _ = try await expired.prepare(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: 501, data: request)
      preconditionFailure("grant expired during verification accepted")
    } catch SupabaseUsageGrantError.expired {}
    var bootValue: Int64 = 7
    clock = 1000
    let rebooted = MacHostsVerifiedUsage(transaction: store, verify: { _, _, _, _, _ in
      bootValue = 8
      return VerifiedUsageGrant(sessionId: session, budgetMillis: 10000, remainingMillis: 5000)
    }, now: { clock }, boot: { bootValue })
    do {
      _ = try await rebooted.prepare(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: 501, data: request)
      preconditionFailure("grant across reboot accepted")
    } catch SupabaseUsageGrantError.expired {}
    clock = 1000
    let requestID = "40000000-0000-4000-8000-000000000004"
    let countdownRequest = try JSONSerialization.data(withJSONObject: ["kind": "countdown", "requestID": requestID,
      "profileID": profile, "deviceKey": device, "accessToken": "synthetic-token"])
    let countdownVerifier = MacHostsVerifiedUsage(transaction: store, verify: { kind, identifier, _, _, _ in
      precondition(kind == "countdown" && identifier == requestID)
      return VerifiedUsageGrant(sessionId: session, budgetMillis: 86400000, remainingMillis: 5000)
    }, now: { clock }, boot: { 7 })
    let countdown = try await countdownVerifier.prepare(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier,
      peerUID: 501, data: countdownRequest)
    precondition(countdown.sessionID == session && countdown.deadline == 6000)
    print("macOS verified hosts usage checks passed")
  }
}
