import Darwin
import Foundation

struct MacUsageState: Codable, Equatable {
  let sessionId: String
  let userId: String
  var budgetMillis: Int64
  var expiryElapsedMillis: Double
  let boot: Int64
  var startedElapsedMillis: Double?
  var usedMillis: Int64 = 0
  var activeSinceMillis: Double?
  var closed = false
  var serverVerified: Bool? = nil

  mutating func observe(now: Double, boot currentBoot: Int64?, active: Bool) {
    guard !closed else { return }
    guard currentBoot == boot, now.isFinite, now >= 0 else { activeSinceMillis = nil; closed = true; return }
    guard let started = startedElapsedMillis, now >= started else { activeSinceMillis = nil; closed = true; return }
    let elapsed = max(0, min(now, expiryElapsedMillis) - started)
    usedMillis = min(budgetMillis, Int64(elapsed.rounded(.down)))
    if now >= expiryElapsedMillis || usedMillis >= budgetMillis {
      activeSinceMillis = nil; closed = true
    } else {
      activeSinceMillis = active ? now : nil
    }
  }

  func allows(now: Double, boot currentBoot: Int64?) -> Bool {
    guard serverVerified == true, !closed, currentBoot == boot, now.isFinite, now >= 0,
          let started = startedElapsedMillis, now >= started, now < expiryElapsedMillis else { return false }
    return min(budgetMillis, Int64((now - started).rounded(.down))) < budgetMillis
  }
}

/// File locking makes the app helper and background monitor serialize each
/// checkpoint. A closed session stays on disk until its server debit succeeds.
final class MacUsageStore {
  enum StoreError: LocalizedError {
    case unavailable, existing, invalid, wrongAccount
    var errorDescription: String? {
      switch self {
      case .unavailable: return "Bloom's Mac usage store is unavailable."
      case .existing: return "Finish the existing screen-time session first."
      case .invalid: return "The screen-time reservation expired or is invalid."
      case .wrongAccount: return "This screen-time session belongs to another account."
      }
    }
  }

  private let directory: URL
  init(directory: URL) { self.directory = directory }

  static func shared(group configuredGroup: String? = nil) throws -> MacUsageStore {
    guard let group = configuredGroup ?? BloomAppGroup.identifier,
          let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { throw StoreError.unavailable }
    return MacUsageStore(directory: url)
  }

  private func mutate(_ operation: (inout MacUsageState?) throws -> Void) throws -> MacUsageState? {
    let lockURL = directory.appendingPathComponent("bloom-usage.lock")
    let fileURL = directory.appendingPathComponent("bloom-usage.json")
    let fd = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw StoreError.unavailable }
    defer { Darwin.close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw StoreError.unavailable }
    defer { flock(fd, LOCK_UN) }
    var state: MacUsageState?
    if FileManager.default.fileExists(atPath: fileURL.path) {
      state = try JSONDecoder().decode(MacUsageState.self, from: Data(contentsOf: fileURL))
    }
    let before = state
    try operation(&state)
    if state != before {
      if let state { try JSONEncoder().encode(state).write(to: fileURL, options: .atomic) }
      else if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }
    return state
  }

  func start(session: String, user: String, budget: Int64, expiryIn: Double, requestElapsed: Double, requestBoot: Int64) throws {
    let now = FilterCreditClock.nowMillis()
    guard !session.isEmpty, !user.isEmpty, budget >= 1000, budget <= 604800000,
          expiryIn.isFinite, expiryIn >= 1000, expiryIn <= 1209600000,
          requestElapsed.isFinite, requestElapsed >= 0, now >= requestElapsed,
          let boot = FilterCreditClock.boot(), boot == requestBoot else { throw StoreError.invalid }
    let expiry = now + expiryIn - (now - requestElapsed)
    guard expiry > now else { throw StoreError.invalid }
    _ = try mutate { current in
      if var existing = current {
        guard existing.sessionId == session, existing.userId == user, !existing.closed,
              existing.boot == boot, let started = existing.startedElapsedMillis, now >= started else { throw StoreError.existing }
        existing.budgetMillis = min(existing.budgetMillis, budget)
        existing.expiryElapsedMillis = min(existing.expiryElapsedMillis, expiry)
        existing.serverVerified = true
        existing.observe(now: now, boot: boot, active: false)
        current = existing
      } else {
        current = MacUsageState(sessionId: session, userId: user, budgetMillis: budget,
          expiryElapsedMillis: expiry, boot: boot, startedElapsedMillis: requestElapsed, serverVerified: true)
      }
    }
  }

  @discardableResult func observe(active: Bool) throws -> MacUsageState? {
    try mutate { state in state?.observe(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot(), active: active) }
  }

  func read() throws -> MacUsageState? {
    try mutate { state in
      guard var current = state else { return }
      current.observe(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot(), active: current.activeSinceMillis != nil)
      state = current
    }
  }

  // The Network Extension has read-only app-group access. State is written
  // atomically by the host and monitor, so the filter can read a complete
  // snapshot without creating a lock file or updating the elapsed counter.
  func readSnapshot() throws -> MacUsageState? {
    let fileURL = directory.appendingPathComponent("bloom-usage.json")
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return try JSONDecoder().decode(MacUsageState.self, from: Data(contentsOf: fileURL))
  }

  func close(user: String) throws -> MacUsageState? {
    try mutate { state in
      guard var current = state else { return }
      guard current.userId == user else { throw StoreError.wrongAccount }
      current.observe(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot(), active: false)
      current.closed = true
      state = current
    }
  }

  func recoverAfterInterruption() throws {
    _ = try observe(active: false)
  }

  func clear(user: String, session: String) throws {
    _ = try mutate { state in
      guard let current = state else { return }
      guard current.userId == user, current.sessionId == session else { throw StoreError.wrongAccount }
      guard current.closed else { throw StoreError.existing }
      state = nil
    }
  }
}
