import Foundation

@main struct IosUsageStateCheck {
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bloom-ios-usage-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = BloomUsageFile(directory: directory)
    let started = Date(timeIntervalSince1970: 1000)
    try store.mutate { state in
      state = BloomUsageState(sessionId: "s", userId: "u", budgetMillis: 120_000,
        expiry: started.addingTimeInterval(600), startedAt: started)
    }
    try store.mutate { state in
      state?.refresh(now: started.addingTimeInterval(60))
      precondition(state?.usedMillis == 60_000 && state?.closed == false)
    }
    try store.mutate { state in
      // The target remains idle, but elapsed access time continues.
      state?.refresh(now: started.addingTimeInterval(90))
      precondition(state?.usedMillis == 90_000 && state?.closed == false)
      state?.finish(now: started.addingTimeInterval(90))
      precondition(state?.usedMillis == 90_000 && state?.closed == true && state?.finalized == true)
      state = nil
    }
    try store.mutate { state in
      state = BloomUsageState(sessionId: "s2", userId: "u", budgetMillis: 120_000,
        expiry: started.addingTimeInterval(5), startedAt: started)
    }
    try store.mutate { state in
      state?.refresh(now: started.addingTimeInterval(5))
      precondition(state?.usedMillis == 5_000 && state?.closed == true)
      state = nil
    }
    try store.mutate { state in
      state = BloomUsageState(sessionId: "s3", userId: "u", budgetMillis: 120_000,
        expiry: started.addingTimeInterval(600), startedAt: started)
    }
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      try! BloomUsageFile(directory: directory).mutate { state in
        state?.refresh(now: started.addingTimeInterval(Double(index + 1)))
      }
    }
    try store.mutate { state in
      precondition(state?.usedMillis == 100_000 && state?.closed == false)
      state = nil
    }
    print("iOS server-timed access checks passed")
  }
}
