import NetworkExtension
import Network
import Darwin
import os

/// A macOS content filter receives only network flows, not an app's screen or page contents.
final class BloomFilterDataProvider: NEFilterDataProvider {
  private let logger = Logger(subsystem: "com.focusflow.focusFlowFlutter", category: "website-flow")
  private var heartbeatTimer: DispatchSourceTimer?

  // Debug diagnostics contain only flow class and decision, never addresses,
  // app identities, audit tokens, or packet contents.
  private func trace(_ flow: NEFilterFlow, _ decision: String, persist: Bool = false) {
    let kind: String
    if let socket = flow as? NEFilterSocketFlow {
      kind = socket.socketType == SOCK_STREAM ? "tcp" : socket.socketType == SOCK_DGRAM ? "udp" : "socket-other"
    } else { kind = "non-socket" }
    let source = flow.sourceAppAuditToken == nil ? "missing" : "present"
    if persist {
      logger.notice("flow=\(kind, privacy: .public) source-token=\(source, privacy: .public) decision=\(decision, privacy: .public)")
    } else {
      logger.debug("flow=\(kind, privacy: .public) source-token=\(source, privacy: .public) decision=\(decision, privacy: .public)")
    }
  }
  private enum FlowTarget {
    case website(String)
    case unreadableBrowser(String)
  }

  private let outboundInspector = OutboundFlowInspector()
  private let selectedLock = NSLock()
  private var selectedFlows: [UUID: FlowTarget] = [:]
  private var completedDirections: [UUID: UInt8] = [:]

  private func selectedTarget(_ flow: NEFilterFlow) -> FlowTarget? {
    selectedLock.lock(); defer { selectedLock.unlock() }
    return selectedFlows[flow.identifier]
  }

  private func select(_ flow: NEFilterFlow, target: FlowTarget) {
    selectedLock.lock(); defer { selectedLock.unlock() }
    selectedFlows[flow.identifier] = target
  }

  private func forget(_ flow: NEFilterFlow) {
    outboundInspector.forget(flowID: flow.identifier)
    selectedLock.lock(); defer { selectedLock.unlock() }
    selectedFlows.removeValue(forKey: flow.identifier)
    completedDirections.removeValue(forKey: flow.identifier)
  }

  private func complete(_ flow: NEFilterFlow, direction: UInt8) {
    selectedLock.lock(); defer { selectedLock.unlock() }
    guard selectedFlows[flow.identifier] != nil else { return }
    let complete = (completedDirections[flow.identifier] ?? 0) | direction
    if complete == 3 {
      selectedFlows.removeValue(forKey: flow.identifier)
      completedDirections.removeValue(forKey: flow.identifier)
    } else { completedDirections[flow.identifier] = complete }
  }

