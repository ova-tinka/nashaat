import Foundation

/// Privileged requests carry only a bounded domain list and a transient admin
/// authorization. Paths and commands are never accepted from the caller.
struct MacHostsHelper {
  let authorize: (Data) -> Bool
  let apply: ([String]) throws -> Void

  func update(peerIdentifier: String?, peerUID: UInt32, authorization: Data, encodedDomains: Data) -> String {
    guard MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: peerIdentifier, peerUID: peerUID),
          authorization.count == 32, authorize(authorization) else { return "denied" }
    guard encodedDomains.count <= 100_000,
          let domains = try? JSONDecoder().decode([String].self, from: encodedDomains), domains.count <= 500 else { return "invalid" }
    do {
      try apply(domains)
      return "updated"
    } catch MacHostsPolicy.Failure.invalidDomain {
      return "invalid"
    } catch MacHostsPolicy.Failure.conflict {
      return "conflict"
    } catch MacHostsPolicy.Failure.damagedBlock {
      return "conflict"
    } catch MacHostsPolicy.Failure.invalidFile {
      return "unsafe"
    } catch MacHostsPolicy.Failure.tooLarge {
      return "unsafe"
    } catch MacHostsTransaction.Failure.stale {
      return "stale"
    } catch MacHostsTransaction.Failure.changed {
      return "conflict"
    } catch MacHostsTransaction.Failure.unsafeDirectory {
      return "unsafe"
    } catch MacHostsTransaction.Failure.unsafeFile {
      return "unsafe"
    } catch MacHostsTransaction.Failure.busy {
      return "busy"
    } catch MacHostsTransaction.Failure.commitUncertain {
      return "uncertain"
    } catch MacHostsTransaction.Failure.recoveryRequired {
      return "recoveryRequired"
    } catch {
      return "unavailable"
    }
  }
}
