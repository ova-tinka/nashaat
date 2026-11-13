import Foundation

@main struct MacUsageCheck {
  static func main() throws {
    var usage = MacUsageState(sessionId: "s", userId: "u", budgetMillis: 10000, expiryElapsedMillis: 20000, boot: 7, startedElapsedMillis: 1000)
    usage.observe(now: 1000, boot: 7, active: true)
    usage.observe(now: 4000, boot: 7, active: false)
    precondition(usage.usedMillis == 3000 && usage.activeSinceMillis == nil)
    usage.observe(now: 8000, boot: 7, active: true)
    usage.observe(now: 10000, boot: 7, active: false)
    precondition(usage.usedMillis == 9000 && !usage.closed)
    usage.observe(now: 11000, boot: 7, active: false)
    precondition(usage.closed && usage.usedMillis == 10000)

    var expiryClipped = MacUsageState(sessionId: "s2", userId: "u", budgetMillis: 10000, expiryElapsedMillis: 5000, boot: 7, startedElapsedMillis: 1000)
    expiryClipped.observe(now: 4000, boot: 7, active: false)
    precondition(expiryClipped.usedMillis == 3000 && !expiryClipped.closed)
    expiryClipped.observe(now: 5000, boot: 7, active: false)
    precondition(expiryClipped.closed && expiryClipped.usedMillis == 4000)

    var reboot = MacUsageState(sessionId: "s", userId: "u", budgetMillis: 10000, expiryElapsedMillis: 20000, boot: 7, startedElapsedMillis: 1000)
    reboot.observe(now: 1000, boot: 7, active: true)
    reboot.observe(now: 1100, boot: 8, active: true)
    precondition(reboot.closed && reboot.usedMillis == 0)

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bloom-usage-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = MacUsageStore(directory: directory)
    let missingSnapshot = try store.readSnapshot()
    precondition(missingSnapshot == nil)
    let snapshot = MacUsageState(sessionId: "snapshot", userId: "account", budgetMillis: 10000,
      expiryElapsedMillis: 20000, boot: 7, startedElapsedMillis: 1000, serverVerified: true)
    try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("bloom-usage.json"), options: .atomic)
    let legacy = MacUsageState(sessionId: "legacy", userId: "account", budgetMillis: 10000, expiryElapsedMillis: 20000, boot: 7, startedElapsedMillis: 1000)
    precondition(!legacy.allows(now: 2000, boot: 7))
    let legacyDecoded = try JSONDecoder().decode(MacUsageState.self, from: JSONEncoder().encode(legacy))
    precondition(!legacyDecoded.allows(now: 2000, boot: 7))
    let savedSnapshot = try store.readSnapshot()
    precondition(savedSnapshot == snapshot)
    precondition(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("bloom-usage.lock").path))
    precondition(snapshot.allows(now: 2000, boot: 7) && !snapshot.allows(now: 11000, boot: 7))
    try FileManager.default.removeItem(at: directory.appendingPathComponent("bloom-usage.json"))
    guard let boot = FilterCreditClock.boot() else { throw MacUsageStore.StoreError.unavailable }
    let clock = FilterCreditClock.nowMillis()
    let old = MacUsageState(sessionId: "session", userId: "account", budgetMillis: 50000, expiryElapsedMillis: clock + 40000, boot: boot, startedElapsedMillis: clock)
    try JSONEncoder().encode(old).write(to: directory.appendingPathComponent("bloom-usage.json"), options: .atomic)
    try store.start(session: "session", user: "account", budget: 60000, expiryIn: 300000, requestElapsed: clock, requestBoot: boot)
    try store.start(session: "session", user: "account", budget: 60000, expiryIn: 300000, requestElapsed: clock, requestBoot: boot)
    let started = try store.read()
    precondition(started?.sessionId == "session" && (started?.usedMillis ?? -1) >= 0)
    precondition(started?.serverVerified == true && started?.budgetMillis == 50000 && started?.expiryElapsedMillis == clock + 40000)
    do { try store.clear(user: "account", session: "session"); preconditionFailure("Open session cleared") }
    catch MacUsageStore.StoreError.existing { }
    let closed = try store.close(user: "account")
    precondition(closed?.closed == true)
    try store.clear(user: "account", session: "session")
    let cleared = try store.read()
    precondition(cleared == nil)
    print("macOS server-timed access checks passed")
  }
}
