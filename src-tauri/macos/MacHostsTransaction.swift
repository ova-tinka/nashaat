import Darwin
import Foundation

/// The caller supplies a fixed, trusted directory; no path comes from XPC.
/// The production helper must use /private/etc and expectedOwner 0.
struct MacHostsTransaction {
  enum Failure: Error { case unsafeDirectory, unsafeFile, busy, io, changed, commitUncertain, recoveryRequired, wrongOwner, invalidGrant, stale, needsEnrollment }
  private static let staging = ".bloom-hosts"
  private static let lockName = "lock"
  private static let hostName = "hosts"
  private static let desiredName = "desired-policy.json"
  private static let fenceName = "policy-fence"
  let directory: URL
  let expectedOwner: uid_t

  func apply(domains: [String], afterStageCreated: (() throws -> Void)? = nil, beforeCommit: (() throws -> Void)? = nil, afterValidation: (() throws -> Void)? = nil, afterCommit: (() throws -> Void)? = nil, afterDisplacedRead: (() throws -> Void)? = nil, beforeNoopValidation: (() throws -> Void)? = nil) throws {
    try withLockedDirectory(create: true) { dir, work in
      try applyLocked(domains: domains, dir: dir, work: work, afterStageCreated: afterStageCreated,
        beforeCommit: beforeCommit, afterValidation: afterValidation, afterCommit: afterCommit,
        afterDisplacedRead: afterDisplacedRead, beforeNoopValidation: beforeNoopValidation)
    }
  }

