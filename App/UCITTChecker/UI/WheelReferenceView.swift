import SwiftUI
import UCITTCore

/// Wheel mode S3.5 — tap the scale reference on the photo: the two wheel hub
/// centers (their line is horizontal) and the rear tyre's ground contact (hub →
/// ground = wheel radius). Supports pinch-to-zoom + pan + loupe for precision.
struct WheelReferenceView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @State private var points: [Point2?] = Array(repeating: nil, count: 3)
    @State private var active = 0

    @State private var dragLocation: CGPoint?
    @State private var draggingPoint: Int?
    @State private var dragMode: DragMode?

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var isPinching = false

    private enum DragMode: Equatable { case move, place, pan, ignore }

    private let labels = ["rear wheel hub (center)",
                          "front wheel hub (center)",
                          "rear tyre's ground contact"]
    private let colors: [Color] = [.orange, .cyan, .yellow]

    var body: some View {
        GeometryReader { geo in
            let fit = imageFit(in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = flow.capturedImage {
                    ZStack {
                        Image(uiImage: image).resizable().scaledToFit()
                        guideOverlay(fit: fit)
                        pointDots(fit: fit)
                    }
                    .scaleEffect(zoom)
                    .offset(panOffset)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(combinedGesture(fit: fit, container: geo.size))

                    if let loc = dragLocation, dragMode == .move || dragMode == .place {
                        Loupe(image: image, fit: fit, focusViewPoint: toCanvas(loc, geo.size))
                            .position(x: loc.x, y: max(loc.y - 110, 90))
                            .allowsHitTesting(false)
                    }
                }

                VStack { promptBar; Spacer(); controls }

                if zoom > 1.01 {
                    VStack {
                        HStack {
                            Spacer()
                            Button { resetZoom() } label: {
                                Image(systemName: "1.magnifyingglass")
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Wheel scale")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Layout / transform

    private func imageFit(in container: CGSize) -> ImageFit {
        let px = flow.capturedImage.map {
            CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale)
        } ?? .zero
        return ImageFit(imagePixelSize: px, containerSize: container)
    }

    private func toCanvas(_ screen: CGPoint, _ container: CGSize) -> CGPoint {
        let cx = container.width / 2, cy = container.height / 2
        return CGPoint(x: cx + (screen.x - cx - panOffset.width) / zoom,
                       y: cy + (screen.y - cy - panOffset.height) / zoom)
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = 1; lastZoom = 1; panOffset = .zero; lastPan = .zero
        }
    }

    private var allPlaced: Bool { points.allSatisfy { $0 != nil } }
    private var placedCount: Int { points.compactMap { $0 }.count }

    // MARK: Subviews

    private var promptBar: some View {
        VStack(spacing: 4) {
            Text("Tap the \(labels[min(active, 2)])")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(placedCount)/3 placed · pinch to zoom · drag to pan / fine-tune")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Button { active = i } label: {
                    Text(shortLabel(i))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(chipColor(i), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            if allPlaced {
                Button("Next") {
                    flow.rearHubPx = points[0]
                    flow.frontHubPx = points[1]
                    flow.groundContactPx = points[2]
                    flow.advance(to: .tapping)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private func shortLabel(_ i: Int) -> String {
        ["Rear hub", "Front hub", "Ground"][i]
    }

    private func chipColor(_ i: Int) -> Color {
        if points[i] != nil { return .green }
        return i == active ? .orange : .gray
    }

    private func pointDots(fit: ImageFit) -> some View {
        ForEach(0..<3, id: \.self) { i in
            if let p = points[i] {
                let v = fit.toView(p)
                Circle().fill(colors[i])
                    .frame(width: 14 / zoom, height: 14 / zoom)
                    .overlay(Circle().stroke(.black, lineWidth: 1 / zoom))
                    .position(v)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A faint line between the two hubs once both are placed (sanity check).
    private func guideOverlay(fit: ImageFit) -> some View {
        Path { path in
            guard let r = points[0], let f = points[1] else { return }
            path.move(to: fit.toView(r))
            path.addLine(to: fit.toView(f))
        }
        .stroke(.green.opacity(0.7), style: StrokeStyle(lineWidth: 1.5 / zoom, dash: [6 / zoom]))
        .allowsHitTesting(false)
    }

    // MARK: Gestures

    private func combinedGesture(fit: ImageFit, container: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { v in isPinching = true; zoom = min(max(lastZoom * v.magnification, 1), 6) }
                .onEnded { _ in isPinching = false; lastZoom = zoom; if zoom <= 1.01 { resetZoom() } },
            DragGesture(minimumDistance: 0)
                .onChanged { v in handleDragChanged(v, fit: fit, container: container) }
                .onEnded { _ in handleDragEnded() }
        )
    }

    private func handleDragChanged(_ v: DragGesture.Value, fit: ImageFit, container: CGSize) {
        if dragMode == nil {
            if isPinching { dragMode = .ignore; return }
            let startCanvas = toCanvas(v.startLocation, container)
            if let i = nearestPoint(to: startCanvas, fit: fit) {
                dragMode = .move; draggingPoint = i; active = i
            } else if points[active] == nil {
                dragMode = .place; draggingPoint = active
            } else if zoom > 1.01 {
                dragMode = .pan
            } else {
                dragMode = .ignore
            }
        }
        switch dragMode {
        case .move?, .place?:
            dragLocation = v.location
            if let i = draggingPoint {
                points[i] = fit.toImage(toCanvas(v.location, container))
            }
        case .pan?:
            panOffset = CGSize(width: lastPan.width + v.translation.width,
                               height: lastPan.height + v.translation.height)
        default:
            break
        }
    }

    private func handleDragEnded() {
        if dragMode == .pan { lastPan = panOffset }
        if dragMode == .move || dragMode == .place {
            if let next = points.firstIndex(where: { $0 == nil }) { active = next }
        }
        dragMode = nil
        draggingPoint = nil
        dragLocation = nil
    }

    private func nearestPoint(to canvasPoint: CGPoint, fit: ImageFit) -> Int? {
        let threshold: CGFloat = 28 / zoom
        var best: (Int, CGFloat)?
        for i in 0..<3 {
            guard let p = points[i] else { continue }
            let v = fit.toView(p)
            let d = hypot(v.x - canvasPoint.x, v.y - canvasPoint.y)
            if d <= threshold, best == nil || d < best!.1 { best = (i, d) }
        }
        return best?.0
    }
}
