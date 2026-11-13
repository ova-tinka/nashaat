import Foundation
import os
import Security

private final class MacPolicyBrokerSession: NSObject, MacPolicyBrokerXPCProtocol {
  private let connection: NSXPCConnection
  private let store: MacPolicyBrokerStore
  private let peerIdentifier: String
  private let recovery: MacHostsRecoveryCoordinator

  init(connection: NSXPCConnection, store: MacPolicyBrokerStore, peerIdentifier: String, recovery: MacHostsRecoveryCoordinator) {
    self.connection = connection
    self.store = store
    self.peerIdentifier = peerIdentifier
    self.recovery = recovery
  }

  func publishSnapshot(_ data: Data, claimedUID: UInt32, reply: @escaping (Bool) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    reply(store.publish(data, peerIdentifier: peerIdentifier, peerUID: peerUID,
      claimedUID: claimedUID, nowMillis: FilterCreditClock.nowMillis()))
  }

  func snapshot(forUID uid: UInt32, reply: @escaping (Data?) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    reply(store.snapshot(for: uid, peerIdentifier: peerIdentifier,
      peerUID: peerUID, nowMillis: FilterCreditClock.nowMillis()))
  }

  func reportProviderHeartbeat(reply: @escaping (Bool) -> Void) {
    reply(store.recordProviderHeartbeat(peerIdentifier: peerIdentifier, peerUID: UInt32(connection.effectiveUserIdentifier),
      nowMillis: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot()))
  }

  func providerHeartbeat(reply: @escaping (Double, Int64) -> Void) {
    let value = store.providerHeartbeat(peerIdentifier: peerIdentifier, peerUID: UInt32(connection.effectiveUserIdentifier),
      nowMillis: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot())
    reply(value?.atMillis ?? 0, value?.boot ?? 0)
  }

  func cleanupHosts(_ authorization: Data, reply: @escaping (String) -> Void) {
    updateHosts(authorization, domains: Data("[]".utf8)) { result in
      reply(result == "updated" ? "cleaned" : result)
    }
  }

  func updateHosts(_ authorization: Data, domains: Data, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    let peer = peerIdentifier
    recovery.update({
      let helper = MacHostsHelper(authorize: MacHostsAdminGrant.validate) { domains in
        // Fixed system path. The caller cannot select a file, command, or content.
        try MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
          .setPersistentDomains(domains)
      }
      return helper.update(peerIdentifier: peer, peerUID: peerUID,
        authorization: authorization, encodedDomains: domains)
    }, reply: reply)
  }

