import Foundation
import Darwin

// Shared by the app and Device Activity extension. The lock protects both the
// state and shield changes, so a late callback cannot reopen a closed session.
struct BloomUsageState: Codable {
  let sessionId: String
  let userId: String
  let budgetMillis: Int64
  let expiry: Date
  var startedAt: Date?
  var usedMillis: Int64 = 0
  var closed = false
  var endedAt: Date?
  var finalized = false

  mutating func refresh(now: Date) {
    guard !closed else { return }
    guard let startedAt, startedAt <= now else {
      closed = true
      endedAt = min(now, expiry)
      return
    }
    let end = min(now, expiry)
    let elapsed = Int64(max(0, end.timeIntervalSince(startedAt)) * 1000)
    usedMillis = min(budgetMillis, max(usedMillis, elapsed))
    if now >= expiry || usedMillis >= budgetMillis {
      closed = true
      endedAt = min(now, expiry)
    }
  }

  mutating func finish(now: Date) {
    if endedAt == nil { endedAt = min(now, expiry) }
    closed = true
    if let startedAt {
      let elapsed = Int64(max(0, endedAt!.timeIntervalSince(startedAt)) * 1000)
      usedMillis = min(budgetMillis, max(usedMillis, elapsed))
    }
    finalized = true
  }

  var response: [String: Any] {
    let now = Date()
    let end = min(endedAt ?? now, expiry)
    let elapsed = startedAt.map { Int64(max(0, end.timeIntervalSince($0)) * 1000) } ?? usedMillis
    let measured = min(budgetMillis, max(usedMillis, elapsed))
    return ["sessionId": sessionId, "userId": userId, "budgetMillis": budgetMillis,
      "usedMillis": measured, "remainingMillis": max(0, budgetMillis - measured),
      "closed": closed || now >= expiry || measured >= budgetMillis, "tracking": false]
  }
}

final class BloomUsageFile {
  enum Failure: Error { case unavailable, corrupt }
  private let directory: URL
  init(directory: URL) { self.directory = directory }

  static func shared() throws -> BloomUsageFile {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { throw Failure.unavailable }
    return BloomUsageFile(directory: directory)
  }

  func mutate<T>(_ action: (inout BloomUsageState?) throws -> T) throws -> T {
    let lock = open(directory.appendingPathComponent("bloom-usage.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard lock >= 0 else { throw Failure.unavailable }
    defer { Darwin.close(lock) }
    guard flock(lock, LOCK_EX) == 0 else { throw Failure.unavailable }
    defer { flock(lock, LOCK_UN) }
    let url = directory.appendingPathComponent("bloom-usage.json")
    var state: BloomUsageState?
    if FileManager.default.fileExists(atPath: url.path) {
      do { state = try JSONDecoder().decode(BloomUsageState.self, from: Data(contentsOf: url)) }
      catch { throw Failure.corrupt }
    }
    let result = try action(&state)
    if let state { try JSONEncoder().encode(state).write(to: url, options: .atomic) }
    else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    return result
  }
}
