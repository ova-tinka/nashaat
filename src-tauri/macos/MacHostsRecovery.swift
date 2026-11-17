import Foundation

/// Only a coarse result crosses XPC; file paths and contents remain private.
enum MacHostsRecovery {
  static func status(_ recover: () throws -> Void) -> String {
    do { try recover(); return "clear" }
    catch MacHostsTransaction.Failure.recoveryRequired { return "review" }
    catch MacHostsTransaction.Failure.busy { return "busy" }
    catch MacHostsTransaction.Failure.unsafeDirectory { return "unsafe" }
    catch MacHostsTransaction.Failure.unsafeFile { return "unsafe" }
    catch { return "unavailable" }
  }
}
