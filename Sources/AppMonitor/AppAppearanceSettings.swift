import AppKit
import SwiftUI

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .system: return "Use System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }

    var nsAppearance: NSAppearance? {
        nsAppearanceName.flatMap(NSAppearance.init(named:))
    }
}

@MainActor
enum AppAppearanceSettings {
    private static let preferenceKey = "AppMonitorAppearancePreference"

    static var preference: AppAppearancePreference {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferenceKey),
                  let preference = AppAppearancePreference(rawValue: rawValue)
            else {
                return .system
            }
            return preference
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
            apply(newValue)
        }
    }

    static func applyCurrentPreference() {
        apply(preference)
    }

    static func apply(_ preference: AppAppearancePreference) {
        NSApp.appearance = preference.nsAppearance
    }
}

struct AppMonitorRGBA {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

extension Color {
    static func appMonitor(light: AppMonitorRGBA, dark: AppMonitorRGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let color = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                calibratedRed: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: CGFloat(color.alpha)
            )
        })
    }
}
