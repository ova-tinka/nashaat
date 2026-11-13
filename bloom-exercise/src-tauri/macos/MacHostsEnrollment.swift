import Foundation

struct MacHostsApprovedRules {
  let manual: [String]
  let managed: [String]
  let combined: [String]
}

struct MacHostsEnrollment {
  let authorize: (Data) -> Bool
  let verifyProfile: (String, String) async throws -> Void
  let fetchManaged: (String, String) async throws -> [String]

  /// Profile verification is read-only; the grant is checked again when the
  /// serialized filesystem operation runs after the network request.
  func prepare(peerIdentifier: String?, peerUID: UInt32, authorization: Data,
               domains: Data, profileID: String, accessToken: String) async throws -> MacHostsApprovedRules {
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier, peerUID: peerUID),
          authorization.count == 32, authorize(authorization) else { throw SupabaseUsageGrantError.rejected }
    guard domains.count <= 100_000, let decoded = try? JSONDecoder().decode([String].self, from: domains),
          decoded.count <= 500, UUID(uuidString: profileID) != nil,
          !accessToken.isEmpty, accessToken.utf8.count <= 8192 else { throw SupabaseUsageGrantError.rejected }
    _ = try MacHostsPolicy.transform(Data(), domains: decoded)
    try await verifyProfile(profileID, accessToken)
    let managed = try await fetchManaged(profileID, accessToken)
    let combined = Array(Set(decoded + managed)).sorted()
    guard !combined.isEmpty, combined.count <= 500 else { throw MacHostsPolicy.Failure.tooLarge }
    _ = try MacHostsPolicy.transform(Data(), domains: combined)
    return MacHostsApprovedRules(manual: decoded, managed: managed, combined: combined)
  }
}
