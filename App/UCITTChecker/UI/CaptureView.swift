import SwiftUI
import UCITTCore

/// Wheel mode S3 — take one square-on side-on photo of the whole bike. Scale and
/// landmarks are tapped on the still afterwards.
struct CaptureView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var vm = CaptureViewModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isAuthorized {
                CameraPreview(session: vm.session)
                    .ignoresSafeArea()
                guideOverlay
            } else {
                ContentUnavailableView("Camera unavailable",
                                       systemImage: "camera.fill",
                                       description: Text(vm.lastError ?? "Grant camera access to continue."))
            }

            VStack {
                Spacer()
                captureButton
                    .padding(.bottom, 28)
            }
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.requestAccessAndConfigure() }
        .onDisappear { vm.stop() }
    }

    private var guideOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Framing field
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                    .padding(20)

                // HUD corner brackets
                VStack {
                    HStack { HUDCorner(corner: .tl); Spacer(); HUDCorner(corner: .tr) }
                    Spacer()
                    HStack { HUDCorner(corner: .bl); Spacer(); HUDCorner(corner: .br) }
                }
                .padding(28)

                // Guidance + status
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        StatusPill(text: "ALIGN BIKE — DEAD SIDE-ON", color: Theme.accent)
                    }
                    .padding(.top, 8)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().stroke(Theme.accent, lineWidth: 3).frame(width: 84, height: 84)
                Circle().fill(Theme.accent).frame(width: 68, height: 68)
                if isCapturing {
                    ProgressView().tint(Theme.onAccent)
                }
            }
        }
        .disabled(!vm.isAuthorized || isCapturing)
    }

    private func capture() async {
        isCapturing = true
        defer { isCapturing = false }
        guard let image = await vm.capturePhotoOnly() else { return }

        // Wheel reference points are tapped next (robust, markerless).
        flow.capturedImage = image
        flow.rearHubPx = nil
        flow.frontHubPx = nil
        flow.groundContactPx = nil
        vm.stop()
        flow.advance(to: .wheelReference)
    }
}