  override func startFilter(completionHandler: @escaping (Error?) -> Void) {
    // macOS filters do not send socket flows to the provider until a filter
    // rule or default action explicitly asks for inspection.
    apply(NEFilterSettings(rules: [], defaultAction: .filterData)) { [weak self] error in
      if error == nil, let self {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: .seconds(5), leeway: .seconds(1))
        timer.setEventHandler { MacPolicyBrokerClient.shared.reportProviderHeartbeat() }
        self.heartbeatTimer = timer
        timer.resume()
      }
      completionHandler(error)
    }
  }

  override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    heartbeatTimer?.cancel()
    heartbeatTimer = nil
    completionHandler()
  }

  override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
    let configuration = filterConfiguration.vendorConfiguration
    let rules = WebsiteRules(configuration: configuration)
    guard !rules.isEmpty else { return .allow() }
    let userID = MacFlowSource.userID(for: flow.sourceAppAuditToken)
    let hostname = remoteHostname(for: flow)
    if let browser = unreadableBrowserBundleIdentifier(configuration: configuration, userID: userID) {
      let sourceBundleIdentifier = MacFlowSource.bundleIdentifier(for: flow.sourceAppAuditToken)
      switch MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: sourceBundleIdentifier, browserBundleIdentifier: browser) {
      case .inspectBrowser:
        let target = FlowTarget.unreadableBrowser(browser)
        guard targetAllowed(target, flow: flow, configuration: configuration) else { trace(flow, "unreadable-browser-drop", persist: true); return .drop() }
        trace(flow, "unreadable-browser-inspect")
        select(flow, target: target)
        return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 1, filterOutbound: true, peekOutboundBytes: 1)
      case .continueNormalFiltering:
        trace(flow, sourceBundleIdentifier == nil ? "unreadable-browser-source-unknown-allow" : "unreadable-browser-source-mismatch-allow")
        // Unknown sources are not treated as the unreadable browser. Still
        // inspect any hostname the flow exposes and eligible TLS traffic.
        break
      }
    } else if hostname == nil, let markerDecision = unreadableBrowserMarkerDecision(configuration: configuration, userID: userID) {
      trace(flow, markerDecision)
    }
    // WebKit flows may expose a URL without being socket flows. Other flows may
    // only provide the hostname; neither is guaranteed for every connection.
    guard let hostname else {
      if shouldDropHostlessBrowserFlow(flow, configuration: configuration, userID: userID) {
        trace(flow, "hostless-active-blocked-browser-drop", persist: true)
        return .drop()
      }
      // Some browsers use raw TCP sockets, for which macOS supplies no host.
      // Peek at the TLS ClientHello on HTTPS connections to inspect its server
      // name locally. A recent monitor decision covers hostless flows from a
      // browser whose readable foreground address currently matches a rule.
      guard let socket = flow as? NEFilterSocketFlow else { trace(flow, "hostless-allow"); return .allow() }
      let port = remotePort(for: socket)
      let sourceBundleIdentifier = MacFlowSource.bundleIdentifier(for: flow.sourceAppAuditToken)
      if socket.socketType == SOCK_DGRAM && !FilterCreditClock.isAllowed(configuration: configuration) {
        if MacFlowSource.shouldDropBrowserQUIC(
          isDatagram: true,
          remotePort: port,
          sourceBundleIdentifier: sourceBundleIdentifier) {
          trace(flow, "hostless-browser-quic-drop", persist: true)
          return .drop()
        }
        if port == nil && MacFlowSource.isKnownBrowserProcess(sourceBundleIdentifier) {
          trace(flow, "hostless-browser-udp-port-pending-inspect")
          return .filterDataVerdict(withFilterInbound: false, peekInboundBytes: 0, filterOutbound: true, peekOutboundBytes: 1)
        }
      }
      if TLSHostname.shouldInspect(isStream: socket.socketType == SOCK_STREAM, remotePort: port) {
        let peek = outboundInspector.begin(flowID: flow.identifier, kind: .tls)
        trace(flow, "hostless-tls-inspect")
        return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 1, filterOutbound: true, peekOutboundBytes: peek)
      }
      if HTTPHostname.shouldInspect(isStream: socket.socketType == SOCK_STREAM, remotePort: port) {
        let peek = outboundInspector.begin(flowID: flow.identifier, kind: .http)
        trace(flow, "hostless-http-inspect")
        return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 1, filterOutbound: true, peekOutboundBytes: peek)
      }
      trace(flow, "hostless-not-tls-candidate-allow")
      return .allow()
    }
    guard rules.blocks(hostname) else { trace(flow, "hostname-unmatched-allow"); return .allow() }
    let target = FlowTarget.website(hostname)
    guard targetAllowed(target, flow: flow, configuration: configuration) else { trace(flow, "hostname-matched-drop", persist: true); return .drop() }
    trace(flow, "hostname-matched-inspect")
    select(flow, target: target)
    // Keep inspecting selected flows during an allowance so they can be
    // stopped after the deadline, including connections opened before it.
    return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 1, filterOutbound: true, peekOutboundBytes: 1)
  }

  override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
    guard let target = selectedTarget(flow) else { return .allow() }
    return dataVerdict(flow: flow, target: target, bytes: readBytes.count)
  }

  override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
    if let target = selectedTarget(flow) { return dataVerdict(flow: flow, target: target, bytes: readBytes.count) }
    guard let socket = flow as? NEFilterSocketFlow else {
      outboundInspector.forget(flowID: flow.identifier)
      trace(flow, "outbound-non-socket-allow")
      return .allow()
    }
    let port = remotePort(for: socket)
    if socket.socketType == SOCK_DGRAM {
      let configuration = filterConfiguration.vendorConfiguration
      if !FilterCreditClock.isAllowed(configuration: configuration),
         MacFlowSource.shouldDropBrowserQUIC(
           isDatagram: true,
           remotePort: port,
           sourceBundleIdentifier: MacFlowSource.bundleIdentifier(for: flow.sourceAppAuditToken)) {
        trace(flow, "outbound-browser-quic-drop", persist: true)
        return .drop()
      }
      trace(flow, "outbound-udp-non-quic-allow")
      return .allow()
    }
    let isStream = socket.socketType == SOCK_STREAM
    let kind: OutboundInspectionKind? = TLSHostname.shouldInspect(isStream: isStream, remotePort: port)
      ? .tls
      : HTTPHostname.shouldInspect(isStream: isStream, remotePort: port) ? .http : nil
    guard let kind else {
      outboundInspector.forget(flowID: flow.identifier)
      trace(flow, "outbound-not-inspectable-allow")
      return .allow()
    }
    switch outboundInspector.feed(flowID: flow.identifier, kind: kind, offset: offset, chunk: readBytes) {
    case .need(let peekBytes):
      trace(flow, kind == .tls ? "tls-host-need-more" : "http-host-need-more")
      return NEFilterDataVerdict(passBytes: 0, peekBytes: peekBytes)
    case .unknown:
      trace(flow, kind == .tls ? "tls-host-unavailable-allow" : "http-host-unavailable-allow")
      return .allow()
    case .host(let hostname, let bufferedBytes):
      let config = filterConfiguration.vendorConfiguration
      guard WebsiteRules(configuration: config).blocks(hostname) else {
        trace(flow, kind == .tls ? "tls-host-unmatched-allow" : "http-host-unmatched-allow")
        return .allow()
      }
      let target = FlowTarget.website(hostname)
      guard targetAllowed(target, flow: flow, configuration: config) else {
        trace(flow, kind == .tls ? "tls-host-matched-drop" : "http-host-matched-drop", persist: true)
        return .drop()
      }
      trace(flow, kind == .tls ? "tls-host-matched-inspect" : "http-host-matched-inspect")
      select(flow, target: target)
      return dataVerdict(flow: flow, target: target, bytes: max(bufferedBytes, readBytes.count))
    }
  }

  override func handleInboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
    complete(flow, direction: 1)
    return .allow()
  }

  override func handleOutboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
    outboundInspector.forget(flowID: flow.identifier)
    complete(flow, direction: 2)
    return .allow()
  }

  private func remotePort(for socket: NEFilterSocketFlow) -> String? {
    if #available(macOS 15.0, *), case let .hostPort(_, port) = socket.remoteFlowEndpoint {
      return String(port.rawValue)
    }
    return (socket.remoteEndpoint as? NWHostEndpoint)?.port
  }

  private func remoteHostname(for flow: NEFilterFlow) -> String? {
    if let host = flow.url?.host { return host }
    guard let socket = flow as? NEFilterSocketFlow else { return nil }
    if let host = socket.remoteHostname { return host }
    if #available(macOS 15.0, *), case let .hostPort(.name(name, _), _) = socket.remoteFlowEndpoint {
      return name
    }
    return nil
  }

  private func targetAllowed(_ target: FlowTarget, flow: NEFilterFlow, configuration: [String: Any]?) -> Bool {
    if case .website(let host) = target {
      let managed = configuration?["managedDomains"] as? [String] ?? []
      if !managed.isEmpty && WebsiteRules(configuration: ["blockedDomains": managed]).blocks(host) {
        return false
      }
    }
    if FilterCreditClock.isAllowed(configuration: configuration) { return true }
    let userID = MacFlowSource.userID(for: flow.sourceAppAuditToken)
    switch target {
    case .website(let host):
      return MacWebsiteUsageAccess.allows(host: host, userID: userID, configuration: configuration)
    case .unreadableBrowser(let bundleIdentifier):
      return MacWebsiteUsageAccess.allowsUnknownBrowser(bundleIdentifier: bundleIdentifier,
        userID: userID, configuration: configuration)
    }
  }

  private func dataVerdict(flow: NEFilterFlow, target: FlowTarget, bytes: Int) -> NEFilterDataVerdict {
    guard targetAllowed(target, flow: flow, configuration: filterConfiguration.vendorConfiguration) else { forget(flow); return .drop() }
    return NEFilterDataVerdict(passBytes: max(bytes, 16 * 1024), peekBytes: 1)
  }

  private func shouldDropHostlessBrowserFlow(_ flow: NEFilterFlow, configuration: [String: Any]?, userID: UInt32?) -> Bool {
    guard !WebsiteRules(configuration: configuration).isEmpty,
          let userID, let boot = FilterCreditClock.boot(),
          let snapshot = MacPolicyBrokerClient.shared.snapshotForForegroundEnforcement(for: userID,
            nowMillis: FilterCreditClock.nowMillis(), boot: boot) else { return false }
    return snapshot.shouldDropHostlessFlow(
      sourceBundleIdentifier: MacFlowSource.bundleIdentifier(for: flow.sourceAppAuditToken),
      nowMillis: FilterCreditClock.nowMillis(), boot: boot)
  }

  private func unreadableBrowserBundleIdentifier(configuration: [String: Any]?, userID: UInt32?) -> String? {
    guard !WebsiteRules(configuration: configuration).isEmpty,
          let userID, let boot = FilterCreditClock.boot(),
          let snapshot = MacPolicyBrokerClient.shared.snapshotForForegroundEnforcement(for: userID,
            nowMillis: FilterCreditClock.nowMillis(), boot: boot) else { return nil }
    return snapshot.unreadableBrowserIdentifier(nowMillis: FilterCreditClock.nowMillis(), boot: boot)
  }

  private func unreadableBrowserMarkerDecision(configuration: [String: Any]?, userID: UInt32?) -> String? {
    guard !WebsiteRules(configuration: configuration).isEmpty else { return nil }
    guard let userID, let boot = FilterCreditClock.boot(),
          let snapshot = MacPolicyBrokerClient.shared.snapshotForForegroundEnforcement(for: userID,
            nowMillis: FilterCreditClock.nowMillis(), boot: boot) else {
      return "policy-broker-snapshot-unavailable-allow"
    }
    guard snapshot.websiteBlockingEnabled else { return "unreadable-browser-policy-flag-off-allow" }
    let status = snapshot.browserAddressStatus
    let knownStatuses: Set<String> = ["readable", "unreadable", "unsupported", "inactive", "missing"]
    guard status == "unreadable" else {
      let label = knownStatuses.contains(status) ? status : "other"
      return "unreadable-browser-address-status-\(label)-allow"
    }
    guard !snapshot.unreadableBrowserBundleIdentifier.isEmpty else {
      return "unreadable-browser-identifier-missing-allow"
    }
    guard snapshot.freshMonitor(nowMillis: FilterCreditClock.nowMillis(), boot: boot) else {
      return "unreadable-browser-monitor-boot-mismatch-allow"
    }
    return snapshot.unreadableBrowserIdentifier(nowMillis: FilterCreditClock.nowMillis(), boot: boot) == nil
      ? "unreadable-browser-monitor-stale-allow" : "unreadable-browser-marker-available-allow"
  }
}