  func enrollHosts(_ authorization: Data, domains: Data, profileID: String, accessToken: String, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    let peer = peerIdentifier
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peer, peerUID: peerUID),
          UUID(uuidString: profileID) != nil, !accessToken.isEmpty, accessToken.utf8.count <= 8192,
          authorization.count == 32, MacHostsAdminGrant.validate(authorization) else { reply("denied"); return }
    let transaction = MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
    let policyFence: String
    do { policyFence = try transaction.enrollmentFence(ownerUID: peerUID, profileID: profileID,
      now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot()) }
    catch MacHostsTransaction.Failure.wrongOwner { reply("otherAccount"); return }
    catch MacHostsTransaction.Failure.needsEnrollment { reply("needsEnrollment"); return }
    catch MacHostsTransaction.Failure.invalidGrant { reply("usageActive"); return }
    catch MacHostsTransaction.Failure.busy { reply("busy"); return }
    catch MacHostsTransaction.Failure.recoveryRequired { reply("recoveryRequired"); return }
    catch { reply("unavailable"); return }
    let enrollment = MacHostsEnrollment(authorize: MacHostsAdminGrant.validate,
      verifyProfile: { try await SupabaseExistingUsageGrant.verifyProfile(profileID: $0, accessToken: $1) },
      fetchManaged: { try await SupabaseExistingUsageGrant.managedWebsites(profileID: $0, accessToken: $1) })
    Task {
      do {
        let generation = await withCheckedContinuation { continuation in
          recovery.currentGeneration { continuation.resume(returning: $0) }
        }
        let approved = try await enrollment.prepare(peerIdentifier: peer, peerUID: peerUID, authorization: authorization,
          domains: domains, profileID: profileID, accessToken: accessToken)
        let encodedApproved = try JSONEncoder().encode(approved.combined)
        recovery.update(expectedGeneration: generation, {
          let helper = MacHostsHelper(authorize: MacHostsAdminGrant.validate) { domains in
            try transaction.setPersistentDomains(domains, ownerUID: peerUID, profileID: profileID, expectedFence: policyFence,
              manualDomains: approved.manual, managedDomains: approved.managed,
              now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot())
          }
          return helper.update(peerIdentifier: peer, peerUID: peerUID, authorization: authorization, encodedDomains: encodedApproved)
        }, reply: reply)
      } catch SupabaseUsageGrantError.wrongProfile { reply("denied") }
      catch SupabaseUsageGrantError.rejected { reply("denied") }
      catch MacHostsPolicy.Failure.invalidDomain { reply("invalid") }
      catch MacHostsTransaction.Failure.wrongOwner { reply("otherAccount") }
      catch MacHostsTransaction.Failure.needsEnrollment { reply("needsEnrollment") }
      catch MacHostsTransaction.Failure.invalidGrant { reply("usageActive") }
      catch MacHostsTransaction.Failure.busy { reply("busy") }
      catch MacHostsTransaction.Failure.recoveryRequired { reply("recoveryRequired") }
      catch MacHostsTransaction.Failure.stale { reply("stale") }
      catch { reply("unavailable") }
    }
  }

  func startHostsUsage(_ request: Data, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    let peer = peerIdentifier
    let transaction = MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
    let verifier = MacHostsVerifiedUsage(transaction: transaction,
      verify: { kind, identifier, deviceKey, profileID, token in
        if kind == "countdown" {
          return try await SupabaseExistingUsageGrant.verifyCountdown(requestID: identifier, deviceKey: deviceKey, profileID: profileID, accessToken: token)
        }
        return try await SupabaseExistingUsageGrant.verify(sessionID: identifier, deviceKey: deviceKey, profileID: profileID, accessToken: token)
      },
      now: FilterCreditClock.nowMillis, boot: FilterCreditClock.boot)
    Task {
      do {
        let generation = await withCheckedContinuation { continuation in
          recovery.currentGeneration { continuation.resume(returning: $0) }
        }
        let prepared = try await verifier.prepare(peerIdentifier: peer, peerUID: peerUID, data: request)
        recovery.update(expectedGeneration: generation, {
          guard FilterCreditClock.boot() == prepared.boot else { return "expired" }
          let now = FilterCreditClock.nowMillis()
          guard now.isFinite, now < prepared.deadline else { return "expired" }
          do {
            try transaction.installVerifiedWindow(ownerUID: prepared.ownerUID, profileID: prepared.profileID,
              sessionID: prepared.sessionID, boot: prepared.boot, now: now, deadline: prepared.deadline, expectedFence: prepared.policyFence)
            return "updated"
          } catch MacHostsTransaction.Failure.stale { return "stale" }
          catch MacHostsTransaction.Failure.wrongOwner { return "denied" }
          catch MacHostsTransaction.Failure.invalidGrant { return "expired" }
          catch MacHostsTransaction.Failure.busy { return "busy" }
          catch MacHostsTransaction.Failure.recoveryRequired { return "recoveryRequired" }
          catch MacHostsTransaction.Failure.commitUncertain { return "uncertain" }
          catch { return "unavailable" }
        }, reply: reply)
      } catch MacHostsTransaction.Failure.wrongOwner { reply("denied") }
      catch MacHostsTransaction.Failure.busy { reply("busy") }
      catch SupabaseUsageGrantError.expired { reply("expired") }
      catch SupabaseUsageGrantError.wrongProfile { reply("denied") }
      catch SupabaseUsageGrantError.rejected { reply("denied") }
      catch { reply("unavailable") }
    }
  }

  func syncHostsManaged(_ profileID: String, accessToken: String, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    let peer = peerIdentifier
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peer, peerUID: peerUID),
          UUID(uuidString: profileID) != nil, !accessToken.isEmpty, accessToken.utf8.count <= 8192 else { reply("denied"); return }
    let transaction = MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
    Task {
      do {
        let fence = try transaction.policyFenceForOwner(ownerUID: peerUID, profileID: profileID)
        let generation = await withCheckedContinuation { continuation in
          recovery.currentGeneration { continuation.resume(returning: $0) }
        }
        try await SupabaseExistingUsageGrant.verifyProfile(profileID: profileID, accessToken: accessToken)
        let managed = try await SupabaseExistingUsageGrant.managedWebsites(profileID: profileID, accessToken: accessToken)
        recovery.update(expectedGeneration: generation, {
          let now = FilterCreditClock.nowMillis()
          guard now.isFinite, now >= 0 else { return "unavailable" }
          do {
            return try transaction.syncManagedDomains(managed, ownerUID: peerUID, profileID: profileID,
              expectedFence: fence, now: now, boot: FilterCreditClock.boot()) ? "updated" : "unchanged"
          } catch MacHostsTransaction.Failure.wrongOwner { return "denied" }
          catch MacHostsTransaction.Failure.needsEnrollment { return "needsEnrollment" }
          catch MacHostsTransaction.Failure.stale { return "stale" }
          catch MacHostsTransaction.Failure.busy { return "busy" }
          catch MacHostsTransaction.Failure.recoveryRequired { return "recoveryRequired" }
          catch MacHostsTransaction.Failure.commitUncertain { return "uncertain" }
          catch MacHostsPolicy.Failure.invalidDomain { return "invalid" }
          catch { return "unavailable" }
        }, reply: reply)
      } catch MacHostsTransaction.Failure.wrongOwner { reply("denied") }
      catch MacHostsTransaction.Failure.busy { reply("busy") }
      catch SupabaseUsageGrantError.wrongProfile { reply("denied") }
      catch { reply("unavailable") }
    }
  }

  func stopHostsUsage(_ profileID: String, sessionID: String, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier, peerUID: peerUID),
          UUID(uuidString: profileID) != nil, UUID(uuidString: sessionID) != nil else { reply("denied"); return }
    recovery.update({
      do {
        let transaction = MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
        return try transaction.closeVerifiedWindow(ownerUID: peerUID, profileID: profileID, sessionID: sessionID) ? "updated" : "inactive"
      } catch MacHostsTransaction.Failure.wrongOwner { return "denied" }
      catch MacHostsTransaction.Failure.invalidGrant { return "denied" }
      catch MacHostsTransaction.Failure.busy { return "busy" }
      catch MacHostsTransaction.Failure.recoveryRequired { return "recoveryRequired" }
      catch MacHostsTransaction.Failure.commitUncertain { return "uncertain" }
      catch { return "unavailable" }
    }, reply: { result in reply(result == "updated" ? "closed" : result) })
  }

  func hostsPolicyStatus(_ profileID: String, reply: @escaping (String) -> Void) {
    let peerUID = UInt32(connection.effectiveUserIdentifier)
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier, peerUID: peerUID),
          UUID(uuidString: profileID) != nil else { reply("denied"); return }
    recovery.inspect({
      do {
        return try MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
          .policyStatus(ownerUID: peerUID, profileID: profileID)
      } catch MacHostsTransaction.Failure.busy { return "busy" }
      catch MacHostsTransaction.Failure.recoveryRequired { return "review" }
      catch MacHostsTransaction.Failure.unsafeDirectory { return "unsafe" }
      catch MacHostsTransaction.Failure.unsafeFile { return "unsafe" }
      catch { return "unavailable" }
    }, reply: reply)
  }

  func hostsRecoveryStatus(reply: @escaping (String) -> Void) {
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier,
      peerUID: UInt32(connection.effectiveUserIdentifier)) else { reply("denied"); return }
    recovery.check(reply: reply)
  }
}

