import Foundation

/// End-to-end, device-independent pipeline tying detection geometry, the
/// homography, measurements and the rules engine into a single report. The app
/// layer supplies pixel coordinates (marker corners + tapped landmarks); this
/// produces the `ResultReport`. Pure and fully unit-testable.
public struct PositionChecker {

    public enum Failure: Error, Equatable {
        case capture(MarkerGeometry.Rejection)
        case degenerateMarker          // homography could not be solved
        case missingLandmarks
    }

    public let rules: UCIRules
    /// Physical marker size in mm (the config constant the user confirms, §6).
    public let markerWidthMM: Double
    public let markerHeightMM: Double

    public init(rules: UCIRules = .current,
                markerWidthMM: Double = 100,
                markerHeightMM: Double = 100) {
        self.rules = rules
        self.markerWidthMM = markerWidthMM
        self.markerHeightMM = markerHeightMM
    }

    /// Build the homography from detected marker corners, validating capture
    /// quality first. Corners are TL/TR/BR/BL pixels.
    public func homography(markerCornersPx: [Point2],
                           frameWidth: Double,
                           frameHeight: Double,
                           validateCapture: Bool = true) -> Result<Homography, Failure> {
        if validateCapture,
           let rejection = MarkerGeometry.validate(corners: markerCornersPx,
                                                   frameWidth: frameWidth,
                                                   frameHeight: frameHeight) {
            return .failure(.capture(rejection))
        }
        let dst = Homography.markerCornersMM(width: markerWidthMM, height: markerHeightMM)
        guard let h = Homography.estimate(src: markerCornersPx, dst: dst) else {
            return .failure(.degenerateMarker)
        }
        return .success(h)
    }

    /// Run the whole pipeline.
    /// - Parameters:
    ///   - markerCornersPx: detected marker corners (pixels), TL/TR/BR/BL.
    ///   - landmarksPx: tapped landmark pixels.
    ///   - heightCm: rider height.
    ///   - setbackOverrideMm: optional manual saddle setback (magnitude, mm) used
    ///     instead of the measured value when the saddle nose isn't cleanly
    ///     visible (§2 / §4 S2).
    ///   - frameWidth/Height: capture dimensions in pixels (for the quality gate).
    public func check(markerCornersPx: [Point2],
                      landmarksPx: [Landmark: Point2],
                      heightCm: Double,
                      setbackOverrideMm: Double? = nil,
                      frameWidth: Double,
                      frameHeight: Double,
                      validateCapture: Bool = true) -> Result<ResultReport, Failure> {

        let h: Homography
        switch homography(markerCornersPx: markerCornersPx,
                          frameWidth: frameWidth,
                          frameHeight: frameHeight,
                          validateCapture: validateCapture) {
        case .failure(let f): return .failure(f)
        case .success(let value): h = value
        }

        // Rectify every tapped landmark into mm.
        var mmPoints: [Landmark: Point2] = [:]
        for (landmark, px) in landmarksPx {
            mmPoints[landmark] = h.apply(px)
        }

        guard let rawMeasurements = Measurement.all(points: mmPoints) else {
            return .failure(.missingLandmarks)
        }

        let report = ReportBuilder.build(rawMeasurements: rawMeasurements,
                                         heightCm: heightCm,
                                         setbackOverrideMm: setbackOverrideMm,
                                         rules: rules)
        return .success(report)
    }

    /// ARKit path: build a report directly from six gravity-aligned 3D landmark
    /// points (mm). No homography or capture gate — the AR session provides
    /// metric scale and gravity.
    public func check(points3: [Landmark: Point3],
                      heightCm: Double,
                      setbackOverrideMm: Double? = nil) -> Result<ResultReport, Failure> {
        guard let rawMeasurements = Measurement.all(points3: points3) else {
            return .failure(.missingLandmarks)
        }
        let report = ReportBuilder.build(rawMeasurements: rawMeasurements,
                                         heightCm: heightCm,
                                         setbackOverrideMm: setbackOverrideMm,
                                         rules: rules)
        return .success(report)
    }

    /// Wheel path: scale a side-on photo from the bike's wheel instead of a
    /// placed marker. `rearHubPx`/`frontHubPx` define horizontal; the rear
    /// hub-to-ground distance is the wheel radius (metric scale).
    public func check(landmarksPx: [Landmark: Point2],
                      rearHubPx: Point2,
                      frontHubPx: Point2,
                      groundContactPx: Point2,
                      wheelDiameterMM: Double,
                      heightCm: Double,
                      setbackOverrideMm: Double? = nil) -> Result<ResultReport, Failure> {
        guard let rect = WheelRectifier(rearHub: rearHubPx, frontHub: frontHubPx,
                                        groundContact: groundContactPx,
                                        wheelDiameterMM: wheelDiameterMM) else {
            return .failure(.degenerateMarker)
        }
        var mmPoints: [Landmark: Point2] = [:]
        for (landmark, px) in landmarksPx {
            mmPoints[landmark] = rect.mm(px)
        }
        guard let rawMeasurements = Measurement.all(points: mmPoints) else {
            return .failure(.missingLandmarks)
        }
        let report = ReportBuilder.build(rawMeasurements: rawMeasurements,
                                         heightCm: heightCm,
                                         setbackOverrideMm: setbackOverrideMm,
                                         rules: rules)
        return .success(report)
    }
}
