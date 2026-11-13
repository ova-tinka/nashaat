import Foundation

@main struct SupabaseUsageGrantCheck {
  static func main() throws {
    let profile = "10000000-0000-4000-8000-000000000001"
    let session = "20000000-0000-4000-8000-000000000002"
    try SupabaseUsageGrant.validateProfile(statusCode: 200, data: Data("{\"profile_id\":\"\(profile)\"}".utf8), expectedProfile: profile)
    do {
      try SupabaseUsageGrant.validateProfile(statusCode: 200, data: Data("{\"profile_id\":\"\(session)\"}".utf8), expectedProfile: profile)
      preconditionFailure("cross-profile response accepted")
    } catch SupabaseUsageGrantError.wrongProfile {}
    try SupabaseUsageGrant.validateOwner(statusCode: 200, data: Data("[{\"user_id\":\"\(profile)\",\"settled_at\":null}]".utf8), expectedProfile: profile)
    for invalidOwner in ["[]", "[{\"user_id\":\"\(session)\",\"settled_at\":null}]", "[{\"user_id\":\"\(profile)\"}]"] {
      do { try SupabaseUsageGrant.validateOwner(statusCode: 200, data: Data(invalidOwner.utf8), expectedProfile: profile); preconditionFailure("unverified reservation owner accepted") }
      catch SupabaseUsageGrantError.wrongProfile {}
    }
    do { try SupabaseUsageGrant.validateOwner(statusCode: 200, data: Data("[{\"user_id\":\"\(profile)\",\"settled_at\":\"2026-01-01T00:00:00Z\"}]".utf8), expectedProfile: profile); preconditionFailure("settled reservation accepted") }
    catch SupabaseUsageGrantError.expired {}
    let valid = Data("[{\"session_id\":\"\(session)\",\"reserved_ms\":60000,\"expiry_remaining_ms\":59000}]".utf8)
    let grant = try SupabaseUsageGrant.decodeResponse(statusCode: 200, data: valid, requestedMillis: 60000)
    precondition(grant == VerifiedUsageGrant(sessionId: session, budgetMillis: 60000, remainingMillis: 59000))
    let managedData = Data("[{\"target_identifier\":\"parent.example.com\"}]".utf8)
    let managed = try SupabaseExistingUsageGrant.decodeManagedWebsites(statusCode: 200, data: managedData, contentRange: "0-0/1")
    precondition(managed == ["parent.example.com"])
    for range in ["0-0/2", "0-0/*", "bad"] {
      do {
        _ = try SupabaseExistingUsageGrant.decodeManagedWebsites(statusCode: 200, data: managedData, contentRange: range)
        preconditionFailure("truncated managed rules accepted")
      } catch SupabaseUsageGrantError.retryable {}
    }
    let requestID = "30000000-0000-4000-8000-000000000003"
    let countdown = Data("[{\"request_id\":\"\(requestID)\",\"session_id\":\"\(session)\",\"remaining_ms\":5000}]".utf8)
    let countdownGrant = try SupabaseExistingUsageGrant.decodeCountdown(statusCode: 200, data: countdown, expectedRequest: requestID)
    precondition(countdownGrant.sessionId == session && countdownGrant.remainingMillis == 5000)
    do {
      _ = try SupabaseExistingUsageGrant.decodeCountdown(statusCode: 200, data: countdown, expectedRequest: profile)
      preconditionFailure("wrong countdown request accepted")
    } catch SupabaseUsageGrantError.rejected {}
    let expiredCountdown = Data("[{\"request_id\":\"\(requestID)\",\"session_id\":\"\(session)\",\"remaining_ms\":0}]".utf8)
    do {
      _ = try SupabaseExistingUsageGrant.decodeCountdown(statusCode: 200, data: expiredCountdown, expectedRequest: requestID)
      preconditionFailure("expired countdown accepted")
    } catch SupabaseUsageGrantError.expired {}
    let checked = try SupabaseExistingUsageGrant.decode(statusCode: 200, data: valid, expectedSession: session)
    precondition(checked == grant)
    do {
      _ = try SupabaseExistingUsageGrant.decode(statusCode: 200, data: valid, expectedSession: profile)
      preconditionFailure("wrong reservation accepted")
    } catch SupabaseUsageGrantError.rejected {}
    let expired = Data("[{\"session_id\":\"\(session)\",\"reserved_ms\":60000,\"expiry_remaining_ms\":0}]".utf8)
    do { _ = try SupabaseUsageGrant.decodeResponse(statusCode: 200, data: expired, requestedMillis: 60000); preconditionFailure("expired grant accepted") }
    catch SupabaseUsageGrantError.expired {}
    for invalid in [
      "[]", "not-json", "[{\"session_id\":\"bad\",\"reserved_ms\":60000,\"expiry_remaining_ms\":1}]",
      "[{\"session_id\":\"\(session)\",\"reserved_ms\":60001,\"expiry_remaining_ms\":1}]",
      "[{\"session_id\":\"\(session)\",\"reserved_ms\":1000,\"expiry_remaining_ms\":1001}]",
      "[{\"session_id\":\"\(session)\",\"reserved_ms\":999,\"expiry_remaining_ms\":1}]"
    ] {
      do { _ = try SupabaseUsageGrant.decodeResponse(statusCode: 200, data: Data(invalid.utf8), requestedMillis: 60000); preconditionFailure("invalid grant accepted") }
      catch SupabaseUsageGrantError.rejected {}
    }
    do { _ = try SupabaseUsageGrant.decodeResponse(statusCode: 503, data: Data(), requestedMillis: 60000); preconditionFailure("server failure accepted") }
    catch SupabaseUsageGrantError.retryable {}
    print("macOS server usage grant checks passed")
  }
}
