import SwiftUI
import UCITTCore

/// Maps between a SwiftUI view's coordinate space and an aspect-fit image's
/// pixel coordinate space. All tap points live in image pixels so they feed the
/// homography unchanged regardless of how the image is displayed.
struct ImageFit {
    let imagePixelSize: CGSize   // full-resolution pixel dimensions
    let containerSize: CGSize    // the SwiftUI container

    /// The rect (in view space) the image actually occupies under .scaledToFit.
    var displayedRect: CGRect {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imagePixelSize.width,
                        containerSize.height / imagePixelSize.height)
        let w = imagePixelSize.width * scale
        let h = imagePixelSize.height * scale
        let x = (containerSize.width - w) / 2
        let y = (containerSize.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    var displayScale: CGFloat {
        guard imagePixelSize.width > 0 else { return 1 }
        return displayedRect.width / imagePixelSize.width
    }

    /// View point → image pixel.
    func toImage(_ viewPoint: CGPoint) -> Point2 {
        let r = displayedRect
        let s = displayScale
        return Point2(x: Double((viewPoint.x - r.minX) / s),
                      y: Double((viewPoint.y - r.minY) / s))
    }

    /// Image pixel → view point.
    func toView(_ imagePoint: Point2) -> CGPoint {
        let r = displayedRect
        let s = displayScale
        return CGPoint(x: r.minX + CGFloat(imagePoint.x) * s,
                       y: r.minY + CGFloat(imagePoint.y) * s)
    }

    /// Clamp a view point to the displayed image rect.
    func clampToImage(_ viewPoint: CGPoint) -> CGPoint {
        let r = displayedRect
        return CGPoint(x: min(max(viewPoint.x, r.minX), r.maxX),
                       y: min(max(viewPoint.y, r.minY), r.maxY))
    }
}
