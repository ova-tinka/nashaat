import Darwin
import Foundation

@main struct MacHostsTransactionCheck {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
    try store.recoverInterruptedTransactions()
    precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".bloom-hosts").path))
    let path = root.appendingPathComponent("hosts")
    let original = Data("127.0.0.1 localhost\n# keep\r\n".utf8)
    try original.write(to: path)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
    let marker = Data("metadata".utf8)
    let xattrSet = marker.withUnsafeBytes { setxattr(path.path, "com.bloom.fixture", $0.baseAddress, marker.count, 0, 0) }
    precondition(xattrSet == 0)
    try store.apply(domains: ["example.com"])
    let blocked = try Data(contentsOf: path)
    precondition(blocked != original)
    let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
    precondition((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o644)
    precondition(getxattr(path.path, "com.bloom.fixture", nil, 0, 0, 0) == marker.count)
    var copiedMarker = [UInt8](repeating: 0, count: marker.count)
    let copiedLength = getxattr(path.path, "com.bloom.fixture", &copiedMarker, copiedMarker.count, 0, 0)
    precondition(copiedLength == marker.count && Data(copiedMarker) == marker)
    try store.apply(domains: ["example.com"])
    precondition((try? Data(contentsOf: path)) == blocked)
    try store.apply(domains: [])
    precondition((try? Data(contentsOf: path)) == original)
    let noOpEdit = Data("127.0.0.1 localhost\n# concurrent no-op edit\n".utf8)
    do {
      try store.apply(domains: [], beforeNoopValidation: { try noOpEdit.write(to: path) })
      preconditionFailure("concurrent no-op edit accepted")
    } catch MacHostsTransaction.Failure.changed {}
    precondition((try? Data(contentsOf: path)) == noOpEdit)
    try original.write(to: path)
    try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: path.path)
    do { try store.apply(domains: ["example.com"]); preconditionFailure("world-writable hosts accepted") } catch MacHostsTransaction.Failure.unsafeFile {}
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
    let hardLink = root.appendingPathComponent("hard-link")
    try FileManager.default.linkItem(at: path, to: hardLink)
    do { try store.apply(domains: ["example.com"]); preconditionFailure("hard-linked hosts accepted") } catch MacHostsTransaction.Failure.unsafeFile {}
    try FileManager.default.removeItem(at: hardLink)
    let chmod = Process()
    chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
    chmod.arguments = ["+a", "everyone allow read", path.path]
    chmod.standardOutput = Pipe(); chmod.standardError = Pipe()
    try chmod.run(); chmod.waitUntilExit(); precondition(chmod.terminationStatus == 0)
    do { try store.apply(domains: ["example.com"]); preconditionFailure("ACL on hosts accepted") } catch MacHostsTransaction.Failure.unsafeFile {}
    let clearACL = Process()
    clearACL.executableURL = URL(fileURLWithPath: "/bin/chmod")
    clearACL.arguments = ["-N", path.path]
    clearACL.standardOutput = Pipe(); clearACL.standardError = Pipe()
    try clearACL.run(); clearACL.waitUntilExit(); precondition(clearACL.terminationStatus == 0)

    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      defer { done.signal() }
      try! store.apply(domains: ["example.com"], beforeCommit: { started.signal(); release.wait() })
    }
    precondition(started.wait(timeout: .now() + 5) == .success)
    do { try store.apply(domains: []); preconditionFailure("concurrent helper accepted") } catch MacHostsTransaction.Failure.busy {}
    release.signal()
    precondition(done.wait(timeout: .now() + 5) == .success)
    try store.apply(domains: [])
    precondition((try? Data(contentsOf: path)) == original)

    enum Abort: Error { case interrupted }
    let staging = root.appendingPathComponent(".bloom-hosts", isDirectory: true)
    func preservedConflict() throws -> URL {
      let files = try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("conflict-") && $0.pathExtension == "hosts" }
      precondition(files.count == 1)
      return files[0]
    }
    do { try store.apply(domains: ["example.com"], beforeCommit: { throw Abort.interrupted }); preconditionFailure("interruption accepted") } catch Abort.interrupted {}
    precondition((try? Data(contentsOf: path)) == original)
    do { try store.apply(domains: ["example.com"], afterCommit: { throw Abort.interrupted }); preconditionFailure("interruption accepted") } catch Abort.interrupted {}
    let heldHosts = root.appendingPathComponent("held-hosts")
    try FileManager.default.moveItem(at: path, to: heldHosts)
    do { try store.recoverInterruptedTransactions(); preconditionFailure("unreviewed backup accepted") } catch MacHostsTransaction.Failure.recoveryRequired {}
    try FileManager.default.moveItem(at: heldHosts, to: path)
    let interruptedBackup = try preservedConflict()
    precondition((try? Data(contentsOf: interruptedBackup)) == original)
    do { try store.apply(domains: []); preconditionFailure("unreviewed conflict accepted") } catch MacHostsTransaction.Failure.recoveryRequired {}
    try FileManager.default.removeItem(at: interruptedBackup) // Simulates administrator review in the fixture.
    try store.apply(domains: ["example.com"])
    precondition((try? Data(contentsOf: path)) == blocked)
    try store.apply(domains: [])
    precondition((try? Data(contentsOf: path)) == original)
    let orphan = staging.appendingPathComponent("txn-\(UUID().uuidString.lowercased()).tmp")
    try Data("partial".utf8).write(to: orphan)
    try store.apply(domains: [])
    precondition(!FileManager.default.fileExists(atPath: orphan.path))
    let stagedID = UUID().uuidString.lowercased()
    let pending = staging.appendingPathComponent("pending-fixture")
    try Data("partial staged data".utf8).write(to: pending)
    let pendingAttributes = try FileManager.default.attributesOfItem(atPath: pending.path)
    let pendingInode = (pendingAttributes[.systemFileNumber] as! NSNumber).uint64Value
    let stagedOrphan = staging.appendingPathComponent("txn-\(stagedID)-\(pendingInode).tmp")
    try FileManager.default.moveItem(at: pending, to: stagedOrphan)
    try store.apply(domains: [])
    precondition(!FileManager.default.fileExists(atPath: stagedOrphan.path))
    let outside = root.appendingPathComponent("unrelated")
    try Data("untouched".utf8).write(to: outside)
    let maliciousOrphan = staging.appendingPathComponent("txn-\(UUID().uuidString.lowercased()).tmp")
    try FileManager.default.createSymbolicLink(at: maliciousOrphan, withDestinationURL: outside)
    do { try store.apply(domains: []); preconditionFailure("unsafe orphan accepted") } catch MacHostsTransaction.Failure.unsafeFile {}
    precondition((try? Data(contentsOf: outside)) == Data("untouched".utf8))
    try FileManager.default.removeItem(at: maliciousOrphan)
    let external = Data("127.0.0.1 localhost\n# another editor\n".utf8)
    do {
      try store.apply(domains: ["example.com"], beforeCommit: { try external.write(to: path) })
      preconditionFailure("concurrent edit accepted")
    } catch MacHostsTransaction.Failure.changed {}
    precondition((try? Data(contentsOf: path)) == external)
    let lastInstantEdit = Data("127.0.0.1 localhost\n# edit after final check\n".utf8)
    do {
      try store.apply(domains: ["example.com"], afterValidation: { try lastInstantEdit.write(to: path) })
      preconditionFailure("last-instant edit accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    let lastInstantBackup = try preservedConflict()
    precondition((try? Data(contentsOf: lastInstantBackup)) == lastInstantEdit)
    try lastInstantEdit.write(to: path) // Simulates administrator recovery in the fixture.
    try FileManager.default.removeItem(at: lastInstantBackup)
    let lastInstantReplacement = Data("127.0.0.1 localhost\n# replaced after final check\n".utf8)
    let replacementPath = root.appendingPathComponent("late-replacement")
    try lastInstantReplacement.write(to: replacementPath)
    do {
      try store.apply(domains: ["example.com"], afterValidation: {
        try FileManager.default.removeItem(at: path)
        try FileManager.default.moveItem(at: replacementPath, to: path)
      })
      preconditionFailure("last-instant replacement accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    let replacementBackup = try preservedConflict()
    precondition((try? Data(contentsOf: replacementBackup)) == lastInstantReplacement)
    try lastInstantReplacement.write(to: path) // Simulates administrator recovery in the fixture.
    try FileManager.default.removeItem(at: replacementBackup)
    let lateAttribute = Data("late metadata".utf8)
    do {
      try store.apply(domains: ["example.com"], afterValidation: {
        let result = lateAttribute.withUnsafeBytes { setxattr(path.path, "com.bloom.late", $0.baseAddress, lateAttribute.count, 0, 0) }
        precondition(result == 0)
      })
      preconditionFailure("last-instant metadata change accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    let metadataBackup = try preservedConflict()
    precondition(getxattr(metadataBackup.path, "com.bloom.late", nil, 0, 0, 0) == lateAttribute.count)
    try lastInstantReplacement.write(to: path)
    try FileManager.default.removeItem(at: metadataBackup)
    let heldFD = open(path.path, O_WRONLY | O_CLOEXEC)
    precondition(heldFD >= 0)
    let heldEdit = Data("127.0.0.1 localhost\n# edit through a previously opened file\n".utf8)
    do {
      try store.apply(domains: ["example.com"], afterDisplacedRead: {
        precondition(ftruncate(heldFD, 0) == 0 && lseek(heldFD, 0, SEEK_SET) == 0)
        let written = heldEdit.withUnsafeBytes { write(heldFD, $0.baseAddress, heldEdit.count) }
        precondition(written == heldEdit.count)
      })
      preconditionFailure("edit during displaced-file verification accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    close(heldFD)
    let heldBackup = try preservedConflict()
    precondition((try? Data(contentsOf: heldBackup)) == heldEdit)
    try heldEdit.write(to: path)
    try FileManager.default.removeItem(at: heldBackup)
    let afterSwapEdit = Data("127.0.0.1 localhost\n# edit after swap\n".utf8)
    do {
      try store.apply(domains: ["example.com"], afterDisplacedRead: { try afterSwapEdit.write(to: path) })
      preconditionFailure("post-swap edit accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    let afterSwapBackup = try preservedConflict()
    precondition((try? Data(contentsOf: afterSwapBackup)) == heldEdit)
    precondition((try? Data(contentsOf: path)) == afterSwapEdit)
    try FileManager.default.removeItem(at: afterSwapBackup)
    let afterSwapReplacement = root.appendingPathComponent("after-swap-replacement")
    try heldEdit.write(to: afterSwapReplacement)
    do {
      try store.apply(domains: ["example.com"], afterDisplacedRead: {
        try FileManager.default.removeItem(at: path)
        try FileManager.default.moveItem(at: afterSwapReplacement, to: path)
      })
      preconditionFailure("post-swap replacement accepted")
    } catch MacHostsTransaction.Failure.recoveryRequired {}
    let afterSwapReplacementBackup = try preservedConflict()
    precondition((try? Data(contentsOf: afterSwapReplacementBackup)) == afterSwapEdit)
    precondition((try? Data(contentsOf: path)) == heldEdit)
    try FileManager.default.removeItem(at: afterSwapReplacementBackup)
    let renamedExternal = Data("127.0.0.1 localhost\n# replacement by another editor\n".utf8)
    let replaced = root.appendingPathComponent("other-editor")
    try renamedExternal.write(to: replaced)
    do {
      try store.apply(domains: ["example.com"], beforeCommit: { try FileManager.default.removeItem(at: path); try FileManager.default.moveItem(at: replaced, to: path) })
      preconditionFailure("replacement accepted")
    } catch MacHostsTransaction.Failure.changed {}
    precondition((try? Data(contentsOf: path)) == renamedExternal)
    try FileManager.default.removeItem(at: path)
    let elsewhere = root.appendingPathComponent("elsewhere")
    try original.write(to: elsewhere)
    try FileManager.default.createSymbolicLink(at: path, withDestinationURL: elsewhere)
    do { try store.apply(domains: ["example.com"]); preconditionFailure("symlink accepted") } catch MacHostsTransaction.Failure.unsafeFile {}
    precondition((try? Data(contentsOf: elsewhere)) == original)
    print("macOS hosts transaction checks passed")
  }
}
