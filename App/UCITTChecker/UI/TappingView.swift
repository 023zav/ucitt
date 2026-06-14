import SwiftUI
import UCITTCore

/// S4 — guided tapping with a zoom loupe and draggable points (§4).
struct TappingView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @StateObject private var session: TapSession
    @State private var dragLocation: CGPoint?
    @State private var draggingLandmark: Landmark?
    @State private var showHelp = false

    init() {
        // The model is reconstructed in onAppear from flow state; this default is
        // replaced immediately. (SwiftUI requires a StateObject initializer.)
        _session = StateObject(wrappedValue: TapSession())
    }

    var body: some View {
        GeometryReader { geo in
            let fit = imageFit(in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = flow.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    MarkerOutline(corners: flow.markerCornersPx, fit: fit)
                    placedPoints(fit: fit)

                    // Gesture surface.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(dragGesture(fit: fit))

                    if let loc = dragLocation {
                        loupeOverlay(image: image, fit: fit, at: loc)
                    }
                }

                VStack {
                    promptBar
                    Spacer()
                    controls
                }
            }
        }
        .navigationTitle("Place points")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $showHelp) { LandmarkHelpView() }
        .onAppear {
            session.points = flow.landmarkPx
            session.advance()
        }
    }

    // MARK: Layout helpers

    private func imageFit(in container: CGSize) -> ImageFit {
        let px = flow.capturedImage.map {
            CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale)
        } ?? .zero
        return ImageFit(imagePixelSize: px, containerSize: container)
    }

    // MARK: Subviews

    private var promptBar: some View {
        VStack(spacing: 4) {
            Text("\(session.placedCount)/\(session.order.count) · \(session.active.title)")
                .font(.headline)
            Text(session.active.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Tap to set · drag to fine-tune · ? for help")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        HStack {
            ForEach(session.order) { landmark in
                Button {
                    session.activeIndex = session.order.firstIndex(of: landmark) ?? 0
                } label: {
                    Text(landmark.shortLabel)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(chipColor(landmark), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .topTrailing) {
            if session.allPlaced {
                Button("Results") {
                    flow.landmarkPx = session.points
                    flow.computeResult()
                    flow.advance(to: .results)
                }
                .buttonStyle(.borderedProminent)
                .padding(8)
            }
        }
    }

    private func placedPoints(fit: ImageFit) -> some View {
        ForEach(session.order) { landmark in
            if let p = session.points[landmark] {
                let v = fit.toView(p)
                ZStack {
                    Circle()
                        .fill(landmark == session.active ? Color.yellow : Color.cyan)
                        .frame(width: 14, height: 14)
                    Circle().stroke(.black, lineWidth: 1).frame(width: 14, height: 14)
                    Text(landmark.shortLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .offset(y: -16)
                }
                .position(v)
                .allowsHitTesting(false)
            }
        }
    }

    private func loupeOverlay(image: UIImage, fit: ImageFit, at loc: CGPoint) -> some View {
        // Keep the loupe out from under the finger.
        let loupePos = CGPoint(x: loc.x, y: max(loc.y - 110, 90))
        return Loupe(image: image, fit: fit, focusViewPoint: loc)
            .position(loupePos)
            .allowsHitTesting(false)
    }

    // MARK: Gestures

    private func dragGesture(fit: ImageFit) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clamped = fit.clampToImage(value.location)
                dragLocation = clamped

                // If the user grabbed near an existing point, move that one;
                // otherwise place/refine the active landmark.
                if draggingLandmark == nil {
                    draggingLandmark = nearestPoint(to: clamped, fit: fit) ?? session.active
                }
                if let lm = draggingLandmark {
                    session.move(lm, to: fit.toImage(clamped))
                }
            }
            .onEnded { _ in
                dragLocation = nil
                draggingLandmark = nil
                session.advance()
            }
    }

    /// The placed landmark within grab distance of a view point, if any.
    private func nearestPoint(to viewPoint: CGPoint, fit: ImageFit, threshold: CGFloat = 28) -> Landmark? {
        var best: (Landmark, CGFloat)?
        for landmark in session.order {
            guard let p = session.points[landmark] else { continue }
            let v = fit.toView(p)
            let d = hypot(v.x - viewPoint.x, v.y - viewPoint.y)
            if d <= threshold, best == nil || d < best!.1 { best = (landmark, d) }
        }
        return best?.0
    }

    private func chipColor(_ landmark: Landmark) -> Color {
        if landmark == session.active { return .orange }
        return session.points[landmark] != nil ? .green : .gray
    }
}

/// Draws the detected marker quad over the image for confidence (§4 S3/S4).
struct MarkerOutline: View {
    let corners: [Point2]
    let fit: ImageFit

    var body: some View {
        if corners.count == 4 {
            Path { path in
                let pts = corners.map { fit.toView($0) }
                path.move(to: pts[0])
                for p in pts.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
            }
            .stroke(.green, lineWidth: 2)
            .allowsHitTesting(false)
        }
    }
}
