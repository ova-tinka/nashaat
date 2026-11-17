import Foundation

/// XPC transport used by the per-user monitor to publish policy state and by
/// the root filter to read the snapshot for the flow's originating user.
final class MacPolicyBrokerClient {
  static let shared = MacPolicyBrokerClient()
  private static let cacheLifetimeMillis = 400.0
  private static let requestTimeoutMillis = 250.0

  private let lock = NSLock()
  private var connection: NSXPCConnection?
  private var cached: [UInt32: (snapshot: MacPolicyBrokerSnapshot, fetchedAtMillis: Double)] = [:]

  private init() {}

  func hostsPolicyStatus(profileID: String, completion: @escaping (String) -> Void) {
    let resultLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      resultLock.lock(); defer { resultLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("unavailable") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) { finish("unavailable") }
    proxy.hostsPolicyStatus(profileID, reply: finish)
  }

  func hostsRecoveryStatus(completion: @escaping (String) -> Void) {
    let resultLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      resultLock.lock(); defer { resultLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("unavailable") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) { finish("unavailable") }
    proxy.hostsRecoveryStatus(reply: finish)
  }

  func cleanupHosts(authorization: Data, completion: @escaping (String) -> Void) {
    let completionLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("uncertain") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 20) { finish("uncertain") }
    proxy.cleanupHosts(authorization, reply: finish)
  }

  func enrollHosts(authorization: Data, domains: Data, profileID: String, accessToken: String,
                   completion: @escaping (String) -> Void) {
    let completionLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("uncertain") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 60) { finish("uncertain") }
    proxy.enrollHosts(authorization, domains: domains, profileID: profileID, accessToken: accessToken, reply: finish)
  }

  func startHostsUsage(request: Data, completion: @escaping (String) -> Void) {
    let completionLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("uncertain") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 60) { finish("uncertain") }
    proxy.startHostsUsage(request, reply: finish)
  }

  func syncHostsManaged(profileID: String, accessToken: String, completion: @escaping (String) -> Void) {
    let completionLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("uncertain") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 60) { finish("uncertain") }
    proxy.syncHostsManaged(profileID, accessToken: accessToken, reply: finish)
  }

  func stopHostsUsage(profileID: String, sessionID: String, completion: @escaping (String) -> Void) {
    let completionLock = NSLock()
    var completed = false
    func finish(_ result: String) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(result)
    }
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish("uncertain") }) as? MacPolicyBrokerXPCProtocol else {
      finish("unavailable"); return
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 20) { finish("uncertain") }
    proxy.stopHostsUsage(profileID, sessionID: sessionID, reply: finish)
  }

  func reportProviderHeartbeat() {
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in }) as? MacPolicyBrokerXPCProtocol else { return }
    proxy.reportProviderHeartbeat { _ in }
  }

  func providerHeartbeat(completion: @escaping (Double, Int64) -> Void) {
    guard let connection = connectionForService(),
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in completion(0, 0) }) as? MacPolicyBrokerXPCProtocol else {
      completion(0, 0); return
    }
    proxy.providerHeartbeat(reply: completion)
  }

  func publish(_ snapshot: MacPolicyBrokerSnapshot, completion: @escaping (Bool) -> Void = { _ in }) {
    guard let data = try? JSONEncoder().encode(snapshot),
          data.count <= MacPolicyBrokerSnapshot.maximumEncodedSize,
          let connection = connectionForService() else { completion(false); return }
    let completionLock = NSLock()
    var completed = false
    func finish(_ accepted: Bool) {
      completionLock.lock(); defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(accepted)
    }
    guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish(false) }) as? MacPolicyBrokerXPCProtocol else {
      finish(false)
      return
    }
    proxy.publishSnapshot(data, claimedUID: snapshot.userID, reply: finish)
  }

  func snapshot(for userID: UInt32, nowMillis: Double, boot: Int64?) -> MacPolicyBrokerSnapshot? {
    guard userID > 0, nowMillis.isFinite else { return nil }
    lock.lock()
    if let entry = cached[userID], nowMillis >= entry.fetchedAtMillis,
       nowMillis - entry.fetchedAtMillis <= Self.cacheLifetimeMillis,
       entry.snapshot.isValid(for: userID, nowMillis: nowMillis) {
      lock.unlock()
      return entry.snapshot
    }
    lock.unlock()

    guard let connection = connectionForService() else { return nil }
    let semaphore = DispatchSemaphore(value: 0)
    let responseLock = NSLock()
    var encoded: Data?
    let proxy = connection.remoteObjectProxyWithErrorHandler { _ in semaphore.signal() } as? MacPolicyBrokerXPCProtocol
    proxy?.snapshot(forUID: userID) { data in
      responseLock.lock(); encoded = data; responseLock.unlock()
      semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + Self.requestTimeoutMillis / 1000) == .success else { return nil }
    responseLock.lock(); let data = encoded; responseLock.unlock()
    guard let data, data.count <= MacPolicyBrokerSnapshot.maximumEncodedSize,
          let value = try? JSONDecoder().decode(MacPolicyBrokerSnapshot.self, from: data),
          value.isValid(for: userID, nowMillis: nowMillis),
          value.freshMonitor(nowMillis: nowMillis, boot: boot) else { return nil }
    lock.lock(); cached[userID] = (value, nowMillis); lock.unlock()
    return value
  }

  /// Reads the live broker first, then allows a narrowly bounded last-known
  /// snapshot for browser-flow enforcement if that XPC request fails. Access
  /// grants continue to use `snapshot(for:)` and therefore fail closed.
  func snapshotForForegroundEnforcement(for userID: UInt32, nowMillis: Double,
                                        boot: Int64?) -> MacPolicyBrokerSnapshot? {
    if let current = snapshot(for: userID, nowMillis: nowMillis, boot: boot) { return current }
    guard userID > 0, nowMillis.isFinite else { return nil }
    lock.lock(); let entry = cached[userID]; lock.unlock()
    guard let entry,
          MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
            snapshot: entry.snapshot, userID: userID, fetchedAtMillis: entry.fetchedAtMillis,
            nowMillis: nowMillis, boot: boot) else { return nil }
    return entry.snapshot
  }

  private func connectionForService() -> NSXPCConnection? {
    lock.lock(); defer { lock.unlock() }
    if let connection { return connection }
    guard let group = BloomAppGroup.identifier else { return nil }
    let serviceName = "\(group).policy"
    let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
    connection.remoteObjectInterface = NSXPCInterface(with: MacPolicyBrokerXPCProtocol.self)
    let team = group.components(separatedBy: ".").first ?? ""
    guard !team.isEmpty else { return nil }
    connection.setCodeSigningRequirement(
      "identifier \"com.focusflow.focusFlowFlutter.policy-broker\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\"")
    connection.invalidationHandler = { [weak self] in
      guard let self else { return }
      self.lock.lock()
      self.connection = nil
      self.lock.unlock()
    }
    connection.activate()
    self.connection = connection
    return connection
  }
}
