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
        VStack(spacing: 10) {
            HStack {
                Text("POINT \(min(session.placedCount + 1, session.order.count)) / \(session.order.count)")
                    .font(Theme.mono(11, .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(session.active.title.uppercased())
                    .font(Theme.mono(11, .bold))
                    .foregroundStyle(Theme.accent)
            }
            // Segmented progress
            HStack(spacing: 5) {
                ForEach(session.order) { landmark in
                    Capsule()
                        .fill(segmentColor(landmark))
                        .frame(height: 4)
                }
            }
            Text(session.active.detail)
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func segmentColor(_ landmark: Landmark) -> Color {
        if session.points[landmark] != nil { return Theme.pass }
        return landmark == session.active ? Theme.accent : Theme.surfaceRaised
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                ForEach(session.order) { landmark in
                    Button {
                        session.activeIndex = session.order.firstIndex(of: landmark) ?? 0
                    } label: {
                        Text(landmark.shortLabel)
                            .font(Theme.mono(10, .bold))
                            .foregroundStyle(chipText(landmark))
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(chipFill(landmark))
                            .overlay(Capsule().stroke(landmark == session.active ? Theme.accent : Color.clear, lineWidth: 1.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if session.allPlaced {
                Button {
                    flow.landmarkPx = session.points
                    flow.computeResultFromWheel()
                    flow.advance(to: .results)
                } label: {
                    HStack(spacing: 8) {
                        Text("SEE RESULTS").font(Theme.body(14, .heavy))
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .heavy))
                    }
                }
                .buttonStyle(SlipPrimary())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func chipFill(_ landmark: Landmark) -> Color {
        if session.points[landmark] != nil { return Theme.pass.opacity(0.18) }
        return Theme.surfaceRaised
    }
    private func chipText(_ landmark: Landmark) -> Color {
        if session.points[landmark] != nil { return Theme.pass }
        return landmark == session.active ? Theme.accent : Theme.textSecondary
    }

    private func placedPoints(fit: ImageFit) -> some View {
        ForEach(session.order) { landmark in
            if let p = session.points[landmark] {
                let v = fit.toView(p)
                let isActive = landmark == session.active
                let color = isActive ? Theme.accent : Theme.pass
                ZStack {
                    if isActive {
                        Circle().fill(color.opacity(0.20)).frame(width: 28, height: 28)
                    }
                    Circle().fill(color).frame(width: 14, height: 14)
                    Circle().stroke(.black.opacity(0.6), lineWidth: 1).frame(width: 14, height: 14)
                    Text(landmark.shortLabel)
                        .font(Theme.mono(9, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: Capsule())
                        .offset(y: -18)
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
}
