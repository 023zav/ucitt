import SwiftUI
import ARKit
import UCITTCore

/// S3/S4 (ARKit mode) — aim the reticle at each landmark and tap to capture a
/// 3D point, then compute the report from the gravity-aligned points.
struct ARKitMeasureView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var controller = ARMeasureController()
    @State private var showHelp = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $showHelp) { LandmarkHelpView() }
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
            if controller.allPlaced {
                Label("All 6 points placed", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Tap a point below to re-do it, or see your results.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(controller.activeIndex + 1)/\(controller.order.count) · \(controller.active.title)")
                    .font(.headline)
                Text(controller.active.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !controller.trackingNormal {
                    Label("Move the phone slowly to map the bike", systemImage: "move.3d")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            // Status chips: green = placed, ringed = currently selected.
            HStack(spacing: 6) {
                ForEach(controller.order) { landmark in
                    Button {
                        controller.select(landmark)
                    } label: {
                        HStack(spacing: 3) {
                            if controller.points[landmark] != nil {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                            }
                            Text(landmark.shortLabel).font(.caption2.bold())
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(chipColor(landmark), in: Capsule())
                        .overlay(
                            Capsule().stroke(.white, lineWidth: landmark == controller.active ? 2 : 0)
                        )
                        .foregroundStyle(.white)
                    }
                }
            }

            // Primary action.
            Button {
                controller.captureCurrent()
            } label: {
                Label(controller.points[controller.active] == nil
                      ? "Capture \(controller.active.title)"
                      : "Re-capture \(controller.active.title)",
                      systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Once everything is placed, an unmissable full-width CTA.
            if controller.allPlaced {
                Button {
                    flow.landmark3D = controller.points
                    flow.computeResultFromARKit()
                    flow.advance(to: .results)
                } label: {
                    Label("See results", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func chipColor(_ landmark: Landmark) -> Color {
        // Placed wins over active, so completed points read as green (done)
        // even while selected; the selection is shown by the white ring.
        if controller.points[landmark] != nil { return .green }
        return landmark == controller.active ? .orange : .gray
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
