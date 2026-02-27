import SwiftUI

/// User preference for light, dark, or automatic appearance.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light Mode"
        case .dark: "Dark Mode"
        case .auto: "Auto"
        }
    }

    /// The corresponding `ColorScheme`, or `nil` for system automatic.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// The UIKit interface style for this mode.
    /// `.unspecified` tells UIKit to follow the system setting, which
    /// reliably clears any previous override — unlike SwiftUI's
    /// `.preferredColorScheme(nil)` which does not.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .auto: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applies this appearance mode to every window in the app.
    /// Call this whenever the mode changes to ensure all windows —
    /// including presented sheets — update immediately.
    func applyToAllWindows() {
        let style = interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
