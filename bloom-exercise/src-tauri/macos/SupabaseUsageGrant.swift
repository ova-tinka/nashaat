import Foundation

enum SupabaseUsageGrantError: LocalizedError {
  case configuration, rejected, retryable, expired, wrongProfile
  var errorDescription: String? {
    switch self {
    case .configuration: return "Bloom cannot verify this screen-time request."
    case .rejected: return "The server did not accept this screen-time reservation."
    case .retryable: return "Could not verify the reservation. Reconnect and retry the same request."
    case .expired: return "This screen-time reservation has ended. Sync it before starting another."
    case .wrongProfile: return "The reservation belongs to another Bloom profile."
    }
  }
}

struct VerifiedUsageGrant: Equatable {
  let sessionId: String
  let budgetMillis: Int64
  let remainingMillis: Int64
}

private struct UsageGrantRequest: Encodable {
  let p_request_id: String
  let p_device_key: String
  let p_requested_ms: Int64
}
private struct UsageGrantResponse: Decodable {
  let session_id: String
  let reserved_ms: Int64
  let expiry_remaining_ms: Int64
}
private struct UsageProfileResponse: Decodable { let profile_id: String }
private struct UsageOwnerResponse: Decodable {
  let user_id: String
  let settled_at: String?
  private enum CodingKeys: String, CodingKey { case user_id, settled_at }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    user_id = try values.decode(String.self, forKey: .user_id)
    guard values.contains(.settled_at) else { throw DecodingError.keyNotFound(CodingKeys.settled_at, .init(codingPath: decoder.codingPath, debugDescription: "Missing settlement state")) }
    settled_at = try values.decodeIfPresent(String.self, forKey: .settled_at)
  }
}
private struct UsageErrorResponse: Decodable { let message: String? }
private final class UsageRedirectBlocker: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

enum SupabaseUsageGrant {
  static func reserve(requestId: String, deviceKey: String, requestedMillis: Int64,
                      profileId: String, accessToken: String) async throws -> VerifiedUsageGrant {
    guard UUID(uuidString: requestId) != nil, UUID(uuidString: deviceKey) != nil,
          UUID(uuidString: profileId) != nil, requestedMillis >= 1000, requestedMillis <= 604_800_000,
          !accessToken.isEmpty, accessToken.utf8.count <= 8192,
          let base = Bundle.main.object(forInfoDictionaryKey: "BloomSupabaseURL") as? String,
          let key = Bundle.main.object(forInfoDictionaryKey: "BloomSupabasePublishableKey") as? String,
          !key.isEmpty, key.utf8.count <= 512,
          let components = URLComponents(string: base), let scheme = components.scheme?.lowercased(),
          let host = components.host?.lowercased(), components.user == nil, components.password == nil,
          components.query == nil, components.fragment == nil, components.path.isEmpty || components.path == "/",
          (scheme == "https" && (components.port == nil || components.port == 443))
            || (scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host) && components.port != nil) else {
      throw SupabaseUsageGrantError.configuration
    }
    let session = URLSession(configuration: .ephemeral, delegate: UsageRedirectBlocker(), delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    func call(_ path: String, body: Data?) async throws -> (Int, Data) {
      guard let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/rest/v1/" + path) else { throw SupabaseUsageGrantError.configuration }
      var request = URLRequest(url: url, timeoutInterval: 12)
      request.httpMethod = body == nil ? "GET" : "POST"
      request.setValue(key, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
      do {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, data.count <= 65_536 else { throw SupabaseUsageGrantError.retryable }
        return (response.statusCode, data)
      } catch let error as SupabaseUsageGrantError { throw error }
      catch { throw SupabaseUsageGrantError.retryable }
    }
    let (profileStatus, profileData) = try await call("rpc/bloom_current_profile", body: Data("{}".utf8))
    try validateProfile(statusCode: profileStatus, data: profileData, expectedProfile: profileId)
    let request = try JSONEncoder().encode(UsageGrantRequest(p_request_id: requestId, p_device_key: deviceKey, p_requested_ms: requestedMillis))
    let (status, data) = try await call("rpc/bloom_start_usage_session", body: request)
    let grant = try decodeResponse(statusCode: status, data: data, requestedMillis: requestedMillis)
    let (ownerStatus, ownerData) = try await call("bloom_usage_sessions?select=user_id,settled_at&id=eq.\(grant.sessionId)&limit=1", body: nil)
    try validateOwner(statusCode: ownerStatus, data: ownerData, expectedProfile: profileId)
    return grant
  }

  static func validateProfile(statusCode: Int, data: Data, expectedProfile: String) throws {
    try checkStatus(statusCode, data: data)
    guard let response = try? JSONDecoder().decode(UsageProfileResponse.self, from: data),
          let actual = UUID(uuidString: response.profile_id), let expected = UUID(uuidString: expectedProfile), actual == expected else {
      throw SupabaseUsageGrantError.wrongProfile
    }
  }

  static func decodeResponse(statusCode: Int, data: Data, requestedMillis: Int64) throws -> VerifiedUsageGrant {
    try checkStatus(statusCode, data: data)
    guard requestedMillis >= 1000, requestedMillis <= 604_800_000,
          let rows = try? JSONDecoder().decode([UsageGrantResponse].self, from: data), rows.count == 1,
          let row = rows.first, UUID(uuidString: row.session_id) != nil,
          row.reserved_ms >= 1000, row.reserved_ms <= requestedMillis,
          row.expiry_remaining_ms >= 0, row.expiry_remaining_ms <= row.reserved_ms else { throw SupabaseUsageGrantError.rejected }
    guard row.expiry_remaining_ms > 0 else { throw SupabaseUsageGrantError.expired }
    return VerifiedUsageGrant(sessionId: row.session_id, budgetMillis: row.reserved_ms, remainingMillis: row.expiry_remaining_ms)
  }

  static func validateOwner(statusCode: Int, data: Data, expectedProfile: String) throws {
    try checkStatus(statusCode, data: data)
    guard let rows = try? JSONDecoder().decode([UsageOwnerResponse].self, from: data), rows.count == 1,
          let actual = UUID(uuidString: rows[0].user_id), let expected = UUID(uuidString: expectedProfile), actual == expected else {
      throw SupabaseUsageGrantError.wrongProfile
    }
    if rows[0].settled_at != nil { throw SupabaseUsageGrantError.expired }
  }

  private static func checkStatus(_ statusCode: Int, data: Data) throws {
    guard (200..<300).contains(statusCode) else {
      if statusCode == 401 || statusCode == 429 || statusCode >= 500 { throw SupabaseUsageGrantError.retryable }
      let message = (try? JSONDecoder().decode(UsageErrorResponse.self, from: data).message)?.lowercased() ?? ""
      if message == "screen-time reservation has ended" { throw SupabaseUsageGrantError.expired }
      throw SupabaseUsageGrantError.rejected
    }
  }
}
