import Foundation

struct MacHostsUsageRequest: Decodable {
  let kind: String?
  let sessionID: String?
  let requestID: String?
  let deviceKey: String
  let profileID: String
  let accessToken: String
}

struct MacHostsPreparedUsage {
  let ownerUID: UInt32
  let profileID: String
  let sessionID: String
  let boot: Int64
  let deadline: Double
  let policyFence: String
}

/// Only a server-confirmed existing reservation can reach the transaction.
/// The caller serializes the subsequent installation with policy updates.
struct MacHostsVerifiedUsage {
  let transaction: MacHostsTransaction
  let verify: (String, String, String, String, String) async throws -> VerifiedUsageGrant
  let now: () -> Double
  let boot: () -> Int64?

  func prepare(peerIdentifier: String?, peerUID: UInt32, data: Data) async throws -> MacHostsPreparedUsage {
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier, peerUID: peerUID),
          data.count <= 16_384, let request = try? JSONDecoder().decode(MacHostsUsageRequest.self, from: data),
          UUID(uuidString: request.deviceKey) != nil, UUID(uuidString: request.profileID) != nil,
          !request.accessToken.isEmpty, request.accessToken.utf8.count <= 8192 else { throw SupabaseUsageGrantError.rejected }
    let kind = request.kind ?? "easy"
    guard kind == "easy" || kind == "countdown",
          let identifier = kind == "easy" ? request.sessionID : request.requestID,
          UUID(uuidString: identifier) != nil else { throw SupabaseUsageGrantError.rejected }
    let policyFence = try transaction.policyFenceForOwner(ownerUID: peerUID, profileID: request.profileID)
    guard let requestBoot = boot(), requestBoot > 0 else { throw SupabaseUsageGrantError.retryable }
    let started = now()
    guard started.isFinite, started >= 0 else { throw SupabaseUsageGrantError.retryable }
    let grant = try await verify(kind, identifier, request.deviceKey, request.profileID, request.accessToken)
    guard UUID(uuidString: grant.sessionId) != nil,
          (kind != "easy" || UUID(uuidString: grant.sessionId) == UUID(uuidString: identifier)),
          grant.remainingMillis > 0, grant.remainingMillis <= grant.budgetMillis,
          grant.budgetMillis >= 1000, grant.budgetMillis <= 604_800_000 else { throw SupabaseUsageGrantError.rejected }
    let current = now()
    let deadline = started + Double(grant.remainingMillis)
    guard boot() == requestBoot, current.isFinite, current >= started, deadline.isFinite, deadline > current else {
      throw SupabaseUsageGrantError.expired
    }
    return MacHostsPreparedUsage(ownerUID: peerUID, profileID: request.profileID,
      sessionID: grant.sessionId, boot: requestBoot, deadline: deadline, policyFence: policyFence)
  }
}
