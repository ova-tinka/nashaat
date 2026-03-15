import Flutter
import UIKit

// FamilyControls and ManagedSettings are imported conditionally so the project
// compiles on simulators that don't support all Screen Time APIs.
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// Handles the "com.nashaat/blocking" Flutter method channel on iOS.
///
/// Requires the `com.apple.developer.family-controls` entitlement and
/// iOS 16+. On older OS versions all blocking calls are no-ops.
@objc class BlockingPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.nashaat/blocking",
            binaryMessenger: registrar.messenger()
        )
        let instance = BlockingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            switch call.method {
            case "checkPermissions":
                checkPermissions(result: result)
            case "requestPermission":
                requestPermission(result: result)
            case "presentAppPicker":
                presentAppPicker(result: result)
            case "startBlocking":
                startBlocking(result: result)
            case "stopBlocking":
                stopBlocking(result: result)
            case "isBlockingActive":
                isBlockingActive(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            // iOS < 16: return safe defaults
            switch call.method {
            case "checkPermissions":
                result(["familyControls": false])
            case "isBlockingActive":
                result(false)
            default:
                result(nil)
            }
        }
    }

    // ── Permission ────────────────────────────────────────────────────────────

    @available(iOS 16.0, *)
    private func checkPermissions(result: @escaping FlutterResult) {
        #if canImport(FamilyControls)
        let granted = AuthorizationCenter.shared.authorizationStatus == .approved
        result(["familyControls": granted])
        #else
        result(["familyControls": false])
        #endif
    }

    @available(iOS 16.0, *)
    private func requestPermission(result: @escaping FlutterResult) {
        #if canImport(FamilyControls)
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { result(true) }
            } catch {
                await MainActor.run { result(false) }
            }
        }
        #else
        result(false)
        #endif
    }

    // ── App picker ────────────────────────────────────────────────────────────

    /// Presents the native FamilyActivityPicker in a UIHostingController.
    /// When the user confirms, the selection is persisted and blocking is applied.
    @available(iOS 16.0, *)
    private func presentAppPicker(result: @escaping FlutterResult) {
        #if canImport(FamilyControls)
        DispatchQueue.main.async {
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController else {
                result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
                return
            }

            let pickerVC = FamilyActivityPickerViewController { selection in
                // Persist and apply the selection
                BlockingStore.shared.saveSelection(selection)
                BlockingStore.shared.applyBlocking()
                result(nil)
            } onCancel: {
                result(nil)
            }

            rootVC.present(pickerVC, animated: true)
        }
        #else
        result(nil)
        #endif
    }

    // ── Blocking ──────────────────────────────────────────────────────────────

    @available(iOS 16.0, *)
    private func startBlocking(result: @escaping FlutterResult) {
        #if canImport(ManagedSettings)
        BlockingStore.shared.applyBlocking()
        UserDefaults.standard.set(true, forKey: "nashaat_blocking_active")
        result(nil)
        #else
        result(nil)
        #endif
    }

    @available(iOS 16.0, *)
    private func stopBlocking(result: @escaping FlutterResult) {
        #if canImport(ManagedSettings)
        BlockingStore.shared.removeBlocking()
        UserDefaults.standard.set(false, forKey: "nashaat_blocking_active")
        result(nil)
        #else
        result(nil)
        #endif
    }

    @available(iOS 16.0, *)
    private func isBlockingActive(result: @escaping FlutterResult) {
        result(UserDefaults.standard.bool(forKey: "nashaat_blocking_active"))
    }
}

// ── FamilyActivityPicker wrapper ──────────────────────────────────────────────

#if canImport(FamilyControls) && canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, *)
class FamilyActivityPickerViewController: UIViewController {
    private let onDone: (FamilyActivitySelection) -> Void
    private let onCancel: () -> Void

    init(
        onDone: @escaping (FamilyActivitySelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onDone = onDone
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pickerView = FamilyActivityPickerView(
            onDone: { [weak self] sel in
                self?.dismiss(animated: true) { self?.onDone(sel) }
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true) { self?.onCancel() }
            }
        )

        let host = UIHostingController(rootView: pickerView)
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
    }
}

@available(iOS 16.0, *)
private struct FamilyActivityPickerView: View {
    let onDone: (FamilyActivitySelection) -> Void
    let onCancel: () -> Void

    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Select Apps to Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone(selection) }
                    }
                }
        }
    }
}
#endif

// ── BlockingStore ─────────────────────────────────────────────────────────────

#if canImport(ManagedSettings) && canImport(FamilyControls)
@available(iOS 16.0, *)
class BlockingStore {
    static let shared = BlockingStore()
    private let store = ManagedSettingsStore()
    private let selectionKey = "nashaat_family_selection"

    func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
    }

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func applyBlocking() {
        guard let selection = loadSelection() else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    func removeBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
#endif