private final class MacPolicyBrokerListener: NSObject, NSXPCListenerDelegate {
  private let store = MacPolicyBrokerStore()
  private let recovery: MacHostsRecoveryCoordinator
  private let expectedTeam: String

  init(expectedTeam: String, recovery: MacHostsRecoveryCoordinator) { self.expectedTeam = expectedTeam; self.recovery = recovery }

  func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
    guard let identity = MacPolicyBrokerIdentity.signingIdentifier(for: connection.processIdentifier),
          MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: identity.identifier,
            peerTeam: identity.team, expectedTeam: expectedTeam),
          let requirement = MacPolicyBrokerAccessPolicy.connectionRequirement(peerIdentifier: identity.identifier,
            expectedTeam: expectedTeam) else { return false }
    // Bind every message to the exact signing identity observed for this
    // peer. The PID lookup alone must not authorize a privileged request.
    connection.setCodeSigningRequirement(requirement)
    connection.exportedInterface = NSXPCInterface(with: MacPolicyBrokerXPCProtocol.self)
    connection.exportedObject = MacPolicyBrokerSession(connection: connection, store: store,
      peerIdentifier: identity.identifier, recovery: recovery)
    connection.resume()
    return true
  }
}

@main struct BloomPolicyBroker {
  static func main() {
    let logger = Logger(subsystem: "com.focusflow.focusFlowFlutter.policy-broker", category: "lifecycle")
    let team = BloomPolicyBrokerBuildIdentity.teamIdentifier
    guard team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
      logger.error("startup rejected: invalid build team identifier")
      return
    }
    let listener = NSXPCListener(machServiceName: "\(team).com.nashaat.bloomexercise.policy")
    let transaction = MacHostsTransaction(directory: URL(fileURLWithPath: "/private/etc", isDirectory: true), expectedOwner: 0)
    let recovery = MacHostsRecoveryCoordinator(recover: { try transaction.recoverInterruptedTransactions() },
      reconcile: { try transaction.reconcilePersistentDomains(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot()) })
    recovery.restore { status in
      if status != "clear" { logger.notice("hosts recovery check requires attention") }
    }
    recovery.startMonitoring()
    let delegate = MacPolicyBrokerListener(expectedTeam: team, recovery: recovery)
    listener.delegate = delegate
    listener.activate()
    logger.info("startup accepted; XPC listener activated")
    dispatchMain()
  }
}
