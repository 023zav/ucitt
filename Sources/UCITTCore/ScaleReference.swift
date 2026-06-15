import Foundation

/// How the app obtains real-world scale.
///
/// - `.arKit`: markerless 3D measurement using ARKit (LiDAR depth on Pro
///   devices). Gravity gives vertical; horizontal distances come from the
///   world-space points. No reference object at all. Primary method.
/// - `.wheel`: a single side-on photo scaled from the bike's own wheel (known
///   diameter). Markerless, works on any phone, nothing to attach. Fallback /
///   cross-check.
public enum MeasurementMode: String, CaseIterable, Identifiable, Codable {
    // Order here drives the picker order (LiDAR first).
    case arKit
    case wheel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wheel: return "Wheel photo"
        case .arKit: return "LiDAR scan"
        }
    }

    public var noun: String {
        switch self {
        case .wheel: return "photo"
        case .arKit: return "phone"
        }
    }
}
