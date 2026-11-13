import Foundation
import Security

/// A short-lived administrator grant. Never persist or return its external form
/// to the renderer; it is sent directly to the signed privileged helper.
final class MacHostsAdminGrant {
  private let reference: AuthorizationRef
  private init(_ reference: AuthorizationRef) { self.reference = reference }
  deinit { AuthorizationFree(reference, []) }

  static func request() throws -> MacHostsAdminGrant {
    var reference: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &reference) == errAuthorizationSuccess, let reference else { throw Failure.denied }
    let status = withAdminRight { rights in
      AuthorizationCopyRights(reference, rights, nil, [.interactionAllowed, .extendRights, .preAuthorize], nil)
    }
    guard status == errAuthorizationSuccess else { AuthorizationFree(reference, []); throw Failure.denied }
    return MacHostsAdminGrant(reference)
  }

  func externalForm() throws -> Data {
    var form = AuthorizationExternalForm()
    guard AuthorizationMakeExternalForm(reference, &form) == errAuthorizationSuccess else { throw Failure.denied }
    return withUnsafeBytes(of: &form) { Data($0) }
  }

  static func validate(_ data: Data) -> Bool {
    guard data.count == MemoryLayout<AuthorizationExternalForm>.size else { return false }
    var form = AuthorizationExternalForm()
    _ = withUnsafeMutableBytes(of: &form) { destination in data.copyBytes(to: destination) }
    var reference: AuthorizationRef?
    guard AuthorizationCreateFromExternalForm(&form, &reference) == errAuthorizationSuccess, let reference else { return false }
    defer { AuthorizationFree(reference, []) }
    return withAdminRight { rights in AuthorizationCopyRights(reference, rights, nil, [], nil) } == errAuthorizationSuccess
  }

  private static func withAdminRight(_ operation: (UnsafePointer<AuthorizationRights>) -> OSStatus) -> OSStatus {
    kAuthorizationRightExecute.withCString { name in
      var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
      return withUnsafeMutablePointer(to: &item) { pointer in
        var rights = AuthorizationRights(count: 1, items: pointer)
        return withUnsafePointer(to: &rights, operation)
      }
    }
  }

  enum Failure: Error { case denied }
}