  private func applyLocked(domains: [String], dir: Int32, work: Int32,
    afterStageCreated: (() throws -> Void)? = nil, beforeCommit: (() throws -> Void)? = nil,
    afterValidation: (() throws -> Void)? = nil, afterCommit: (() throws -> Void)? = nil,
    afterDisplacedRead: (() throws -> Void)? = nil, beforeNoopValidation: (() throws -> Void)? = nil) throws {
    try recover(in: work, hostsDirectory: dir)
    let source = openat(dir, Self.hostName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard source >= 0 else { throw Failure.unsafeFile }
    defer { close(source) }
    guard flock(source, LOCK_EX | LOCK_NB) == 0 else { throw Failure.busy }
    defer { flock(source, LOCK_UN) }
    var originalStat = stat()
    guard fstat(source, &originalStat) == 0, originalStat.st_uid == expectedOwner,
          originalStat.st_nlink == 1, (originalStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
          (originalStat.st_mode & 0o022) == 0,
          (originalStat.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0,
          noExtendedACL(source), originalStat.st_size >= 0, originalStat.st_size <= 1_048_576 else { throw Failure.unsafeFile }
    let original = try readAll(source)
    let replacement = try MacHostsPolicy.transform(original, domains: domains)
    if replacement == original {
      try beforeNoopValidation?()
      var currentPath = stat(); var currentFD = stat()
      var afterPath = stat(); var afterFD = stat()
      guard fstatat(dir, Self.hostName, &currentPath, AT_SYMLINK_NOFOLLOW) == 0,
            fstat(source, &currentFD) == 0, sameFile(originalStat, currentPath),
            sameFile(originalStat, currentFD), try readAll(source) == original,
            fstat(source, &afterFD) == 0, fstatat(dir, Self.hostName, &afterPath, AT_SYMLINK_NOFOLLOW) == 0,
            sameFile(originalStat, afterFD), sameFile(afterFD, afterPath) else { throw Failure.changed }
      return
    }
    let transactionID = UUID().uuidString.lowercased()
    var name = "txn-\(transactionID).tmp"
    let target = openat(work, name, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard target >= 0 else { throw Failure.io }
    var committed = false
    defer { close(target); if !committed { _ = unlinkat(work, name, 0) } }
    try afterStageCreated?()
    try writeAll(target, data: replacement)
    // Preserve ownership, permissions and xattrs. Extended ACLs are refused
    // above because they can grant unprivileged writers access to the source.
    guard fcopyfile(source, target, nil, copyfile_flags_t(COPYFILE_METADATA)) == 0 else { throw Failure.io }
    var copiedStat = stat()
    guard fstat(target, &copiedStat) == 0, copiedStat.st_uid == originalStat.st_uid,
          copiedStat.st_gid == originalStat.st_gid, copiedStat.st_mode == originalStat.st_mode,
          copiedStat.st_flags == originalStat.st_flags else { throw Failure.io }
    guard fsync(target) == 0, fcntl(target, F_FULLFSYNC) == 0 else { throw Failure.io }
    // The staged inode is encoded in its name. After a crash, a different
    // inode at that name means swap completed and the displaced hosts file
    // must be preserved for an administrator to review.
    let stagedName = "txn-\(transactionID)-\(copiedStat.st_ino).tmp"
    guard renameatx_np(work, name, work, stagedName, UInt32(RENAME_EXCL)) == 0 else { throw Failure.io }
    name = stagedName
    guard fsync(work) == 0 else { throw Failure.io }
    try beforeCommit?()
    var currentPath = stat()
    var currentFD = stat()
    guard fstatat(dir, Self.hostName, &currentPath, AT_SYMLINK_NOFOLLOW) == 0,
          fstat(source, &currentFD) == 0, sameFile(originalStat, currentPath), sameFile(originalStat, currentFD),
          try readAll(source) == original else { throw Failure.changed }
    try afterValidation?()
    // A swap preserves the file actually displaced, even if another editor
    // changed the path in the interval after the last pre-commit check.
    guard renameatx_np(work, name, dir, Self.hostName, UInt32(RENAME_SWAP)) == 0 else { throw Failure.io }
    committed = true
    try afterCommit?()
    // Make both sides of the swap durable before the displaced file can be
    // removed. If this fails, retain it for recovery on the next attempt.
    guard fsync(dir) == 0, fsync(work) == 0 else { throw Failure.recoveryRequired }
    let displaced = openat(work, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard displaced >= 0 else { throw Failure.recoveryRequired }
    defer { close(displaced) }
    var displacedStat = stat()
    guard fstat(displaced, &displacedStat) == 0,
          sameDisplacedFile(originalStat, displacedStat), noExtendedACL(displaced),
          let oldAttributes = extendedAttributes(displaced), let newAttributes = extendedAttributes(target),
          oldAttributes == newAttributes, try readAll(displaced) == original else {
      try preserveConflict(in: work, name: name, transactionID: transactionID)
      throw Failure.recoveryRequired
    }
    try afterDisplacedRead?()
    // Verify that the inode installed by the swap is still at the hosts
    // path and still contains the intended bytes. An editor can replace or
    // modify it while the displaced file is being checked.
    var installedStat = stat(); var installedPath = stat()
    var installedAfter = stat(); var installedPathAfter = stat()
    let installedMatches = fstat(target, &installedStat) == 0
      && fstatat(dir, Self.hostName, &installedPath, AT_SYMLINK_NOFOLLOW) == 0
      && installedStat.st_dev == copiedStat.st_dev && installedStat.st_ino == copiedStat.st_ino
      && sameFile(installedStat, installedPath)
      && installedStat.st_uid == originalStat.st_uid && installedStat.st_gid == originalStat.st_gid
      && installedStat.st_mode == originalStat.st_mode && installedStat.st_flags == originalStat.st_flags
      && installedStat.st_nlink == 1 && noExtendedACL(target)
      && extendedAttributes(target) == oldAttributes && (try? readAll(target)) == replacement
      && fstat(target, &installedAfter) == 0
      && fstatat(dir, Self.hostName, &installedPathAfter, AT_SYMLINK_NOFOLLOW) == 0
      && sameFile(installedStat, installedAfter) && sameFile(installedAfter, installedPathAfter)
    var verifiedStat = stat()
    guard installedMatches, fstat(displaced, &verifiedStat) == 0, sameFile(displacedStat, verifiedStat) else {
      try preserveConflict(in: work, name: name, transactionID: transactionID)
      throw Failure.recoveryRequired
    }
    guard unlinkat(work, name, 0) == 0 else { throw Failure.recoveryRequired }
    // An error after deletion means the change may already have committed.
    guard fsync(work) == 0 else { throw Failure.commitUncertain }
  }

  private struct PolicyOwner: Codable {
    let ownerUID: UInt32
    let profileID: String
    var isValid: Bool { ownerUID > 0 && UUID(uuidString: profileID) != nil }
    func matches(uid: UInt32, profile: String) -> Bool {
      isValid && ownerUID == uid && UUID(uuidString: profileID) == UUID(uuidString: profile)
    }
  }

  private struct AccessWindow: Codable {
    let ownerUID: UInt32
    let profileID: String
    let sessionID: String
    let boot: Int64
    let issuedMillis: Double
    let deadlineMillis: Double

    var isValid: Bool {
      ownerUID > 0 && UUID(uuidString: profileID) != nil && UUID(uuidString: sessionID) != nil && boot > 0
        && issuedMillis.isFinite && issuedMillis >= 0 && deadlineMillis.isFinite
        && deadlineMillis > issuedMillis && deadlineMillis - issuedMillis <= 604_800_000
    }

    func allows(now: Double?, boot currentBoot: Int64?) -> Bool {
      guard isValid, let now, now.isFinite, now >= issuedMillis,
            let currentBoot, currentBoot == boot else { return false }
      return now < deadlineMillis
    }
  }

  private struct DesiredPolicy: Codable {
    let version: Int
    let domains: [String]
    let manualDomains: [String]?
    let managedDomains: [String]?
    let owner: PolicyOwner?
    let access: AccessWindow?
    let completedSessionID: String?
  }

  /// Persist intent before changing hosts. A process interruption can then be
  /// replayed without depending on the app or an expiring authorization grant.
  func setPersistentDomains(_ domains: [String], ownerUID: UInt32? = nil, profileID: String? = nil, expectedFence: String? = nil,
                            manualDomains: [String]? = nil, managedDomains: [String]? = nil,
                            now: Double? = nil, boot: Int64? = nil,
                            afterFenceCommit: (() throws -> Void)? = nil, beforePolicyCommit: (() throws -> Void)? = nil,
                            afterPolicyCommit: (() throws -> Void)? = nil,
                            afterHostsApply: (() throws -> Void)? = nil) throws {
    _ = try MacHostsPolicy.transform(Data(), domains: domains)
    if let manual = manualDomains, let managed = managedDomains {
      guard Set(domains) == Set(manual + managed) else { throw Failure.invalidGrant }
      _ = try MacHostsPolicy.transform(Data(), domains: manual)
      _ = try MacHostsPolicy.transform(Data(), domains: managed)
    } else if manualDomains != nil || managedDomains != nil { throw Failure.invalidGrant }
    let owner: PolicyOwner?
    if let uid = ownerUID, let profile = profileID {
      let value = PolicyOwner(ownerUID: uid, profileID: profile)
      guard value.isValid, !domains.isEmpty || (manualDomains != nil && managedDomains != nil) else { throw Failure.invalidGrant }
      owner = value
    } else {
      guard ownerUID == nil && profileID == nil else { throw Failure.invalidGrant }
      owner = nil
    }
    guard manualDomains == nil || owner != nil else { throw Failure.invalidGrant }
    try withLockedDirectory(create: true) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      // Refuse to replace an unexpected or unsafe existing policy file.
      let current = try readDesiredPolicy(in: work)
      if let owner {
        if let currentOwner = current?.owner, !currentOwner.matches(uid: owner.ownerUID, profile: owner.profileID) {
          throw Failure.wrongOwner
        }
        if let current, current.owner == nil, current.domains.isEmpty { throw Failure.needsEnrollment }
        if let access = current?.access {
          guard let now, let boot, !access.allows(now: now, boot: boot) else { throw Failure.invalidGrant }
        }
      }
      let fence = try readOrCreateFence(in: work)
      guard expectedFence == nil || expectedFence == fence else { throw Failure.stale }
      try writeFence(in: work)
      try afterFenceCommit?()
      try writeDesiredPolicy(DesiredPolicy(version: 1, domains: domains, manualDomains: manualDomains, managedDomains: managedDomains,
        owner: owner, access: nil, completedSessionID: nil), in: work,
        beforeCommit: beforePolicyCommit, afterCommit: afterPolicyCommit)
      do {
        try applyLocked(domains: domains, dir: dir, work: work)
        try afterHostsApply?()
        if domains.isEmpty && owner == nil { try removeDesiredPolicy(in: work) }
      } catch Failure.recoveryRequired { throw Failure.recoveryRequired }
      catch { throw Failure.commitUncertain }
    }
  }

  /// Reports configuration only; it does not claim the rule is effective.
  func policyStatus(ownerUID: UInt32, profileID: String) throws -> String {
    guard ownerUID > 0, UUID(uuidString: profileID) != nil else { throw Failure.invalidGrant }
    var result = "notConfigured"
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work) else { return }
      guard let owner = policy.owner else {
        result = policy.domains.isEmpty ? "cleanupPending" : "needsEnrollment"
        return
      }
      guard owner.matches(uid: ownerUID, profile: profileID) else { result = "otherAccount"; return }
      guard policy.manualDomains != nil && policy.managedDomains != nil else { result = "needsEnrollment"; return }
      result = policy.domains.isEmpty ? "enrolledEmpty" : "enrolled"
    }
    return result
  }

  func policyFenceForOwner(ownerUID: UInt32, profileID: String) throws -> String {
    var fence: String?
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work),
            policy.owner?.matches(uid: ownerUID, profile: profileID) == true else { throw Failure.wrongOwner }
      fence = try readOrCreateFence(in: work)
    }
    guard let fence else { throw Failure.wrongOwner }
    return fence
  }

