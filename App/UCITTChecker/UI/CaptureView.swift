import SwiftUI
import UCITTCore

/// S3 — capture with a side-on guide, then detect + validate the marker (§4).
struct CaptureView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var vm = CaptureViewModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
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
                if let rejection = flow.captureRejection {
                    rejectionBanner(rejection)
                }
                captureButton
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.requestAccessAndConfigure() }
        .onDisappear { vm.stop() }
    }

    private var guideOverlay: some View {
        GeometryReader { geo in
            // A simple level/side-on hint frame.
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(24)
            VStack {
                Text("Bike fully side-on · marker level & sharp")
                    .font(.caption.bold())
                    .padding(8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                Spacer()
            }
            .frame(width: geo.size.width)
        }
    }

    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 72, height: 72)
                Circle().stroke(.white, lineWidth: 4).frame(width: 84, height: 84)
                if isCapturing { ProgressView() }
            }
        }
        .disabled(!vm.isAuthorized || isCapturing)
    }

    private func capture() async {
        isCapturing = true
        defer { isCapturing = false }
        guard let result = await vm.capture() else { return }

        flow.capturedImage = result.image
        flow.markerCornersPx = result.corners ?? []
        flow.captureRejection = result.rejection

        // Good capture with corners → proceed to tapping.
        if result.rejection == nil, let corners = result.corners, corners.count == 4 {
            vm.stop()
            flow.advance(to: .tapping)
        }
    }

    @ViewBuilder
    private func rejectionBanner(_ rejection: MarkerGeometry.Rejection) -> some View {
        Text(reason(for: rejection))
            .font(.callout.bold())
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    private func reason(for rejection: MarkerGeometry.Rejection) -> String {
        switch rejection {
        case .notLevel(let t):
            return "Marker not level (tilted \(String(format: "%.1f", t))°). Re-level and retry."
        case .tooSmall(let c):
            return "Marker too small in frame (\(String(format: "%.0f", c))%). Move closer."
        case .tooMuchPerspective:
            return "Too much perspective. Get square-on to the marker."
        case .wrongCornerCount(let n):
            return n == 0 ? "No marker found. Frame it fully and keep it sharp."
                          : "Marker detection unclear. Retry."
        }
    }
}
