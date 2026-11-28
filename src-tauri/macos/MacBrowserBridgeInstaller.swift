import AppKit
import Foundation

enum MacBrowserBridgeInstaller {
  static let hostName = "com.focusflow.focusflowflutter.bridge"
  static let devExtensionId = "kcjdfbacapjojhpoeokomfcdbdjgkidh"
  static let extensionId = devExtensionId
  static let heartbeatFreshWindowMillis: Double = 120_000

  struct BrowserCandidate: Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let relativeAppSupportPath: String
    let supportsExternalExtensions: Bool
  }

  struct BrowserProtectionEntry: Encodable, Equatable {
    let id: String
    let name: String
    let installed: Bool
    let nativeBridgeInstalled: Bool
    let externalExtensionConfigured: Bool
    let managedProfileEnforced: Bool
    let extensionHeartbeatFresh: Bool
    let lastHeartbeatMillis: Double
  }

  struct BrowserProtectionSnapshot: Encodable, Equatable {
    let storeExtensionConfigured: Bool
    let storeExtensionId: String
    let browsers: [BrowserProtectionEntry]
    let safariBundled: Bool
    let safariEnabled: Bool?
  }

  enum ProfileError: LocalizedError {
    case storeExtensionNotConfigured

    var errorDescription: String? {
      switch self {
      case .storeExtensionNotConfigured:
        return "Chrome Web Store extension ID is not configured in this build yet. Publish the packaged extension and rebuild with BLOOM_CHROME_EXTENSION_ID."
      }
    }
  }

  static let browserCandidates: [BrowserCandidate] = [
    BrowserCandidate(
      id: "brave",
      name: "Brave",
      bundleIdentifier: "com.brave.Browser",
      relativeAppSupportPath: "BraveSoftware/Brave-Browser",
      supportsExternalExtensions: true
    ),
    BrowserCandidate(
      id: "chrome",
      name: "Google Chrome",
      bundleIdentifier: "com.google.Chrome",
      relativeAppSupportPath: "Google/Chrome",
      supportsExternalExtensions: true
    ),
    BrowserCandidate(
      id: "chrome-beta",
      name: "Google Chrome Beta",
      bundleIdentifier: "com.google.Chrome.beta",
      relativeAppSupportPath: "Google/Chrome Beta",
      supportsExternalExtensions: false
    ),
    BrowserCandidate(
      id: "edge",
      name: "Microsoft Edge",
      bundleIdentifier: "com.microsoft.edgemac",
      relativeAppSupportPath: "Microsoft Edge",
      supportsExternalExtensions: true
    ),
    BrowserCandidate(
      id: "arc",
      name: "Arc",
      bundleIdentifier: "company.thebrowser.Browser",
      relativeAppSupportPath: "Arc/User Data",
      supportsExternalExtensions: false
    ),
  ]

  static func configuredStoreExtensionId(bundle: Bundle = .main) -> String? {
    guard let raw = (bundle.object(forInfoDictionaryKey: "BloomChromeExtensionId") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      MacBrowserPolicyProfile.isValidExtensionId(raw) else {
      return nil
    }
    return raw
  }

  static func allowedExtensionIds(bundle: Bundle = .main, includeDev: Bool = true) -> [String] {
    var ids: [String] = []
    if let storeId = configuredStoreExtensionId(bundle: bundle) {
      ids.append(storeId)
    }
    if includeDev && !ids.contains(devExtensionId) {
      ids.append(devExtensionId)
    }
    return ids
  }

  static func manifestData(bridgePath: String, extensionIds: [String] = [extensionId]) throws -> Data {
    let origins = extensionIds.map { "chrome-extension://\($0)/" }
    let payload: [String: Any] = [
      "name": hostName,
      "description": "Bloom Focus browser bridge",
      "path": bridgePath,
      "type": "stdio",
      "allowed_origins": origins,
    ]
    return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
  }

  static func externalExtensionData() throws -> Data {
    let payload: [String: Any] = [
      "external_update_url": MacBrowserPolicyProfile.chromeWebStoreUpdateURL,
    ]
    return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
  }

  static func nativeMessagingDirectories(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
    let appSupport = homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    return browserCandidates
      .map { appSupport.appendingPathComponent($0.relativeAppSupportPath, isDirectory: true) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
      .map { $0.appendingPathComponent("NativeMessagingHosts", isDirectory: true) }
  }

  static func externalExtensionDirectories(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
    let appSupport = homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    return browserCandidates
      .filter(\.supportsExternalExtensions)
      .map { appSupport.appendingPathComponent($0.relativeAppSupportPath, isDirectory: true) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
      .map { $0.appendingPathComponent("External Extensions", isDirectory: true) }
  }

  static func install(bridgePath: String, directories: [URL], extensionIds: [String] = [extensionId]) throws -> Int {
    guard !bridgePath.isEmpty, !directories.isEmpty else { return 0 }
    let data = try manifestData(bridgePath: bridgePath, extensionIds: extensionIds)
    var installed = 0
    for directory in directories {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let target = directory.appendingPathComponent("\(hostName).json", isDirectory: false)
      try data.write(to: target, options: .atomic)
      installed += 1
    }
    return installed
  }

  static func installExternalExtensions(extensionId: String, directories: [URL]) throws -> Int {
    guard MacBrowserPolicyProfile.isValidExtensionId(extensionId) else {
      throw MacBrowserPolicyProfile.ProfileError.invalidExtensionId
    }
    guard !directories.isEmpty else { return 0 }
    let data = try externalExtensionData()
    var installed = 0
    for directory in directories {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let target = directory.appendingPathComponent("\(extensionId).json", isDirectory: false)
      try data.write(to: target, options: .atomic)
      installed += 1
    }
    return installed
  }

  @discardableResult
  static func installFromMainBundle() -> Int {
    installAllFromMainBundle().nativeBridges
  }

  @discardableResult
  static func installAllFromMainBundle(bundle: Bundle = .main,
                                       homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> (nativeBridges: Int, externalExtensions: Int, storeExtensionId: String?) {
    let bridge = bundle.bundleURL.appendingPathComponent("Contents/MacOS/BloomBrowserBridge")
    guard FileManager.default.isExecutableFile(atPath: bridge.path) else {
      return (0, 0, configuredStoreExtensionId(bundle: bundle))
    }
    let ids = allowedExtensionIds(bundle: bundle)
    let nativeCount = (try? install(
      bridgePath: bridge.path,
      directories: nativeMessagingDirectories(homeDirectory: homeDirectory),
      extensionIds: ids
    )) ?? 0

    let storeId = configuredStoreExtensionId(bundle: bundle)
    var externalCount = 0
    if let storeId {
      externalCount = (try? installExternalExtensions(
        extensionId: storeId,
        directories: externalExtensionDirectories(homeDirectory: homeDirectory)
      )) ?? 0
    }
    return (nativeCount, externalCount, storeId)
  }

  static func openProtectionProfile(strict: Bool, bundle: Bundle = .main,
                                    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> String {
    let fileName = strict
      ? "BloomBrowserProtectionStrict.mobileconfig"
      : "BloomBrowserProtection.mobileconfig"

    let targetURL: URL
    if let bundled = bundle.resourceURL?.appendingPathComponent(fileName),
       FileManager.default.isReadableFile(atPath: bundled.path) {
      targetURL = bundled
    } else if let storeId = configuredStoreExtensionId(bundle: bundle) {
      let data = try MacBrowserPolicyProfile.mobileconfigData(extensionId: storeId, strict: strict)
      let supportDir = homeDirectory.appendingPathComponent("Library/Application Support/Bloom", isDirectory: true)
      try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
      let generated = supportDir.appendingPathComponent(fileName, isDirectory: false)
      try data.write(to: generated, options: .atomic)
      targetURL = generated
    } else {
      throw ProfileError.storeExtensionNotConfigured
    }

    _ = NSWorkspace.shared.open(targetURL)
    let settingsCandidates = [
      "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
      "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
    ]
    for candidate in settingsCandidates {
      if let url = URL(string: candidate), NSWorkspace.shared.open(url) { break }
    }
    return "opened"
  }

  static func protectionStatus(bundle: Bundle = .main,
                               homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                               nowMillis: Double = Date().timeIntervalSince1970 * 1000) -> BrowserProtectionSnapshot {
    let storeId = configuredStoreExtensionId(bundle: bundle)
    let appSupport = homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    let heartbeats: [String: Double] = {
      guard let group = BloomAppGroup.identifier,
            let defaults = UserDefaults(suiteName: group),
            let raw = defaults.dictionary(forKey: "browserExtensionHeartbeats") else {
        return [:]
      }
      var result: [String: Double] = [:]
      for (key, value) in raw {
        if let number = value as? NSNumber {
          result[key] = number.doubleValue
        }
      }
      return result
    }()

    let primaryBrowsers = browserCandidates.filter { ["brave", "chrome", "edge", "arc"].contains($0.id) }
    let entries: [BrowserProtectionEntry] = primaryBrowsers.map { candidate in
      let dataDir = appSupport.appendingPathComponent(candidate.relativeAppSupportPath, isDirectory: true)
      let installed = FileManager.default.fileExists(atPath: dataDir.path)
      let bridgeFile = dataDir
        .appendingPathComponent("NativeMessagingHosts", isDirectory: true)
        .appendingPathComponent("\(hostName).json", isDirectory: false)
      let bridgeInstalled = FileManager.default.isReadableFile(atPath: bridgeFile.path)

      let externalConfigured: Bool = {
        guard candidate.supportsExternalExtensions, let storeId else { return false }
        let extFile = dataDir
          .appendingPathComponent("External Extensions", isDirectory: true)
          .appendingPathComponent("\(storeId).json", isDirectory: false)
        return FileManager.default.isReadableFile(atPath: extFile.path)
      }()

      let policyEnforced = storeId.map {
        MacBrowserPolicyProfile.isManagedPolicyEnforced(bundleIdentifier: candidate.bundleIdentifier, extensionId: $0)
      } ?? false

      let heartbeat = heartbeats[candidate.id] ?? 0
      let heartbeatFresh = heartbeat > 0 && nowMillis >= heartbeat && (nowMillis - heartbeat) <= heartbeatFreshWindowMillis

      return BrowserProtectionEntry(
        id: candidate.id,
        name: candidate.name,
        installed: installed,
        nativeBridgeInstalled: bridgeInstalled,
        externalExtensionConfigured: externalConfigured,
        managedProfileEnforced: policyEnforced,
        extensionHeartbeatFresh: heartbeatFresh,
        lastHeartbeatMillis: heartbeat
      )
    }

    let safariPlugIn = bundle.bundleURL.appendingPathComponent("Contents/PlugIns/BloomSafariExtension.appex", isDirectory: true)
    let safariBundled = FileManager.default.fileExists(atPath: safariPlugIn.path)
    let safariHeartbeat = heartbeats["safari"] ?? 0
    let safariEnabled: Bool? = safariBundled
      ? (safariHeartbeat > 0 && nowMillis >= safariHeartbeat && (nowMillis - safariHeartbeat) <= heartbeatFreshWindowMillis)
      : nil

    return BrowserProtectionSnapshot(
      storeExtensionConfigured: storeId != nil,
      storeExtensionId: storeId ?? "",
      browsers: entries,
      safariBundled: safariBundled,
      safariEnabled: safariEnabled
    )
  }
}
