import SwiftUI
import ARKit
import UCITTCore

/// S3/S4 (ARKit mode) — aim the reticle at each landmark and tap to capture a
/// 3D point, then compute the report from the gravity-aligned points.
struct ARKitMeasureView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var controller = ARMeasureController()

    var body: some View {
        Group {
            if ARMeasureController.isSupported {
                measuring
            } else {
                ContentUnavailableView("ARKit not available",
                                       systemImage: "arkit",
                                       description: Text("This device doesn't support world tracking. Use Bank card mode instead."))
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onDisappear { controller.pause() }
    }

    private var measuring: some View {
        ZStack {
            ARContainer(controller: controller)
                .ignoresSafeArea()

            reticle

            VStack {
                promptBar
                Spacer()
                if controller.lastCaptureFailed {
                    Text("Couldn't find a surface there — aim at the bike and try again.")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }
                controls
            }
        }
    }

    private var reticle: some View {
        ZStack {
            Circle().stroke(.yellow, lineWidth: 2).frame(width: 26, height: 26)
            Rectangle().fill(.yellow).frame(width: 1, height: 14)
            Rectangle().fill(.yellow).frame(width: 14, height: 1)
        }
    }

    private var promptBar: some View {
        VStack(spacing: 4) {
            Text(controller.active.prompt)
                .font(.headline)
            HStack(spacing: 8) {
                Text("\(controller.placedCount)/\(controller.order.count) placed")
                if !controller.trackingNormal {
                    Label("Move the phone to map the bike", systemImage: "move.3d")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(controller.order) { landmark in
                    Button {
                        controller.select(landmark)
                    } label: {
                        Text(landmark.shortLabel)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(chipColor(landmark), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    controller.undoActive()
                } label: {
                    Label("Clear", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)

                Button {
                    controller.captureCurrent()
                } label: {
                    Label("Capture \(controller.active.shortLabel)", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if controller.allPlaced {
                    Button("Results") {
                        flow.landmark3D = controller.points
                        flow.computeResultFromARKit()
                        flow.advance(to: .results)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func chipColor(_ landmark: Landmark) -> Color {
        if landmark == controller.active { return .orange }
        return controller.points[landmark] != nil ? .green : .gray
    }
}

/// Hosts an `ARSCNView` and wires it to the controller.
struct ARContainer: UIViewRepresentable {
    let controller: ARMeasureController

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        controller.arView = view
        controller.start()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}
