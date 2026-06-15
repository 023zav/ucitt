import Foundation
import AVFoundation
import UIKit
import UCITTCore

/// Owns the AVFoundation still-capture session and runs marker detection on the
/// captured photo (§4 S3). Live AR isn't needed for the MVP — a sharp still with
/// the marker fully visible carries the scale.
@MainActor
final class CaptureViewModel: NSObject, ObservableObject {

    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var lastError: String?

    // AVCaptureSession/Output are configured on `sessionQueue` (Apple's
    // recommendation), so they must be reachable from that background, Sendable
    // closure. They are internally thread-safe, hence `nonisolated(unsafe)`:
    // we opt out of main-actor isolation for these two objects only.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "ucitt.capture.session")

    private let detector: MarkerDetecting = VisionMarkerDetector()

    /// Result of processing a captured still.
    struct CaptureResult {
        let image: UIImage
        let corners: [Point2]?
        let rejection: MarkerGeometry.Rejection?
    }

    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    // MARK: Permissions & lifecycle

    func requestAccessAndConfigure() {
        // Needed for UIDevice.current.orientation to report the physical
        // orientation even though the app UI is portrait-locked.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    if granted { self?.configure() }
                }
            }
        default:
            isAuthorized = false
            lastError = "Camera access is required. Enable it in Settings."
        }
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                     for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                Task { @MainActor in self.lastError = "No camera available." }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            Task { @MainActor in self.isSessionRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            Task { @MainActor in self?.isSessionRunning = false }
        }
    }

    // MARK: Capture

    /// Capture a still and run detection + the capture-quality gate.
    func capture() async -> CaptureResult? {
        do {
            let image = try await capturePhoto()
            guard let cg = image.cgImage else {
                return CaptureResult(image: image, corners: nil, rejection: nil)
            }
            let w = Double(cg.width), h = Double(cg.height)

            guard let corners = detector.detect(in: cg) else {
                return CaptureResult(image: image, corners: nil,
                                     rejection: .wrongCornerCount(0))
            }
            let rejection = MarkerGeometry.validate(corners: corners,
                                                    frameWidth: w, frameHeight: h)
            return CaptureResult(image: image, corners: corners, rejection: rejection)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Just take the still, no marker detection (card corners are tapped by hand).
    func capturePhotoOnly() async -> UIImage? {
        do {
            return try await capturePhoto()
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func capturePhoto() async throws -> UIImage {
        // Orient the capture to how the phone is physically held, so a landscape
        // shot of a wide bike isn't saved rotated to portrait.
        if let conn = photoOutput.connection(with: .video),
           conn.isVideoOrientationSupported {
            conn.videoOrientation = currentVideoOrientation()
        }
        return try await withCheckedThrowingContinuation { cont in
            self.captureContinuation = cont
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:      return .landscapeRight
        case .landscapeRight:     return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default:                  return .portrait
        }
    }
}

extension CaptureViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        Task { @MainActor in
            defer { self.captureContinuation = nil }
            if let error {
                self.captureContinuation?.resume(throwing: error)
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                self.captureContinuation?.resume(
                    throwing: NSError(domain: "ucitt", code: -1))
                return
            }
            self.captureContinuation?.resume(returning: image)
        }
    }
}
