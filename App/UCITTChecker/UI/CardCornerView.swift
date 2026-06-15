import SwiftUI
import UCITTCore

/// Card mode S3.5 — tap the bank card's four corners on the captured photo.
/// Supports pinch-to-zoom + pan of the whole photo (on top of the loupe) so the
/// small card corners are easy to hit. The four points feed the homography
/// (TL, TR, BR, BL → the card's known mm size).
struct CardCornerView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @State private var corners: [Point2?] = Array(repeating: nil, count: 4)
    @State private var activeCorner = 0

    // Placement drag
    @State private var dragLocation: CGPoint?
    @State private var draggingCorner: Int?
    @State private var dragMode: DragMode?

    // Canvas zoom / pan
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var isPinching = false

    private enum DragMode: Equatable { case move, place, pan, ignore }
    private let labels = ["top-left", "top-right", "bottom-right", "bottom-left"]

    var body: some View {
        GeometryReader { geo in
            let fit = imageFit(in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = flow.capturedImage {
                    // Zoom/pan-transformed canvas (image + overlays move together).
                    ZStack {
                        Image(uiImage: image).resizable().scaledToFit()
                        quadOverlay(fit: fit)
                        cornerDots(fit: fit)
                    }
                    .scaleEffect(zoom)
                    .offset(panOffset)

                    // Gesture surface (below the controls so buttons still work).
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(combinedGesture(fit: fit, container: geo.size))

                    if let loc = dragLocation,
                       dragMode == .move || dragMode == .place {
                        Loupe(image: image, fit: fit,
                              focusViewPoint: toCanvas(loc, geo.size))
                            .position(x: loc.x, y: max(loc.y - 110, 90))
                            .allowsHitTesting(false)
                    }
                }

                VStack {
                    promptBar
                    Spacer()
                    controls
                }

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
        .navigationTitle("Card corners")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Layout / transform

    private func imageFit(in container: CGSize) -> ImageFit {
        let px = flow.capturedImage.map {
            CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale)
        } ?? .zero
        return ImageFit(imagePixelSize: px, containerSize: container)
    }

    /// Screen point → un-zoomed canvas point (inverse of scaleEffect+offset).
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

    private var allPlaced: Bool { corners.allSatisfy { $0 != nil } }
    private var placedCount: Int { corners.compactMap { $0 }.count }

    // MARK: Subviews

    private var promptBar: some View {
        VStack(spacing: 4) {
            Text("Tap the \(labels[min(activeCorner, 3)]) corner of the card")
                .font(.headline)
            Text("\(placedCount)/4 placed · pinch to zoom · drag to pan / fine-tune")
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
            ForEach(0..<4, id: \.self) { i in
                Button { activeCorner = i } label: {
                    Text("\(i + 1)")
                        .font(.caption.bold())
                        .frame(width: 30, height: 30)
                        .background(chipColor(i), in: Circle())
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            if allPlaced {
                Button("Next") {
                    flow.markerCornersPx = corners.compactMap { $0 }
                    flow.advance(to: .tapping)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private func chipColor(_ i: Int) -> Color {
        if corners[i] != nil { return .green }
        return i == activeCorner ? .orange : .gray
    }

    private func cornerDots(fit: ImageFit) -> some View {
        ForEach(0..<4, id: \.self) { i in
            if let p = corners[i] {
                let v = fit.toView(p)
                ZStack {
                    Circle().fill(i == activeCorner ? Color.yellow : Color.cyan)
                        .frame(width: 14 / zoom, height: 14 / zoom)
                    Circle().stroke(.black, lineWidth: 1 / zoom)
                        .frame(width: 14 / zoom, height: 14 / zoom)
                }
                .position(v)
                .allowsHitTesting(false)
            }
        }
    }

    private func quadOverlay(fit: ImageFit) -> some View {
        Path { path in
            let pts = corners.compactMap { $0 }.map { fit.toView($0) }
            guard pts.count == 4 else { return }
            path.move(to: pts[0])
            for p in pts.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
        }
        .stroke(.green, lineWidth: 2 / zoom)
        .allowsHitTesting(false)
    }

    // MARK: Gestures

    private func combinedGesture(fit: ImageFit, container: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    isPinching = true
                    zoom = min(max(lastZoom * v.magnification, 1), 6)
                }
                .onEnded { _ in
                    isPinching = false
                    lastZoom = zoom
                    if zoom <= 1.01 { resetZoom() }
                },
            DragGesture(minimumDistance: 0)
                .onChanged { v in handleDragChanged(v, fit: fit, container: container) }
                .onEnded { _ in handleDragEnded() }
        )
    }

    private func handleDragChanged(_ v: DragGesture.Value, fit: ImageFit, container: CGSize) {
        if dragMode == nil {
            if isPinching { dragMode = .ignore; return }
            let startCanvas = toCanvas(v.startLocation, container)
            if let i = nearestCorner(to: startCanvas, fit: fit) {
                dragMode = .move; draggingCorner = i; activeCorner = i
            } else if corners[activeCorner] == nil {
                dragMode = .place; draggingCorner = activeCorner
            } else if zoom > 1.01 {
                dragMode = .pan
            } else {
                dragMode = .ignore
            }
        }
        switch dragMode {
        case .move?, .place?:
            dragLocation = v.location
            if let i = draggingCorner {
                corners[i] = fit.toImage(toCanvas(v.location, container))
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
            if let next = corners.firstIndex(where: { $0 == nil }) { activeCorner = next }
        }
        dragMode = nil
        draggingCorner = nil
        dragLocation = nil
    }

    private func nearestCorner(to canvasPoint: CGPoint, fit: ImageFit) -> Int? {
        let threshold: CGFloat = 28 / zoom
        var best: (Int, CGFloat)?
        for i in 0..<4 {
            guard let p = corners[i] else { continue }
            let v = fit.toView(p)
            let d = hypot(v.x - canvasPoint.x, v.y - canvasPoint.y)
            if d <= threshold, best == nil || d < best!.1 { best = (i, d) }
        }
        return best?.0
    }
}
