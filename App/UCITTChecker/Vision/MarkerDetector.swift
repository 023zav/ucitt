import Foundation
import Vision
import CoreImage
import UIKit
import UCITTCore

/// Abstraction over marker detection so the implementation can be swapped.
///
/// The MVP ships a `VisionMarkerDetector` (no third-party dependency). The spec
/// prefers OpenCV ArUco for a more robust pose from a known tag; an
/// `ArUcoMarkerDetector` can conform to this same protocol later without
/// touching the rest of the app — corners just need to come back in TL, TR, BR,
/// BL order in the image's pixel coordinate space (top-left origin).
protocol MarkerDetecting {
    /// Detect the marker in `image`. Returns its four corners in pixels
    /// (TL, TR, BR, BL), or `nil` if nothing suitable was found.
    func detect(in image: CGImage) -> [Point2]?
}

/// Vision-based rectangle detector. Finds the most prominent quadrilateral and
/// treats it as the marker board. For production accuracy, prefer ArUco — a
/// coded tag avoids picking up the wrong rectangle and gives a stabler pose.
struct VisionMarkerDetector: MarkerDetecting {

    /// Minimum aspect tolerance etc. tuned for a roughly square printed marker.
    var minimumConfidence: Float = 0.6

    func detect(in image: CGImage) -> [Point2]? {
        let width = Double(image.width)
        let height = Double(image.height)

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = minimumConfidence
        request.minimumAspectRatio = 0.6   // tolerate perspective on a square
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 20

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let obs = request.results?.first as? VNRectangleObservation else {
            return nil
        }

        // Vision normalized coords: origin bottom-left, y up. Convert to image
        // pixels with origin top-left, y down, and reorder to TL, TR, BR, BL.
        func px(_ p: CGPoint) -> Point2 {
            Point2(x: Double(p.x) * width, y: (1 - Double(p.y)) * height)
        }
        return [px(obs.topLeft), px(obs.topRight), px(obs.bottomRight), px(obs.bottomLeft)]
    }
}
