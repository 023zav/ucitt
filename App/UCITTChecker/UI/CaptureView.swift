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
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(24)
            VStack {
                Text("Whole bike side-on · square-on · both wheels in frame")
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
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
