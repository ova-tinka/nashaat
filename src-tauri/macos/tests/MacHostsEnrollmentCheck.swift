import Foundation

@main struct MacHostsEnrollmentCheck {
  static func main() async throws {
    let host = MacPolicyBrokerAccessPolicy.hostIdentifier
    let admin = Data(repeating: 42, count: 32)
    let profile = "10000000-0000-4000-8000-000000000001"
    let domains = try JSONEncoder().encode(["example.com"])
    var checks = 0
    let enrollment = MacHostsEnrollment(authorize: { $0 == admin }, verifyProfile: { actual, token in
      checks += 1
      guard actual == profile, token == "synthetic-token" else { throw SupabaseUsageGrantError.wrongProfile }
    }, fetchManaged: { _, _ in ["parent.example.com"] })
    do {
      _ = try await enrollment.prepare(peerIdentifier: "untrusted", peerUID: 501, authorization: admin,
        domains: domains, profileID: profile, accessToken: "synthetic-token")
      preconditionFailure("untrusted peer enrolled")
    } catch SupabaseUsageGrantError.rejected {}
    do {
      _ = try await enrollment.prepare(peerIdentifier: host, peerUID: 501, authorization: Data(repeating: 43, count: 32),
        domains: domains, profileID: profile, accessToken: "synthetic-token")
      preconditionFailure("invalid admin grant enrolled")
    } catch SupabaseUsageGrantError.rejected {}
    do {
      let invalid = try JSONEncoder().encode(["https://example.com/path"])
      _ = try await enrollment.prepare(peerIdentifier: host, peerUID: 501, authorization: admin,
        domains: invalid, profileID: profile, accessToken: "synthetic-token")
      preconditionFailure("invalid domain enrolled")
    } catch MacHostsPolicy.Failure.invalidDomain {}
    precondition(checks == 0)
    do {
      _ = try await enrollment.prepare(peerIdentifier: host, peerUID: 501, authorization: admin,
        domains: domains, profileID: profile, accessToken: "another-synthetic-token")
      preconditionFailure("wrong account enrolled")
    } catch SupabaseUsageGrantError.wrongProfile {}
    let approved = try await enrollment.prepare(peerIdentifier: host, peerUID: 501, authorization: admin,
      domains: domains, profileID: profile, accessToken: "synthetic-token")
    precondition(checks == 2 && Set(approved.combined) == Set(["example.com", "parent.example.com"]) && approved.manual == ["example.com"] && approved.managed == ["parent.example.com"])
    var adminStillValid = true
    let revoked = MacHostsEnrollment(authorize: { _ in adminStillValid }, verifyProfile: { _, _ in
      adminStillValid = false
    }, fetchManaged: { _, _ in [] })
    let afterCheck = try await revoked.prepare(peerIdentifier: host, peerUID: 501, authorization: admin,
      domains: domains, profileID: profile, accessToken: "synthetic-token")
    var applied = false
    let helper = MacHostsHelper(authorize: { _ in adminStillValid }, apply: { _ in applied = true })
    let result = helper.update(peerIdentifier: host, peerUID: 501, authorization: admin,
      encodedDomains: try JSONEncoder().encode(afterCheck.combined))
    precondition(result == "denied" && !applied)
    print("macOS hosts enrollment checks passed")
  }
}
