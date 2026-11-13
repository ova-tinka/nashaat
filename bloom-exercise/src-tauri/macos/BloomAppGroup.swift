import Foundation
import Security

enum BloomAppGroup {
  static var identifier: String? {
    if let configured = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String {
      return configured
    }
    guard let task = SecTaskCreateFromSelf(kCFAllocatorDefault),
          let groups = SecTaskCopyValueForEntitlement(
            task, "com.apple.security.application-groups" as CFString, nil
          ) as? [String] else { return nil }
    return groups.first
  }
}
