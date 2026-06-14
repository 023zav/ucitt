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

    /// The guided tapping sequence.
    public static let captureOrder: [Landmark] = [
        .bb, .tip, .armMid, .armLead, .armRear, .saddleNose
    ]
}
