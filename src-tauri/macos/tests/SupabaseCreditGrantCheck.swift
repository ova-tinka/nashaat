import Foundation

@main struct SupabaseCreditGrantCheck {
  static func main() {
    let session = "10000000-0000-4000-8000-000000000001"
    let valid = Data("[{\"session_id\":\"\(session)\",\"remaining_ms\":59000}]".utf8)
    precondition(try! SupabaseCreditGrant.decodeResponse(statusCode: 200, data: valid)
      == VerifiedCreditGrant(sessionId: session, remainingMillis: 59000))

    let expired = Data("{\"message\":\"Screen-time session has ended\"}".utf8)
    do {
      _ = try SupabaseCreditGrant.decodeResponse(statusCode: 400, data: expired)
      preconditionFailure("An expired owner-bound session must not grant access.")
    } catch SupabaseCreditGrantError.expired {
    } catch {
      preconditionFailure("An expired session returned the wrong result.")
    }

    for invalid in [
      Data("[]".utf8),
      Data("[{\"session_id\":\"\(session)\",\"remaining_ms\":0}]".utf8),
      Data("[{\"session_id\":\"\(session)\",\"remaining_ms\":86400001}]".utf8),
      Data("[{\"session_id\":\"bad\",\"remaining_ms\":59000}]".utf8),
      Data("not-json".utf8),
    ] {
      do {
        _ = try SupabaseCreditGrant.decodeResponse(statusCode: 200, data: invalid)
        preconditionFailure("An invalid server lease must not grant access.")
      } catch SupabaseCreditGrantError.rejected {
      } catch {
        preconditionFailure("An invalid server lease returned the wrong result.")
      }
    }
    print("macOS server credit grant checks passed")
  }
}
