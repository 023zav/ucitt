import SwiftUI
import UIKit
import UCITTCore

/// Slipstream — the TT Fit Check design language.
///
/// A single source of truth for colour, type, spacing and radii. Everything is
/// system-adaptive (light + dark) via dynamic `UIColor` providers. The aesthetic
/// is aero-athletic: a fast, glanceable instrument built around one job —
/// showing how each cockpit measurement sits against its UCI limit.
enum Theme {

    // MARK: - Fonts
    //
    // Fonts are referenced by their exact PostScript names, which match the .ttf
    // files shipped in Resources/Fonts and declared in Info.plist › UIAppFonts.
    // Using PostScript names (rather than family + .weight) is the most reliable
    // way to pick a specific face — especially for the Expanded width, whose
    // family naming varies. If a face doesn't load, SwiftUI falls back to the
    // system font automatically; verify the name in Font Book and fix it here.
    private static func archivo(_ weight: Font.Weight) -> String {
        switch weight {
        case .black:    return "Archivo-Black"
        case .heavy:    return "Archivo-ExtraBold"
        case .bold:     return "Archivo-Bold"
        case .semibold: return "Archivo-SemiBold"
        case .medium:   return "Archivo-Medium"
        default:        return "Archivo-Regular"
        }
    }
    private static func jetbrains(_ weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy, .bold: return "JetBrainsMono-Bold"
        case .semibold:             return "JetBrainsMono-SemiBold"
        case .medium:               return "JetBrainsMono-Medium"
        default:                    return "JetBrainsMono-Regular"
        }
    }

    /// Display face — expanded + black. Verdicts, hero headings, the ≫ mark.
    static func display(_ size: CGFloat) -> Font {
        Font.custom("ArchivoExpanded-Black", size: size)
    }
    /// Body / UI face — Archivo at the requested weight.
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(archivo(weight), size: size)
    }
    /// Monospaced face — every number, unit, label and badge.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(jetbrains(weight), size: size)
    }

    // MARK: - Colour (light / dark adaptive)
    static let bg            = Color(light: 0xF2F3F0, dark: 0x080B11) // page
    static let surface       = Color(light: 0xFFFFFF, dark: 0x131922) // cards
    static let surfaceRaised = Color(light: 0xECEEEA, dark: 0x1A2230) // tracks, wells
    static let line          = Color(light: 0xE4E7E2, dark: 0x2A3442) // hairline borders

    static let textPrimary   = Color(light: 0x0D1016, dark: 0xEEF2F7)
    static let textSecondary = Color(light: 0x5C6675, dark: 0x94A2B6)
    static let textTertiary  = Color(light: 0x97A0AE, dark: 0x5A6678)

    static let accent   = Color(light: 0x00B89A, dark: 0x00E0B8) // brand / action
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x06231D) // text on accent

    // Sign-forward semantic states. Brand mint never doubles as a state colour.
    static let pass  = Color(light: 0x15A85C, dark: 0x2FD27E)
    static let check = Color(light: 0xC8820B, dark: 0xFFB020)
    static let fail  = Color(light: 0xE23A3F, dark: 0xFF6166)

    /// Map a measurement state to its colour.
    static func color(for state: MeasurementState) -> Color {
        switch state {
        case .pass:       return pass
        case .borderline: return check
        case .fail:       return fail
        }
    }

    // MARK: - Radii
    static let rPill: CGFloat = 22
    static let rCard: CGFloat = 14
    static let rChip: CGFloat = 6

    // MARK: - UIKit appearance (nav bar etc.)
    private static let uiBg = UIColor { tc in
        UIColor(hex: tc.userInterfaceStyle == .dark ? 0x080B11 : 0xF2F3F0)
    }
    private static let uiLine = UIColor { tc in
        UIColor(hex: tc.userInterfaceStyle == .dark ? 0x2A3442 : 0xE4E7E2)
    }
    private static let uiTextPrimary = UIColor { tc in
        UIColor(hex: tc.userInterfaceStyle == .dark ? 0xEEF2F7 : 0x0D1016)
    }

    /// Configure global navigation-bar chrome to match the language. Call once
    /// from the App initialiser.
    static func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = uiBg
        nav.shadowColor = uiLine

        let titleFont = UIFont(name: "JetBrainsMono-Bold", size: 15)
            ?? UIFont(name: "JetBrains Mono", size: 15)
            ?? .monospacedSystemFont(ofSize: 15, weight: .bold)
        nav.titleTextAttributes = [
            .foregroundColor: uiTextPrimary,
            .font: titleFont,
            .kern: 1.5
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

// MARK: - Colour helpers

extension Color {
    /// A colour that resolves differently in light vs dark, from 0xRRGGBB ints.
    init(light: UInt, dark: UInt) {
        self = Color(UIColor { tc in
            UIColor(hex: tc.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - Reusable card surface

extension View {
    /// The standard Slipstream card: surface fill, hairline border, card radius.
    func slipCard(padding: CGFloat = 16, radius: CGFloat = Theme.rCard) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
