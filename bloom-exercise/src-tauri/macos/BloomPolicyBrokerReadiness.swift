enum BloomPolicyBrokerReadiness {
  static let acknowledgementFreshnessMillis = 15_000.0

  static func providerIsFresh(heartbeatMillis: Double?, providerBoot: Int64?, nowMillis: Double, boot: Int64?) -> Bool {
    guard let heartbeatMillis, let providerBoot, let boot, boot > 0, providerBoot == boot,
          heartbeatMillis > 0, heartbeatMillis.isFinite, nowMillis.isFinite, nowMillis >= heartbeatMillis else { return false }
    return nowMillis - heartbeatMillis <= acknowledgementFreshnessMillis
  }

  static func isReady(serviceStatus: String, monitorRunning: Bool, snapshotAccepted: Bool,
                      acknowledgementMillis: Double?, nowMillis: Double) -> Bool {
    guard serviceStatus == "active", monitorRunning, snapshotAccepted,
          let acknowledgementMillis, acknowledgementMillis.isFinite,
          nowMillis.isFinite, nowMillis >= acknowledgementMillis else { return false }
    return nowMillis - acknowledgementMillis <= acknowledgementFreshnessMillis
  }
}
