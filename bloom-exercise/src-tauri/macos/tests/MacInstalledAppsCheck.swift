import Foundation

@main struct MacInstalledAppsCheck {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    defer { try? FileManager.default.removeItem(at: outside) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    func app(_ name: String, _ id: String, _ display: String) throws {
      let contents = root.appendingPathComponent(name + ".app/Contents")
      try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
      let info: [String: String] = ["CFBundleIdentifier": id, "CFBundleName": display, "CFBundlePackageType": "APPL"]
      let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
      try data.write(to: contents.appendingPathComponent("Info.plist"))
    }
    try app("One", "com.example.one", "One")
    try app("Duplicate", "com.example.one", "Duplicate")
    try app("Finder", "com.apple.finder", "Finder")
    try app("Bloom", MacAppRules.ownBundle, "Bloom")
    try app("Two", "com.example.two", "Two")
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Link.app"), withDestinationURL: root.appendingPathComponent("Two.app"))
    let outsideContents = outside.appendingPathComponent("Outside.app/Contents")
    try FileManager.default.createDirectory(at: outsideContents, withIntermediateDirectories: true)
    let outsideInfo = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.example.outside", "CFBundleName": "Outside", "CFBundlePackageType": "APPL"], format: .xml, options: 0)
    try outsideInfo.write(to: outsideContents.appendingPathComponent("Info.plist"))
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("External"), withDestinationURL: outside)
    let result = MacInstalledApps.scan(roots: [root], maxApps: 200)
    precondition(Set(result.apps.map(\.id)) == Set(["com.example.one", "com.example.two"]))
    precondition(!result.truncated)
    precondition(result.apps.allSatisfy { $0.name.utf8.count <= 80 })
    let limited = MacInstalledApps.scan(roots: [root], maxApps: 1)
    precondition(limited.apps.count == 1 && limited.truncated)
    print("macOS installed app catalog checks passed")
  }
}
