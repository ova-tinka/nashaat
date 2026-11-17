import Foundation

@main struct MacHostsHelperCheck {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let hosts = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n".utf8)
    try original.write(to: hosts)
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    let auth = Data(repeating: 42, count: 32)
    let request = try JSONEncoder().encode(["example.com"])
    let helper = MacHostsHelper(authorize: { $0 == auth }, apply: { try store.setPersistentDomains($0) })
    let id = MacPolicyBrokerAccessPolicy.hostIdentifier
    let peerUID: UInt32 = 501
    precondition(helper.update(peerIdentifier: "untrusted", peerUID: peerUID, authorization: auth, encodedDomains: request) == "denied")
    precondition(helper.update(peerIdentifier: id, peerUID: 0, authorization: auth, encodedDomains: request) == "denied")
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: Data(), encodedDomains: request) == "denied")
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: Data(repeating: 43, count: 32), encodedDomains: request) == "denied")
    precondition((try? Data(contentsOf: hosts)) == original)
    precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".bloom-hosts").path))
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: auth, encodedDomains: Data("[invalid".utf8)) == "invalid")
    let invalid = try JSONEncoder().encode(["https://example.com/path"])
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: auth, encodedDomains: invalid) == "invalid")
    precondition((try? Data(contentsOf: hosts)) == original)
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: auth, encodedDomains: request) == "updated")
    precondition((try? Data(contentsOf: hosts)) != original)
    try original.write(to: hosts)
    try store.reconcilePersistentDomains()
    precondition((try? Data(contentsOf: hosts)) != original)
    precondition(helper.update(peerIdentifier: id, peerUID: peerUID, authorization: auth, encodedDomains: Data("[]".utf8)) == "updated")
    precondition((try? Data(contentsOf: hosts)) == original)
    let needsRecovery = MacHostsHelper(authorize: { $0 == auth }, apply: { _ in throw MacHostsTransaction.Failure.recoveryRequired })
    precondition(needsRecovery.update(peerIdentifier: id, peerUID: peerUID, authorization: auth, encodedDomains: request) == "recoveryRequired")
    print("macOS hosts helper isolation checks passed")
  }
}
