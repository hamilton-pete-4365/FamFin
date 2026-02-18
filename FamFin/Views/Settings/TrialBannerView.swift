import SwiftUI

/// A compact banner that displays the user's trial status and opens the
/// paywall when tapped. Designed to sit inside a `Form` / `List` section.
struct TrialBannerView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showingPaywall = false

    var body: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.title3)

                VStack(alignment: .leading) {
                    Text(headline)
                        .font(.subheadline)
                        .bold()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    private var iconName: String {
        if premiumManager.hasPremiumAccess {
            return "crown.fill"
        } else if premiumManager.hasProAccess {
            return "checkmark.seal.fill"
        } else if premiumManager.isTrialActive {
            return "clock.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        if premiumManager.hasPremiumAccess {
            return .orange
        } else if premiumManager.hasProAccess {
            return .green
        } else if premiumManager.isTrialActive {
            return .blue
        } else {
            return .red
        }
    }

    private var headline: String {
        if premiumManager.hasPremiumAccess {
            return "FamFin Premium"
        } else if premiumManager.hasProAccess {
            return "FamFin Pro"
        } else if premiumManager.isTrialActive {
            return "\(premiumManager.trialDaysRemaining) days remaining"
        } else {
            return "Trial expired"
        }
    }

    private var subtitle: String {
        if premiumManager.hasPremiumAccess {
            return "You have access to all features."
        } else if premiumManager.hasProAccess {
            return "Upgrade to Premium for bank import."
        } else if premiumManager.isTrialActive {
            return "Tap to upgrade to FamFin Pro."
        } else {
            return "Tap to unlock FamFin."
        }
    }
}

#Preview("Trial Active") {
    Form {
        Section {
            TrialBannerView()
        }
    }
    .environment(PremiumManager())
}
