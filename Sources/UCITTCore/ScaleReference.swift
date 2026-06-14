import Foundation

/// How the app obtains real-world scale (§3/§6).
///
/// - `.bankCardPhoto`: a single side-on photo with a standard ISO/IEC 7810
///   ID-1 card (every credit/debit/ID card is exactly 85.6 × 54 mm) in the
///   cockpit plane. A homography maps pixels → mm. No printing.
/// - `.arKit`: markerless 3D measurement using ARKit (LiDAR depth on Pro
///   devices). Gravity gives vertical; horizontal distances come from the
///   world-space points. No reference object at all.
public enum MeasurementMode: String, CaseIterable, Identifiable, Codable {
    case bankCardPhoto
    case arKit

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bankCardPhoto: return "Bank card"
        case .arKit:         return "ARKit (LiDAR)"
        }
    }

    public var noun: String {
        switch self {
        case .bankCardPhoto: return "card"
        case .arKit:         return "phone"
        }
    }
}

/// Physical size of the bank card used as the scale reference in
/// `.bankCardPhoto` mode (ISO/IEC 7810 ID-1).
public enum BankCard {
    public static let widthMM: Double = 85.60   // long edge, placed horizontal
    public static let heightMM: Double = 53.98  // short edge
    /// Aspect (shorter / longer), for tuning rectangle detection.
    public static let shortOverLongAspect: Double = heightMM / widthMM
}
