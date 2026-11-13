import Foundation

private struct ManagedWebsiteRow: Decodable { let target_identifier: String }
private struct ExistingCountdownRequest: Encodable { let p_request_id: String; let p_device_key: String }
private struct ExistingCountdownResponse: Decodable { let request_id: String; let session_id: String; let remaining_ms: Int64 }
private struct ExistingUsageRequest: Encodable {
  let p_session_id: String
  let p_device_key: String
}
private final class ExistingUsageRedirectBlocker: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

/// Read-only verification. The RPC cannot create or settle a reservation.
enum SupabaseExistingUsageGrant {
  static func verifyProfile(profileID: String, accessToken: String) async throws {
    guard UUID(uuidString: profileID) != nil else { throw SupabaseUsageGrantError.configuration }
    let (status, data, _) = try await call("rpc/bloom_current_profile", body: Data("{}".utf8), accessToken: accessToken)
    try SupabaseUsageGrant.validateProfile(statusCode: status, data: data, expectedProfile: profileID)
  }

  static func verify(sessionID: String, deviceKey: String, profileID: String, accessToken: String) async throws -> VerifiedUsageGrant {
    guard UUID(uuidString: sessionID) != nil, UUID(uuidString: deviceKey) != nil else { throw SupabaseUsageGrantError.configuration }
    try await verifyProfile(profileID: profileID, accessToken: accessToken)
    let body = try JSONEncoder().encode(ExistingUsageRequest(p_session_id: sessionID, p_device_key: deviceKey))
    let (status, data, _) = try await call("rpc/bloom_verify_usage_grant", body: body, accessToken: accessToken)
    return try decode(statusCode: status, data: data, expectedSession: sessionID)
  }

  static func verifyCountdown(requestID: String, deviceKey: String, profileID: String, accessToken: String) async throws -> VerifiedUsageGrant {
    guard UUID(uuidString: requestID) != nil, UUID(uuidString: deviceKey) != nil else { throw SupabaseUsageGrantError.configuration }
    try await verifyProfile(profileID: profileID, accessToken: accessToken)
    let body = try JSONEncoder().encode(ExistingCountdownRequest(p_request_id: requestID, p_device_key: deviceKey))
    let (status, data, _) = try await call("rpc/bloom_verify_countdown_grant", body: body, accessToken: accessToken)
    return try decodeCountdown(statusCode: status, data: data, expectedRequest: requestID)
  }

  static func decodeCountdown(statusCode: Int, data: Data, expectedRequest: String) throws -> VerifiedUsageGrant {
    guard (200..<300).contains(statusCode) else {
      if statusCode == 401 || statusCode == 429 || statusCode >= 500 { throw SupabaseUsageGrantError.retryable }
      throw SupabaseUsageGrantError.rejected
    }
    guard let rows = try? JSONDecoder().decode([ExistingCountdownResponse].self, from: data), rows.count == 1,
          let row = rows.first, let actual = UUID(uuidString: row.request_id),
          let expected = UUID(uuidString: expectedRequest), actual == expected,
          UUID(uuidString: row.session_id) != nil, row.remaining_ms >= 0, row.remaining_ms <= 86_400_000 else {
      throw SupabaseUsageGrantError.rejected
    }
    guard row.remaining_ms > 0 else { throw SupabaseUsageGrantError.expired }
    return VerifiedUsageGrant(sessionId: row.session_id, budgetMillis: 86_400_000, remainingMillis: row.remaining_ms)
  }

  static func managedWebsites(profileID: String, accessToken: String) async throws -> [String] {
    guard let profile = UUID(uuidString: profileID) else { throw SupabaseUsageGrantError.configuration }
    let path = "bloom_blocking_rules?select=target_identifier&user_id=eq.\(profile.uuidString)&platform=eq.macos&target_type=eq.website&enabled=eq.true&limit=501"
    let (status, data, count) = try await call(path, body: nil, accessToken: accessToken)
    return try decodeManagedWebsites(statusCode: status, data: data, contentRange: count)
  }

  static func decodeManagedWebsites(statusCode: Int, data: Data, contentRange: String?) throws -> [String] {
    guard (200..<300).contains(statusCode), data.count <= 100_000,
          let rows = try? JSONDecoder().decode([ManagedWebsiteRow].self, from: data),
          let totalText = contentRange?.split(separator: "/", omittingEmptySubsequences: false).last,
          let total = Int(totalText), total == rows.count, total <= 500 else { throw SupabaseUsageGrantError.retryable }
    return rows.map(\.target_identifier)
  }

  private static func call(_ path: String, body: Data?, accessToken: String) async throws -> (Int, Data, String?) {
    guard !accessToken.isEmpty, accessToken.utf8.count <= 8192,
          let base = Bundle.main.object(forInfoDictionaryKey: "BloomSupabaseURL") as? String,
          let key = Bundle.main.object(forInfoDictionaryKey: "BloomSupabasePublishableKey") as? String,
          !key.isEmpty, key.utf8.count <= 512,
          let components = URLComponents(string: base), let scheme = components.scheme?.lowercased(),
          let host = components.host?.lowercased(), components.user == nil, components.password == nil,
          components.query == nil, components.fragment == nil, components.path.isEmpty || components.path == "/",
          (scheme == "https" && (components.port == nil || components.port == 443))
            || (scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host) && components.port != nil),
          let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/rest/v1/" + path)
    else { throw SupabaseUsageGrantError.configuration }
    let session = URLSession(configuration: .ephemeral, delegate: ExistingUsageRedirectBlocker(), delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    var request = URLRequest(url: url, timeoutInterval: 12)
    request.httpMethod = body == nil ? "GET" : "POST"
    if body == nil { request.setValue("count=exact", forHTTPHeaderField: "Prefer") }
    request.setValue(key, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, data.count <= 100_000 else { throw SupabaseUsageGrantError.retryable }
      return (http.statusCode, data, http.value(forHTTPHeaderField: "Content-Range"))
    } catch let error as SupabaseUsageGrantError { throw error }
    catch { throw SupabaseUsageGrantError.retryable }
  }

  static func decode(statusCode: Int, data: Data, expectedSession: String) throws -> VerifiedUsageGrant {
    let grant = try SupabaseUsageGrant.decodeResponse(statusCode: statusCode, data: data, requestedMillis: 604_800_000)
    guard let actual = UUID(uuidString: grant.sessionId), let expected = UUID(uuidString: expectedSession), actual == expected else {
      throw SupabaseUsageGrantError.rejected
    }
    return grant
  }
}
