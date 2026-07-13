import AppKit
import SwiftUI

@MainActor
enum AppAccessibility {
    static func announce(_ message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}

private struct KeyboardFocusRingModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DashboardFocusColor.color, lineWidth: isFocused ? 3 : 0)
                    .padding(1)
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

private enum DashboardFocusColor {
    static let color = Color(nsColor: .keyboardFocusIndicatorColor)
}

extension View {
    func appKeyboardFocusRing(cornerRadius: CGFloat = 8) -> some View {
        modifier(KeyboardFocusRingModifier(cornerRadius: cornerRadius))
    }

    func appAccessibleControl(
        id: String,
        label: String? = nil,
        hint: String? = nil,
        cornerRadius: CGFloat = 8
    ) -> some View {
        appKeyboardFocusRing(cornerRadius: cornerRadius)
            .accessibilityIdentifier(id)
            .modifier(OptionalAccessibilityTextModifier(label: label, hint: hint))
    }

    func sidebarKeyboardFocus(
        id: String,
        focusedID: FocusState<String?>.Binding,
        cornerRadius: CGFloat = 8
    ) -> some View {
        focused(focusedID, equals: id)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DashboardFocusColor.color, lineWidth: focusedID.wrappedValue == id ? 3 : 0)
                    .padding(1)
                    .allowsHitTesting(false)
            }
    }
}

private struct OptionalAccessibilityTextModifier: ViewModifier {
    let label: String?
    let hint: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let label, let hint {
            content.accessibilityLabel(label).accessibilityHint(hint)
        } else if let label {
            content.accessibilityLabel(label)
        } else if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
