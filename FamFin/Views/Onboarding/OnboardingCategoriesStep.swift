import SwiftUI

/// Fourth onboarding step: lets the user choose which default category groups to include.
struct OnboardingCategoriesStep: View {
    @Binding var enabledGroups: Set<String>
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCategoriesHeader()

            OnboardingCategoriesGroupList(enabledGroups: $enabledGroups)

            Spacer()

            OnboardingStepButtons(
                continueLabel: "Continue",
                continueDisabled: enabledGroups.isEmpty,
                onContinue: onContinue,
                onSkip: onSkip
            )
        }
        .padding()
    }
}

// MARK: - Header

struct OnboardingCategoriesHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Choose Categories")
                .font(.title2.bold())

            Text("These are your budget envelopes — you'll allocate money to each one. Deselect any groups you don't need.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Group List

struct OnboardingCategoriesGroupList: View {
    @Binding var enabledGroups: Set<String>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(DefaultCategories.all, id: \.name) { headerDef in
                    OnboardingCategoryGroupRow(
                        headerDef: headerDef,
                        isEnabled: enabledGroups.contains(headerDef.name),
                        onToggle: {
                            if enabledGroups.contains(headerDef.name) {
                                enabledGroups.remove(headerDef.name)
                            } else {
                                enabledGroups.insert(headerDef.name)
                            }
                        }
                    )

                    if headerDef.name != DefaultCategories.all.last?.name {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Group Row

struct OnboardingCategoryGroupRow: View {
    let headerDef: DefaultCategories.HeaderDef
    let isEnabled: Bool
    var onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Text(headerDef.emoji)
                    .font(.title2)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(headerDef.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(headerDef.subcategories.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headerDef.name): \(headerDef.subcategories.map(\.name).joined(separator: ", "))")
        .accessibilityAddTraits(isEnabled ? [.isSelected] : [])
        .accessibilityHint("Double tap to \(isEnabled ? "deselect" : "select") this category group")
    }
}

#Preview {
    OnboardingCategoriesStep(
        enabledGroups: .constant(Set(DefaultCategories.all.map(\.name))),
        onContinue: {},
        onSkip: {}
    )
}
