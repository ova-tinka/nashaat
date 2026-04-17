import Flutter
import UIKit

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import SwiftUI
#endif

@objc class BlockingPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.nashaat/blocking",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(BlockingPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            switch call.method {
            case "checkPermissions": checkPermissions(result: result)
            case "requestPermission": requestPermission(result: result)
            case "presentAppPicker": presentAppPicker(result: result)
            case "startBlocking":   startBlocking(result: result)
            case "stopBlocking":    stopBlocking(result: result)
            case "isBlockingActive": isBlockingActive(result: result)
            default: result(FlutterMethodNotImplemented)
            }
        } else {
            switch call.method {
            case "checkPermissions": result(["familyControls": false])
            case "isBlockingActive": result(false)
            default: result(nil)
            }
        }
    }

    // ── Permissions ───────────────────────────────────────────────────────────

    @available(iOS 16.0, *)
    private func checkPermissions(result: @escaping FlutterResult) {
        #if canImport(FamilyControls)
        result(["familyControls": AuthorizationCenter.shared.authorizationStatus == .approved])
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

            // Restore previously saved selection so checked apps stay checked.
            var restored = FamilyActivitySelection()
            if let data = UserDefaults.standard.data(forKey: BlockingStore.selectionKey),
               let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                restored = saved
            }

            // Present a transparent host view whose only job is to open the
            // picker as a sheet. The picker supplies its own Done / Cancel —
            // we never wrap it in our own NavigationView.
            var hostVC: UIHostingController<PickerHost>?

            let host = PickerHost(initial: restored) { finalSelection in
                BlockingStore.shared.saveSelection(finalSelection)
                BlockingStore.shared.applyBlocking()
                let count = finalSelection.applicationTokens.count
                           + finalSelection.webDomainTokens.count
                           + finalSelection.categoryTokens.count
                result(["appCount": count])
                // Dismiss the transparent host after the picker sheet is gone.
                DispatchQueue.main.async { hostVC?.dismiss(animated: false) }
            }

            hostVC = UIHostingController(rootView: host)
            hostVC!.view.backgroundColor = .clear
            // Present without animation — the sheet inside will animate on its own.
            rootVC.present(hostVC!, animated: false)
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
        #endif
        result(nil)
    }

    @available(iOS 16.0, *)
    private func stopBlocking(result: @escaping FlutterResult) {
        #if canImport(ManagedSettings)
        BlockingStore.shared.removeBlocking()
        UserDefaults.standard.set(false, forKey: "nashaat_blocking_active")
        #endif
        result(nil)
    }

    @available(iOS 16.0, *)
    private func isBlockingActive(result: @escaping FlutterResult) {
        result(UserDefaults.standard.bool(forKey: "nashaat_blocking_active"))
    }
}

// ── PickerHost ────────────────────────────────────────────────────────────────
//
// Transparent SwiftUI view that presents FamilyActivityPicker as a sheet.
// The picker owns its Done/Cancel buttons and its own navigation stack —
// we don't interfere with either.
//
// PickerCoordinator is a class so the onDismiss closure captures a reference
// and always reads the current selection, not a value-type snapshot.

#if canImport(FamilyControls)

@available(iOS 16.0, *)
private final class PickerCoordinator: ObservableObject {
    @Published var selection: FamilyActivitySelection
    @Published var isPresented = true
    var confirmed = false   // set to true only on Done tap

    init(initial: FamilyActivitySelection) {
        selection = initial
    }
}

@available(iOS 16.0, *)
private struct PickerHost: View {
    @StateObject private var coordinator: PickerCoordinator
    private let onFinish: (FamilyActivitySelection) -> Void

    init(initial: FamilyActivitySelection, onFinish: @escaping (FamilyActivitySelection) -> Void) {
        _coordinator = StateObject(wrappedValue: PickerCoordinator(initial: initial))
        self.onFinish = onFinish
    }

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .sheet(isPresented: $coordinator.isPresented, onDismiss: {
                // Only forward the selection when the user explicitly tapped Done.
                onFinish(coordinator.confirmed ? coordinator.selection : FamilyActivitySelection())
            }) {
                // FamilyActivityPicker does NOT render its own Done/Cancel when
                // presented programmatically — we must supply them via toolbar.
                // NavigationStack (not the deprecated NavigationView) gives a
                // single-stack context that doesn't fight the picker's own navigation.
                NavigationStack {
                    FamilyActivityPicker(selection: $coordinator.selection)
                        .navigationTitle("Block Apps")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") {
                                    coordinator.confirmed = false
                                    coordinator.isPresented = false
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    coordinator.confirmed = true
                                    coordinator.isPresented = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
            }
    }
}

// ── BlockingStore ─────────────────────────────────────────────────────────────

@available(iOS 16.0, *)
class BlockingStore {
    static let shared = BlockingStore()
    static let selectionKey = "nashaat_family_selection"

    private let store = ManagedSettingsStore()

    func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: BlockingStore.selectionKey)
        }
    }

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: BlockingStore.selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func applyBlocking() {
        guard let sel = loadSelection() else { return }
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty
            ? nil : .specific(sel.categoryTokens)
    }

    func removeBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

#endif
