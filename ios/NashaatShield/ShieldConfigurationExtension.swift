import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationDataSourceImpl: ShieldConfigurationDataSource {

    private let messages = [
        "Time to move — your workout is waiting! 💪",
        "You haven't hit your activity goal yet today.",
        "Earn your screen time by finishing your workout.",
        "Every rep brings you closer to your goal.",
        "Your health matters more than your feed.",
        "One workout away from unlocking this. 🏃",
    ]

    private var randomMessage: String {
        messages.randomElement() ?? messages[0]
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShield(name: application.localizedDisplayName ?? "This App")
    }

    override func configuration(
        shielding application: Application,
        in webDomain: WebDomain
    ) -> ShieldConfiguration {
        makeShield(name: application.localizedDisplayName ?? "This App")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShield(name: webDomain.domain ?? "This Site")
    }

    private func makeShield(name: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.11, green: 0.18, blue: 0.42, alpha: 1.0),
            icon: UIImage(systemName: "figure.run.circle.fill"),
            title: ShieldConfiguration.Label(
                text: "\(name) is locked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: randomMessage,
                color: UIColor.white.withAlphaComponent(0.80)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Let's Work Out 🏃",
                color: UIColor(red: 0.11, green: 0.18, blue: 0.42, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: UIColor.white.withAlphaComponent(0.70)
            )
        )
    }
}
