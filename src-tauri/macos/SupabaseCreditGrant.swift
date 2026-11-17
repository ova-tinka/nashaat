import Foundation

enum SupabaseCreditGrantError: Error {
  case configuration
  case rejected
  case retryable
  case expired
}

private struct CreditGrantRequest: Encodable {
  let p_request_id: String
  let p_device_key: String
  let p_minutes: Double
}

private struct CreditGrantResponse: Decodable {
  let session_id: String
  let remaining_ms: Int64
}

struct VerifiedCreditGrant: Equatable {
  let sessionId: String
  let remainingMillis: Int64
}

private struct CreditGrantErrorResponse: Decodable {
  let message: String?
}

private final class CreditGrantRedirectBlocker: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

/// Obtains the authoritative countdown from Supabase inside the signed native
/// bridge. Renderer supplied timing values never open local protection.
enum SupabaseCreditGrant {
  static func start(requestId: String, deviceKey: String, minutes: Double, accessToken: String) async throws -> VerifiedCreditGrant {
    guard let base = Bundle.main.object(forInfoDictionaryKey: "BloomSupabaseURL") as? String,
          let publishableKey = Bundle.main.object(forInfoDictionaryKey: "BloomSupabasePublishableKey") as? String,
          let components = URLComponents(string: base),
          let scheme = components.scheme?.lowercased(),
          let host = components.host?.lowercased(),
          components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
          components.path.isEmpty || components.path == "/",
          ((scheme == "https" && (components.port == nil || components.port == 443))
            || (scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host) && components.port != nil)),
          let endpoint = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/rest/v1/rpc/bloom_start_enforced_credit_session"),
          UUID(uuidString: requestId) != nil, UUID(uuidString: deviceKey) != nil,
          minutes.isFinite, minutes > 0, minutes <= 1440,
          !accessToken.isEmpty, accessToken.utf8.count <= 8192,
          !publishableKey.isEmpty, publishableKey.utf8.count <= 512 else { throw SupabaseCreditGrantError.configuration }

    var request = URLRequest(url: endpoint, timeoutInterval: 12)
    request.httpMethod = "POST"
    request.setValue(publishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(CreditGrantRequest(
      p_request_id: requestId, p_device_key: deviceKey, p_minutes: minutes))

    let session = URLSession(configuration: .ephemeral, delegate: CreditGrantRedirectBlocker(), delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw SupabaseCreditGrantError.rejected }
    if http.statusCode == 401 || http.statusCode == 429 || http.statusCode >= 500 {
      throw SupabaseCreditGrantError.retryable
    }
    return try decodeResponse(statusCode: http.statusCode, data: data)
  }

  static func decodeResponse(statusCode: Int, data: Data) throws -> VerifiedCreditGrant {
    guard (200..<300).contains(statusCode) else {
      let serverMessage = (try? JSONDecoder().decode(CreditGrantErrorResponse.self, from: data).message)?.lowercased() ?? ""
      if serverMessage == "screen-time session has ended" { throw SupabaseCreditGrantError.expired }
      if statusCode == 400 || statusCode == 403 { throw SupabaseCreditGrantError.rejected }
      throw SupabaseCreditGrantError.retryable
    }
    guard let grant = try? JSONDecoder().decode([CreditGrantResponse].self, from: data),
          grant.count == 1, let first = grant.first, UUID(uuidString: first.session_id) != nil,
          first.remaining_ms > 0, first.remaining_ms <= 86_400_000 else {
      throw SupabaseCreditGrantError.rejected
    }
    return VerifiedCreditGrant(sessionId: first.session_id, remainingMillis: first.remaining_ms)
  }
}
