@main struct BloomPolicyBrokerReadinessCheck {
  static func main() {
    let now = 30_000.0
    precondition(BloomPolicyBrokerReadiness.providerIsFresh(heartbeatMillis: now - 1_000, providerBoot: 42, nowMillis: now, boot: 42))
    precondition(!BloomPolicyBrokerReadiness.providerIsFresh(heartbeatMillis: now - 15_001, providerBoot: 42, nowMillis: now, boot: 42))
    precondition(!BloomPolicyBrokerReadiness.providerIsFresh(heartbeatMillis: now + 1, providerBoot: 42, nowMillis: now, boot: 42))
    precondition(!BloomPolicyBrokerReadiness.providerIsFresh(heartbeatMillis: now, providerBoot: 41, nowMillis: now, boot: 42))
    precondition(!BloomPolicyBrokerReadiness.providerIsFresh(heartbeatMillis: nil, providerBoot: 42, nowMillis: now, boot: 42))
    precondition(BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: true,
      snapshotAccepted: true, acknowledgementMillis: now - 1_000, nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "needsApproval", monitorRunning: true,
      snapshotAccepted: true, acknowledgementMillis: now - 1_000, nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: false,
      snapshotAccepted: true, acknowledgementMillis: now - 1_000, nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: true,
      snapshotAccepted: false, acknowledgementMillis: now - 1_000, nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: true,
      snapshotAccepted: true, acknowledgementMillis: now - BloomPolicyBrokerReadiness.acknowledgementFreshnessMillis - 1,
      nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: true,
      snapshotAccepted: true, acknowledgementMillis: now + 1, nowMillis: now))
    precondition(!BloomPolicyBrokerReadiness.isReady(serviceStatus: "active", monitorRunning: true,
      snapshotAccepted: true, acknowledgementMillis: .nan, nowMillis: now))
    print("macOS policy broker readiness checks passed")
  }
}
