import Foundation

struct MacInstalledApp: Encodable {
  let id: String
  let name: String
}

struct MacInstalledApps: Encodable {
  let apps: [MacInstalledApp]
  let truncated: Bool

  /// Only fixed local application directories are passed in by the caller.
  /// Bundle contents and symlinks are not traversed, and no paths are returned.
  static func scan(roots: [URL], maxApps: Int = 200) -> MacInstalledApps {
    let limit = max(1, min(maxApps, 200))
    var found: [String: MacInstalledApp] = [:]
    var visited = 0
    var truncated = false
    for root in roots {
      guard let enumerator = FileManager.default.enumerator(at: root,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else { continue }
      while let url = enumerator.nextObject() as? URL {
        visited += 1
        if visited > 10_000 { truncated = true; break }
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { continue }
        if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
        guard values.isDirectory == true, url.pathExtension.lowercased() == "app" else { continue }
        enumerator.skipDescendants()
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              let id = MacAppRules.normalize([identifier])?.first, found[id] == nil else { continue }
        if found.count >= limit { truncated = true; break }
        let rawName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
          ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
          ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
          ?? url.deletingPathExtension().lastPathComponent
        var name = ""
        for scalar in rawName.unicodeScalars where !CharacterSet.controlCharacters.contains(scalar) {
          let next = name + String(scalar)
          if next.utf8.count > 80 { break }
          name = next
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        found[id] = MacInstalledApp(id: id, name: name.isEmpty ? String(id.prefix(80)) : name)
      }
      if truncated { break }
    }
    let apps = found.values.sorted {
      let order = $0.name.localizedCaseInsensitiveCompare($1.name)
      return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
    }
    return MacInstalledApps(apps: apps, truncated: truncated)
  }
}
