import Foundation
import CoreFoundation

/// Persist only changed group keys using the group domain’s synchronization result.
enum MacSharedPreferences {
  static func write(_ updates: [String: Any] = [:], removing removals: [String] = []) -> Bool {
    guard let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          Set(updates.keys).isDisjoint(with: Set(removals)) else { return false }
    let changed = updates.isEmpty ? nil : updates as CFDictionary
    let deleted = removals.isEmpty ? nil : removals as CFArray
    CFPreferencesSetMultiple(changed, deleted, group as CFString,
                             kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    guard CFPreferencesSynchronize(group as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return false }
    return true
  }
}
