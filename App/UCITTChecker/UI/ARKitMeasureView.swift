import SwiftUI
import ARKit
import UCITTCore

/// S3/S4 (ARKit mode) — aim the reticle at each landmark and tap to capture a
/// 3D point, then compute the report from the gravity-aligned points.
struct ARKitMeasureView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var controller = ARMeasureController()
    @State private var showHelp = false
    @State private var magnify = false

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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { magnify.toggle() } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .symbolVariant(magnify ? .circle.fill : .none)
                }
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
            // The reticle + loupe live in an overlay on the AR view, which
            // ignores the safe area. That makes the crosshair's center exactly
            // the full-screen center the raycast fires from — otherwise the
            // crosshair (laid out inside the safe area) sits below the true
            // aim point and the captured spot is off.
            ARContainer(controller: controller)
                .ignoresSafeArea()
                .overlay { reticleOverlay }

            VStack {
                promptBar
                Spacer()
                statusBanner
                controls
            }
        }
    }

    private var reticleOverlay: some View {
        ZStack {
            reticle
            if magnify {
                TimelineView(.periodic(from: .now, by: 0.08)) { _ in
                    ReticleLoupe(snapshot: controller.arView?.snapshot())
                }
                .offset(y: -160)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if controller.lastCaptureFailed {
            banner("Couldn't find a surface there — aim at the bike and try again.", .red)
        } else if let d = controller.lastCaptureDistanceM {
            if d > 2.5 {
                banner(String(format: "Last point is %.1f m away — that may be the wall/floor behind the bike. Re-capture if it's wrong.", d), .orange)
            } else {
                banner(String(format: "Placed at %.2f m. Check the orange dot sits on the bike.", d), .green)
            }
        }
    }

    private func banner(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.callout.bold())
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 6)
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

/// A magnifier showing a zoomed crop of the AR view's center for precise
/// reticle aiming. Fed throttled snapshots so it doesn't tax the renderer.
struct ReticleLoupe: View {
    let snapshot: UIImage?
    var diameter: CGFloat = 150
    var zoom: CGFloat = 1.8

    var body: some View {
        ZStack {
            if let img = cropped {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.black.opacity(0.35)
            }
            Rectangle().fill(.yellow).frame(width: 1, height: 16)
            Rectangle().fill(.yellow).frame(width: 16, height: 1)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 4)
    }

    /// Center crop of `diameter / zoom` points, later scaled up to `diameter`.
    private var cropped: UIImage? {
        guard let full = snapshot, let cg = full.cgImage else { return nil }
        let scale = full.scale
        let side = diameter / zoom
        let cx = full.size.width / 2
        let cy = full.size.height / 2
        let rect = CGRect(x: (cx - side / 2) * scale,
                          y: (cy - side / 2) * scale,
                          width: side * scale,
                          height: side * scale)
        guard let cropCG = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropCG, scale: scale, orientation: full.imageOrientation)
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
