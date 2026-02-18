import SwiftUI
import StoreKit

/// Full-screen paywall presenting the Pro and Premium purchase options.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    PaywallHeaderView()

                    PaywallProCardView()

                    PaywallPremiumCardView()

                    PaywallFeatureComparisonView()

                    PaywallRestoreButton()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade FamFin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark.circle.fill") {
                        dismiss()
                    }
                    .symbolRenderingMode(.hierarchical)
                }
            }
            .task {
                await premiumManager.loadProducts()
            }
            .alert(
                "Something Went Wrong",
                isPresented: Binding(
                    get: { premiumManager.purchaseError != nil },
                    set: { if !$0 { premiumManager.purchaseError = nil } }
                )
            ) {
                Button("OK") { premiumManager.purchaseError = nil }
            } message: {
                Text(premiumManager.purchaseError ?? "")
            }
        }
    }
}

// MARK: - Header

/// The introductory headline area at the top of the paywall.
private struct PaywallHeaderView: View {
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        VStack {
            Image(systemName: "star.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("Get More from FamFin")
                .font(.title2)
                .bold()

            if premiumManager.isTrialActive {
                Text("You have \(premiumManager.trialDaysRemaining) days left in your free trial.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your free trial has ended. Upgrade to continue using FamFin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom)
    }
}

// MARK: - Pro Card

/// Purchase card for the one-time Pro unlock.
private struct PaywallProCardView: View {
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Label("FamFin Pro", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                Spacer()
                if premiumManager.hasProAccess {
                    ActiveBadge()
                }
            }

            Text("One-time purchase")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading) {
                FeatureRow(icon: "chart.pie.fill", text: "Envelope budgeting")
                FeatureRow(icon: "list.bullet.rectangle", text: "Unlimited accounts & transactions")
                FeatureRow(icon: "chart.bar.fill", text: "Reports & insights")
                FeatureRow(icon: "target", text: "Savings goals")
                FeatureRow(icon: "infinity", text: "Yours forever — no subscription")
            }

            Button {
                Task { await premiumManager.purchasePro() }
            } label: {
                Group {
                    if premiumManager.isPurchasing {
                        ProgressView()
                    } else if let product = premiumManager.proProduct {
                        Text("Unlock Pro for \(product.displayPrice)")
                    } else {
                        Text("Loading…")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(premiumManager.isPurchasing || premiumManager.proProduct == nil || premiumManager.hasProAccess)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Premium Card

/// Purchase card for the Premium monthly subscription.
private struct PaywallPremiumCardView: View {
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Label("FamFin Premium", systemImage: "crown.fill")
                    .font(.headline)
                Spacer()
                if premiumManager.hasPremiumAccess {
                    ActiveBadge()
                }
            }

            Text("Monthly subscription")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading) {
                FeatureRow(icon: "checkmark.seal.fill", text: "Everything in Pro")
                FeatureRow(icon: "doc.text.fill", text: "CSV & OFX file import")
                FeatureRow(icon: "building.columns.fill", text: "Open Banking connection")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic transaction sync")
            }

            Button {
                Task { await premiumManager.purchasePremium() }
            } label: {
                Group {
                    if premiumManager.isPurchasing {
                        ProgressView()
                    } else if let product = premiumManager.premiumProduct {
                        Text("Subscribe for \(product.displayPrice)/month")
                    } else {
                        Text("Loading…")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .disabled(premiumManager.isPurchasing || premiumManager.premiumProduct == nil || premiumManager.hasPremiumAccess)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Feature Comparison

/// A side-by-side comparison of what each tier includes.
private struct PaywallFeatureComparisonView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Compare Plans")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Feature")
                        .font(.subheadline)
                        .bold()
                    Text("Pro")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity)
                    Text("Premium")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity)
                }

                Divider()
                    .gridCellColumns(3)

                ComparisonRow(feature: "Envelope budgeting", pro: true, premium: true)
                ComparisonRow(feature: "Unlimited accounts", pro: true, premium: true)
                ComparisonRow(feature: "Reports & insights", pro: true, premium: true)
                ComparisonRow(feature: "Savings goals", pro: true, premium: true)
                ComparisonRow(feature: "Data backup & restore", pro: true, premium: true)
                ComparisonRow(feature: "CSV & OFX import", pro: false, premium: true)
                ComparisonRow(feature: "Open Banking sync", pro: false, premium: true)
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 12))
    }
}

/// A single row inside the feature comparison grid.
private struct ComparisonRow: View {
    let feature: String
    let pro: Bool
    let premium: Bool

    var body: some View {
        GridRow {
            Text(feature)
                .font(.subheadline)
            Image(systemName: pro ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(pro ? .green : .secondary)
                .frame(maxWidth: .infinity)
            Image(systemName: premium ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(premium ? .green : .secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Restore Button

/// A subtle button at the bottom for restoring previous purchases.
private struct PaywallRestoreButton: View {
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        Button("Restore Purchases") {
            Task { await premiumManager.restorePurchases() }
        }
        .font(.footnote)
        .padding(.top)
    }
}

// MARK: - Supporting views

/// A single feature bullet row with an SF Symbol and text.
private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
    }
}

/// A small capsule badge indicating an active entitlement.
private struct ActiveBadge: View {
    var body: some View {
        Text("Active")
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green.opacity(0.15), in: .capsule)
            .foregroundStyle(.green)
    }
}

#Preview {
    PaywallView()
        .environment(PremiumManager())
}
