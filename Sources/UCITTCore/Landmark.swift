import Foundation

/// The six landmarks the user taps, in the guided order of §4 / §5.
/// Definitions are deliberately precise so the geometry is unambiguous.
public enum Landmark: String, CaseIterable, Codable, Identifiable {
    /// Chainring concentric center == bottom-bracket axle center.
    case bb
    /// Forward-most end of the extensions (including any bar-end accessory).
    case tip
    /// Mid-point of the armrest top surface.
    case armMid
    /// Leading (forward) edge of the armrest.
    case armLead
    /// Rear edge of the armrest top surface (defines the surface line for angle).
    case armRear
    /// Forward-most point of the saddle nose.
    case saddleNose

    public var id: String { rawValue }

    /// Human-readable prompt shown during guided tapping.
    public var prompt: String {
        switch self {
        case .bb:         return "Tap the chainring center (bottom bracket)"
        case .tip:        return "Tap the forward-most extension tip"
        case .armMid:     return "Tap the mid-point of the armrest"
        case .armLead:    return "Tap the armrest leading (front) edge"
        case .armRear:    return "Tap the armrest rear edge"
        case .saddleNose: return "Tap the forward-most point of the saddle nose"
        }
    }

    /// Short label for overlays.
    public var shortLabel: String {
        switch self {
        case .bb:         return "BB"
        case .tip:        return "Tip"
        case .armMid:     return "Arm mid"
        case .armLead:    return "Arm lead"
        case .armRear:    return "Arm rear"
        case .saddleNose: return "Saddle"
        }
    }

    /// Plain-language title for the point.
    public var title: String {
        switch self {
        case .bb:         return "Bottom bracket"
        case .tip:        return "Extension tip"
        case .armMid:     return "Armrest middle"
        case .armLead:    return "Armrest front edge"
        case .armRear:    return "Armrest rear edge"
        case .saddleNose: return "Saddle nose"
        }
    }

    /// A precise, where-to-find-it description used in guidance and the help
    /// panel. Plain language so a non-engineer can place each point confidently.
    public var detail: String {
        switch self {
        case .bb:
            return "The center of the front chainrings — the point the cranks rotate around. Aim at the chainring bolt-circle center, not the pedal."
        case .tip:
            return "The forward-most end of the aero extensions (include any bar-end shifter or extension cap). The very front tip pointing ahead of the bike."
        case .armMid:
            return "The middle of the armrest / elbow pad's top surface — where your forearm sits."
        case .armLead:
            return "The front edge of the armrest pad — the side closest to the front wheel."
        case .armRear:
            return "The back edge of the same armrest pad — the side closest to you. Front + rear edge together set the pad's tilt."
        case .saddleNose:
            return "The forward-most tip of the saddle nose."
        }
    }

    /// The guided tapping sequence.
    public static let captureOrder: [Landmark] = [
        .bb, .tip, .armMid, .armLead, .armRear, .saddleNose
    ]
}
