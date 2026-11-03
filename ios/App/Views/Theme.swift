import SwiftUI
import UIKit

/// Wygląd „achromatic ledger”: tło #f8f8f8, białe płaskie karty z cienką ramką,
/// czarny przycisk główny, szary drugorzędny. Kolor tylko na danych.
enum Theme {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    static let ground = dyn(0xF8F8F8, 0x0A0A0A)
    static let surface = dyn(0xFFFFFF, 0x141414)
    static let raised = dyn(0xF3F3F3, 0x1C1C1C)
    static let border = dyn(0xE6E6E6, 0x262626)
    static let rule = dyn(0xF0F0F0, 0x1F1F1F)
    static let text = dyn(0x0A0A0A, 0xFAFAFA)
    static let muted = dyn(0x6B6B6B, 0xA3A3A3)
    static let primary = dyn(0x141414, 0xFAFAFA)
    static let primaryInk = dyn(0xFFFFFF, 0x0A0A0A)
    static let secondary = dyn(0xE5E5E5, 0x262626)
    static let negative = dyn(0xC4242A, 0xF06A6F)
    static let track = dyn(0xECECEC, 0x262626)

    static let radius: CGFloat = 10
    static let buttonHeight: CGFloat = 44
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Płaska karta: biała, cienka ramka, bez cienia.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
    }
}

struct CardTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 16, weight: .semibold)).lineLimit(1)
    }
}

/// Wszystkie przyciski tej samej wysokości, tekst w jednej linii.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .foregroundStyle(Theme.primaryInk)
            .background(Theme.primary, in: RoundedRectangle(cornerRadius: 8))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .foregroundStyle(destructive ? Theme.negative : Theme.text)
            .background(Theme.secondary, in: RoundedRectangle(cornerRadius: 8))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Wygląd przycisku drugorzędnego dla etykiet Menu (Menu nie używa ButtonStyle).
struct SecondaryLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .foregroundStyle(Theme.text)
            .background(Theme.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Przyciski szybkich kwot — własny styl, żeby w Form każdy działał osobno.
struct QuickAmountButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(Theme.text)
            .background(Theme.secondary, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Pasek postępu w kolorze danych.
struct ProgressBar: View {
    let ratio: Double
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if ratio > 0 {
                    Capsule().fill(Color.dataBlue).frame(width: max(height, geo.size.width * ratio))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((ratio * 100).rounded()))%")
    }
}

/// Liczba z etykietą (np. „Uzbierane 4 100 zł”).
struct Figure: View {
    let label: String
    let value: String
    var size: CGFloat = 20
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            Text(value).font(.system(size: size, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

extension View {
    func screenBackground() -> some View {
        background(Theme.ground.ignoresSafeArea())
    }
}