  /// Capture the revision for an enrollment only when it cannot replace a
  /// different account or interrupt a currently valid access window. The
  /// same checks are repeated by setPersistentDomains under the commit lock.
  func enrollmentFence(ownerUID: UInt32, profileID: String, now: Double, boot: Int64?) throws -> String {
    guard ownerUID > 0, UUID(uuidString: profileID) != nil, now.isFinite, now >= 0 else { throw Failure.invalidGrant }
    var fence: String?
    try withLockedDirectory(create: true) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      if let policy = try readDesiredPolicy(in: work) {
        if let owner = policy.owner, !owner.matches(uid: ownerUID, profile: profileID) { throw Failure.wrongOwner }
        if policy.owner == nil && policy.domains.isEmpty { throw Failure.needsEnrollment }
        if let access = policy.access {
          guard let boot, !access.allows(now: now, boot: boot) else { throw Failure.invalidGrant }
        }
      }
      fence = try readOrCreateFence(in: work)
    }
    guard let fence else { throw Failure.io }
    return fence
  }

  /// Replace only server-managed rules while retaining locally approved manual
  /// rules and any still-valid access window. Caller supplies a fresh server
  /// snapshot and a revision captured before fetching it.
  @discardableResult func syncManagedDomains(_ managed: [String], ownerUID: UInt32, profileID: String,
                          expectedFence: String, now: Double, boot: Int64?,
                          afterPolicyCommit: (() throws -> Void)? = nil) throws -> Bool {
    _ = try MacHostsPolicy.transform(Data(), domains: managed)
    var inspected = false
    var changed = false
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work),
            policy.owner?.matches(uid: ownerUID, profile: profileID) == true else { throw Failure.wrongOwner }
      guard let manual = policy.manualDomains, let previousManaged = policy.managedDomains else { throw Failure.needsEnrollment }
      guard try readOrCreateFence(in: work) == expectedFence else { throw Failure.stale }
      let combined = Array(Set(manual + managed)).sorted()
      _ = try MacHostsPolicy.transform(Data(), domains: combined)
      let allowed = policy.access?.allows(now: now, boot: boot) == true
      inspected = true
      if Set(previousManaged) == Set(managed) && (policy.access == nil || allowed) { return }
      let retainedAccess = allowed ? policy.access : nil
      let completed = !allowed ? (policy.access?.sessionID ?? policy.completedSessionID) : policy.completedSessionID
      let next = DesiredPolicy(version: 1, domains: combined, manualDomains: manual, managedDomains: managed,
        owner: policy.owner, access: retainedAccess, completedSessionID: completed)
      try writeFence(in: work)
      try writeDesiredPolicy(next, in: work, afterCommit: afterPolicyCommit)
      do {
        try applyLocked(domains: allowed ? [] : combined, dir: dir, work: work)
        // An empty managed set retains enrollment for future parent changes.
      } catch Failure.recoveryRequired { throw Failure.recoveryRequired }
      catch { throw Failure.commitUncertain }
      changed = true
    }
    guard inspected else { throw Failure.wrongOwner }
    return changed
  }

  /// The broker verifies the session and owner with the server before calling
  /// this operation; the persisted fence is rechecked while holding the lock.
  func installVerifiedWindow(ownerUID: UInt32, profileID: String, sessionID: String,
                             boot: Int64, now: Double, deadline: Double, expectedFence: String? = nil,
                             afterWindowCommit: (() throws -> Void)? = nil) throws {
    let candidate = AccessWindow(ownerUID: ownerUID, profileID: profileID, sessionID: sessionID,
      boot: boot, issuedMillis: now, deadlineMillis: deadline)
    guard candidate.isValid, candidate.allows(now: now, boot: boot) else { throw Failure.invalidGrant }
    var installed = false
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work),
            policy.owner?.matches(uid: ownerUID, profile: profileID) == true,
            !policy.domains.isEmpty || (policy.manualDomains != nil && policy.managedDomains != nil)
      else { throw Failure.wrongOwner }
      let fence = try readOrCreateFence(in: work)
      guard expectedFence == nil || expectedFence == fence else { throw Failure.stale }
      if let completed = policy.completedSessionID, UUID(uuidString: completed) == UUID(uuidString: sessionID) {
        throw Failure.invalidGrant
      }
      var chosen = candidate
      if let existing = policy.access {
        guard UUID(uuidString: existing.sessionID) == UUID(uuidString: sessionID), existing.allows(now: now, boot: boot) else { throw Failure.invalidGrant }
        chosen = AccessWindow(ownerUID: ownerUID, profileID: profileID, sessionID: sessionID,
          boot: boot, issuedMillis: existing.issuedMillis, deadlineMillis: min(deadline, existing.deadlineMillis))
        guard chosen.allows(now: now, boot: boot) else { throw Failure.invalidGrant }
      }
      try writeFence(in: work)
      try writeDesiredPolicy(DesiredPolicy(version: 1, domains: policy.domains, manualDomains: policy.manualDomains,
        managedDomains: policy.managedDomains, owner: policy.owner,
        access: chosen, completedSessionID: policy.completedSessionID), in: work, afterCommit: afterWindowCommit)
      do { try applyLocked(domains: [], dir: dir, work: work) }
      catch Failure.recoveryRequired { throw Failure.recoveryRequired }
      catch { throw Failure.commitUncertain }
      installed = true
    }
    guard installed else { throw Failure.wrongOwner }
  }

  /// Close only this owner's matching window. Persist the close before the
  /// hosts swap so a crash or timeout cannot reopen it on restart.
  @discardableResult func closeVerifiedWindow(ownerUID: UInt32, profileID: String, sessionID: String,
                                               afterCloseCommit: (() throws -> Void)? = nil) throws -> Bool {
    guard ownerUID > 0, UUID(uuidString: profileID) != nil, UUID(uuidString: sessionID) != nil else {
      throw Failure.invalidGrant
    }
    var closed = false
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work) else { return }
      guard policy.owner?.matches(uid: ownerUID, profile: profileID) == true else { throw Failure.wrongOwner }
      guard let window = policy.access else {
        if policy.completedSessionID.flatMap(UUID.init(uuidString:)) != UUID(uuidString: sessionID) {
          // Fence a verification already in flight even when it has not yet
          // installed its window, and remember this session as closed.
          try writeFence(in: work)
          try writeDesiredPolicy(DesiredPolicy(version: 1, domains: policy.domains, manualDomains: policy.manualDomains,
        managedDomains: policy.managedDomains, owner: policy.owner,
            access: nil, completedSessionID: sessionID), in: work, afterCommit: afterCloseCommit)
        }
        do { try applyLocked(domains: policy.domains, dir: dir, work: work) }
        catch Failure.recoveryRequired { throw Failure.recoveryRequired }
        catch { throw Failure.commitUncertain }
        closed = true
        return
      }
      guard UUID(uuidString: window.sessionID) == UUID(uuidString: sessionID) else { throw Failure.invalidGrant }
      try writeFence(in: work)
      try writeDesiredPolicy(DesiredPolicy(version: 1, domains: policy.domains, manualDomains: policy.manualDomains,
        managedDomains: policy.managedDomains, owner: policy.owner,
        access: nil, completedSessionID: window.sessionID), in: work, afterCommit: afterCloseCommit)
      do { try applyLocked(domains: policy.domains, dir: dir, work: work) }
      catch Failure.recoveryRequired { throw Failure.recoveryRequired }
      catch { throw Failure.commitUncertain }
      closed = true
    }
    return closed
  }

  /// Restore the last administrator-approved intent after a broker restart.
  /// An absent policy never creates a staging directory or reads hosts.
  func reconcilePersistentDomains(now: Double? = nil, boot: Int64? = nil) throws {
    try withLockedDirectory(create: false) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      guard let policy = try readDesiredPolicy(in: work) else { return }
      let accessAllowed = policy.access?.allows(now: now, boot: boot) == true
      try applyLocked(domains: accessAllowed ? [] : policy.domains, dir: dir, work: work)
      if policy.access != nil && !accessAllowed {
        // Restore blocking first, even if the subsequent policy write fails.
        // Persist invalidation so a later clock reading cannot reopen it.
        try writeFence(in: work)
        try writeDesiredPolicy(DesiredPolicy(version: 1, domains: policy.domains, manualDomains: policy.manualDomains,
        managedDomains: policy.managedDomains, owner: policy.owner, access: nil,
          completedSessionID: policy.access?.sessionID ?? policy.completedSessionID), in: work)
      }
      // A temporary opening retains its rules; only explicit cleanup removes them.
      if policy.domains.isEmpty && policy.owner == nil { try removeDesiredPolicy(in: work) }
    }
  }

  /// A root-owned revision survives cleanup, so another broker process can
  /// invalidate a request that is waiting on the network.
  func currentPolicyFence() throws -> String {
    var result: String?
    try withLockedDirectory(create: true) { dir, work in
      try recover(in: work, hostsDirectory: dir)
      result = try readOrCreateFence(in: work)
    }
    guard let result else { throw Failure.io }
    return result
  }

  private func readOrCreateFence(in work: Int32) throws -> String {
    let fd = openat(work, Self.fenceName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    if fd < 0 && errno == ENOENT { return try writeFence(in: work) }
    guard fd >= 0 else { throw Failure.unsafeFile }
    defer { close(fd) }
    var info = stat(); var path = stat(); var after = stat()
    guard fstat(fd, &info) == 0, info.st_uid == expectedOwner, info.st_nlink == 1,
          (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), (info.st_mode & 0o7777) == 0o600,
          (info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0,
          info.st_size == 36, noExtendedACL(fd),
          fstatat(work, Self.fenceName, &path, AT_SYMLINK_NOFOLLOW) == 0, sameFile(info, path),
          let value = String(data: try readAll(fd), encoding: .utf8),
          UUID(uuidString: value)?.uuidString.lowercased() == value,
          fstat(fd, &after) == 0, sameFile(info, after),
          fstatat(work, Self.fenceName, &path, AT_SYMLINK_NOFOLLOW) == 0, sameFile(after, path)
    else { throw Failure.unsafeFile }
    return value
  }

  @discardableResult private func writeFence(in work: Int32) throws -> String {
    let value = UUID().uuidString.lowercased()
    let name = "fence-\(UUID().uuidString.lowercased()).tmp"
    let fd = openat(work, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw Failure.io }
    var published = false
    defer { close(fd); if !published { _ = unlinkat(work, name, 0) } }
    guard fchmod(fd, 0o600) == 0 else { throw Failure.io }
    try writeAll(fd, data: Data(value.utf8))
    guard fsync(fd) == 0, fcntl(fd, F_FULLFSYNC) == 0 else { throw Failure.io }
    guard renameat(work, name, work, Self.fenceName) == 0 else { throw Failure.io }
    published = true
    guard fsync(work) == 0 else { throw Failure.commitUncertain }
    return value
  }

  private func writeDesiredPolicy(_ policy: DesiredPolicy, in work: Int32,
                                  beforeCommit: (() throws -> Void)? = nil,
                                  afterCommit: (() throws -> Void)? = nil) throws {
    let encoded = try JSONEncoder().encode(policy)
    guard encoded.count <= 100_000 else { throw MacHostsPolicy.Failure.tooLarge }
    let temp = "policy-\(UUID().uuidString.lowercased()).tmp"
    let fd = openat(work, temp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw Failure.io }
    var published = false
    defer { close(fd); if !published { _ = unlinkat(work, temp, 0) } }
    guard fchmod(fd, 0o600) == 0 else { throw Failure.io }
    try writeAll(fd, data: encoded)
    guard fsync(fd) == 0, fcntl(fd, F_FULLFSYNC) == 0 else { throw Failure.io }
    try beforeCommit?()
    guard renameat(work, temp, work, Self.desiredName) == 0 else { throw Failure.io }
    published = true
    guard fsync(work) == 0 else { throw Failure.commitUncertain }
    try afterCommit?()
  }

  private func removeDesiredPolicy(in directory: Int32) throws {
    guard unlinkat(directory, Self.desiredName, 0) == 0, fsync(directory) == 0 else { throw Failure.commitUncertain }
  }

  private func readDesiredPolicy(in directory: Int32) throws -> DesiredPolicy? {
    let fd = openat(directory, Self.desiredName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    if fd < 0 && errno == ENOENT { return nil }
    guard fd >= 0 else { throw Failure.unsafeFile }
    defer { close(fd) }
    var info = stat(); var path = stat(); var after = stat()
    guard fstat(fd, &info) == 0, info.st_uid == expectedOwner, info.st_nlink == 1,
          (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), (info.st_mode & 0o7777) == 0o600,
          (info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0,
          info.st_size >= 0, info.st_size <= 100_000, noExtendedACL(fd),
          fstatat(directory, Self.desiredName, &path, AT_SYMLINK_NOFOLLOW) == 0, sameFile(info, path)
    else { throw Failure.unsafeFile }
    let data = try readAll(fd)
    guard data.count <= 100_000, let policy = try? JSONDecoder().decode(DesiredPolicy.self, from: data),
          policy.version == 1, (try? MacHostsPolicy.transform(Data(), domains: policy.domains)) != nil,
          ((policy.manualDomains == nil && policy.managedDomains == nil)
            || (policy.manualDomains != nil && policy.managedDomains != nil && policy.owner != nil
              && Set(policy.domains) == Set(policy.manualDomains! + policy.managedDomains!)
              && (try? MacHostsPolicy.transform(Data(), domains: policy.manualDomains!)) != nil
              && (try? MacHostsPolicy.transform(Data(), domains: policy.managedDomains!)) != nil)),
          (policy.owner == nil || (policy.owner?.isValid == true
            && (!policy.domains.isEmpty || (policy.manualDomains != nil && policy.managedDomains != nil)))),
          (policy.completedSessionID == nil || UUID(uuidString: policy.completedSessionID!) != nil),
          (policy.access == nil || (policy.access?.isValid == true
            && (!policy.domains.isEmpty || (policy.manualDomains != nil && policy.managedDomains != nil))
            && policy.owner?.matches(uid: policy.access!.ownerUID, profile: policy.access!.profileID) == true)),
          fstat(fd, &after) == 0, sameFile(info, after),
          fstatat(directory, Self.desiredName, &path, AT_SYMLINK_NOFOLLOW) == 0, sameFile(after, path)
    else { throw Failure.unsafeFile }
    return policy
  }

  /// Clean unswapped stages and reconcile an interrupted swap conservatively.
  func recoverInterruptedTransactions() throws {
    try withLockedDirectory(create: false) { dir, work in try recover(in: work, hostsDirectory: dir) }
  }

  private func withLockedDirectory(create: Bool, operation: (Int32, Int32) throws -> Void) throws {
    let dir = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard dir >= 0 else { throw Failure.unsafeDirectory }
    defer { close(dir) }
    var directoryStat = stat()
    guard fstat(dir, &directoryStat) == 0, directoryStat.st_uid == expectedOwner,
          (directoryStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
          (directoryStat.st_mode & 0o022) == 0, noExtendedACL(dir) else { throw Failure.unsafeDirectory }
    if create && mkdirat(dir, Self.staging, 0o700) != 0 && errno != EEXIST { throw Failure.io }
    let work = openat(dir, Self.staging, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    if work < 0 && !create && errno == ENOENT { return }
    guard work >= 0 else { throw Failure.unsafeDirectory }
    defer { close(work) }
    var workStat = stat()
    guard fstat(work, &workStat) == 0, workStat.st_uid == expectedOwner,
          (workStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
          (workStat.st_mode & 0o7777) == 0o700, noExtendedACL(work) else { throw Failure.unsafeDirectory }
    // A previous process may have created the directory and died before
    // syncing its parent. Flush even when mkdir reported EEXIST.
    if create && fsync(dir) != 0 { throw Failure.io }
    let lock = openat(work, Self.lockName, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard lock >= 0 else { throw Failure.unsafeFile }
    defer { close(lock) }
    var lockStat = stat()
    guard fstat(lock, &lockStat) == 0, lockStat.st_uid == expectedOwner, lockStat.st_nlink == 1,
          (lockStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), (lockStat.st_mode & 0o7777) == 0o600 else { throw Failure.unsafeFile }
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw Failure.busy }
    defer { flock(lock, LOCK_UN) }
    try operation(dir, work)
  }

  private func sameFile(_ a: stat, _ b: stat) -> Bool {
    a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size && a.st_uid == b.st_uid && a.st_nlink == b.st_nlink
      && a.st_gid == b.st_gid && a.st_mode == b.st_mode && a.st_flags == b.st_flags
      && a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec
      && a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
  }

  private func sameDisplacedFile(_ a: stat, _ b: stat) -> Bool {
    a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size && a.st_uid == b.st_uid && a.st_nlink == b.st_nlink
      && a.st_gid == b.st_gid && a.st_mode == b.st_mode && a.st_flags == b.st_flags
      && a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec
  }

  private func preserveConflict(in directory: Int32, name: String, transactionID: String) throws {
    let preserved = "conflict-\(transactionID).hosts"
    guard renameatx_np(directory, name, directory, preserved, UInt32(RENAME_EXCL)) == 0,
          fsync(directory) == 0 else { throw Failure.recoveryRequired }
  }

  private func noExtendedACL(_ fd: Int32) -> Bool {
    errno = 0
    if let acl = acl_get_fd_np(fd, ACL_TYPE_EXTENDED) {
      _ = acl_free(UnsafeMutableRawPointer(acl))
      return false
    }
    return errno == ENOENT
  }

  private func extendedAttributes(_ fd: Int32) -> [String: Data]? {
    let size = flistxattr(fd, nil, 0, 0)
    guard size >= 0, size <= 1_048_576 else { return nil }
    if size == 0 { return [:] }
    var names = [CChar](repeating: 0, count: size)
    guard flistxattr(fd, &names, names.count, 0) == size else { return nil }
    var result: [String: Data] = [:]
    var start = 0
    var total = 0
    while start < names.count {
      guard let end = names[start...].firstIndex(of: 0), end > start else { return nil }
      let bytes = names[start..<end].map { UInt8(bitPattern: $0) }
      guard let name = String(bytes: bytes, encoding: .utf8) else { return nil }
      let length = fgetxattr(fd, name, nil, 0, 0, 0)
      guard length >= 0, length <= 1_048_576, total + length <= 1_048_576 else { return nil }
      var value = Data(count: length)
      let copied = value.withUnsafeMutableBytes { fgetxattr(fd, name, $0.baseAddress, length, 0, 0) }
      guard copied == length else { return nil }
      result[name] = value
      total += length
      start = end + 1
    }
    return result
  }

  private func readAll(_ fd: Int32) throws -> Data {
    guard lseek(fd, 0, SEEK_SET) >= 0 else { throw Failure.io }
    var data = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
    while true {
      let n = read(fd, &buffer, buffer.count)
      if n == 0 { return data }
      if n < 0 { if errno == EINTR { continue }; throw Failure.io }
      data.append(contentsOf: buffer[0..<n])
      if data.count > 1_048_576 { throw Failure.unsafeFile }
    }
  }

  private func writeAll(_ fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else { return }
      var offset = 0
      while offset < bytes.count {
        let n = write(fd, base.advanced(by: offset), bytes.count - offset)
        if n < 0 { if errno == EINTR { continue }; throw Failure.io }
        guard n > 0 else { throw Failure.io }
        offset += n
      }
    }
  }

  private func recover(in directory: Int32, hostsDirectory: Int32) throws {
    let duplicate = dup(directory)
    guard duplicate >= 0, let stream = fdopendir(duplicate) else { if duplicate >= 0 { close(duplicate) }; throw Failure.io }
    defer { closedir(stream) }
    var examined = 0
    while true {
      errno = 0
      guard let entry = readdir(stream) else {
        if errno != 0 { throw Failure.io }
        break
      }
      examined += 1
      guard examined <= 10_000 else { throw Failure.unsafeFile }
      let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
      }
      if name.hasPrefix("conflict-") && name.hasSuffix(".hosts") { throw Failure.recoveryRequired }
      if (name.hasPrefix("policy-") || name.hasPrefix("fence-")), name.hasSuffix(".tmp") {
        let prefix = name.hasPrefix("policy-") ? 7 : 6
        let id = String(name.dropFirst(prefix).dropLast(4))
        guard UUID(uuidString: id)?.uuidString.lowercased() == id else { continue }
        var info = stat()
        guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0,
              info.st_uid == expectedOwner, info.st_nlink == 1,
              (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              (info.st_mode & 0o7177) == 0 else { throw Failure.unsafeFile }
        guard unlinkat(directory, name, 0) == 0, fsync(directory) == 0 else { throw Failure.io }
        continue
      }
      guard name.hasPrefix("txn-"), name.hasSuffix(".tmp") else { continue }
      let raw = String(name.dropFirst(4).dropLast(4))
      let legacy = UUID(uuidString: raw)?.uuidString.lowercased() == raw
      let split = raw.lastIndex(of: "-")
      let id = legacy ? raw : split.map { String(raw[..<$0]) } ?? ""
      let stagedInode = legacy ? nil : split.flatMap { UInt64(raw[raw.index(after: $0)...]) }
      guard UUID(uuidString: id)?.uuidString.lowercased() == id, legacy || stagedInode != nil else { continue }
      var info = stat()
      guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0,
            info.st_uid == expectedOwner, info.st_nlink == 1,
            (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw Failure.unsafeFile }
      if let stagedInode, UInt64(info.st_ino) != stagedInode {
        if canDiscardDisplaced(in: directory, name: name, hostsDirectory: hostsDirectory, stagedInode: stagedInode) {
          guard unlinkat(directory, name, 0) == 0, fsync(directory) == 0 else { throw Failure.io }
          continue
        }
        try preserveConflict(in: directory, name: name, transactionID: id)
        throw Failure.recoveryRequired
      }
      // Do not report recovery complete until removal of every unswapped
      // stage is durable as well.
      guard unlinkat(directory, name, 0) == 0, fsync(directory) == 0 else { throw Failure.io }
    }
  }

  /// Only discard a displaced file when the current file is the staged inode
  /// and both files have identical non-Bloom bytes and security metadata.
  private func canDiscardDisplaced(in directory: Int32, name: String, hostsDirectory: Int32, stagedInode: UInt64) -> Bool {
    let old = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard old >= 0 else { return false }
    defer { close(old) }
    let current = openat(hostsDirectory, Self.hostName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard current >= 0 else { return false }
    defer { close(current) }
    guard flock(old, LOCK_EX | LOCK_NB) == 0 else { return false }
    defer { flock(old, LOCK_UN) }
    guard flock(current, LOCK_EX | LOCK_NB) == 0 else { return false }
    defer { flock(current, LOCK_UN) }
    var oldStat = stat(); var currentStat = stat(); var pathStat = stat()
    guard fstat(old, &oldStat) == 0, fstat(current, &currentStat) == 0,
          fstatat(hostsDirectory, Self.hostName, &pathStat, AT_SYMLINK_NOFOLLOW) == 0,
          UInt64(currentStat.st_ino) == stagedInode, sameFile(currentStat, pathStat),
          oldStat.st_dev == currentStat.st_dev,
          oldStat.st_uid == expectedOwner, currentStat.st_uid == expectedOwner,
          oldStat.st_nlink == 1, currentStat.st_nlink == 1,
          (oldStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
          (currentStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
          (oldStat.st_mode & 0o022) == 0, (currentStat.st_mode & 0o022) == 0,
          (oldStat.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0,
          oldStat.st_uid == currentStat.st_uid, oldStat.st_gid == currentStat.st_gid,
          oldStat.st_mode == currentStat.st_mode, oldStat.st_flags == currentStat.st_flags,
          noExtendedACL(old), noExtendedACL(current),
          let oldAttributes = extendedAttributes(old), let currentAttributes = extendedAttributes(current),
          oldAttributes == currentAttributes,
          let oldData = try? readAll(old), let currentData = try? readAll(current),
          let oldBase = try? MacHostsPolicy.transform(oldData, domains: []),
          let currentBase = try? MacHostsPolicy.transform(currentData, domains: []), oldBase == currentBase else { return false }
    var oldAfter = stat(); var currentAfter = stat(); var pathAfter = stat()
    return fstat(old, &oldAfter) == 0 && fstat(current, &currentAfter) == 0
      && fstatat(hostsDirectory, Self.hostName, &pathAfter, AT_SYMLINK_NOFOLLOW) == 0
      && sameFile(oldStat, oldAfter) && sameFile(currentStat, currentAfter) && sameFile(currentAfter, pathAfter)
  }
}
