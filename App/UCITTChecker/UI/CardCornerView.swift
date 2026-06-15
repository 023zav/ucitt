import SwiftUI
import UCITTCore

/// Card mode S3.5 — tap the bank card's four corners on the captured photo.
/// A robust replacement for flaky auto rectangle detection: these four points
/// feed the homography directly (TL, TR, BR, BL → the card's known mm size).
struct CardCornerView: View {
    @EnvironmentObject private var flow: CheckFlowModel
    @State private var corners: [Point2?] = Array(repeating: nil, count: 4)
    @State private var activeCorner = 0
    @State private var dragLocation: CGPoint?
    @State private var draggingCorner: Int?

    private let labels = ["top-left", "top-right", "bottom-right", "bottom-left"]

    var body: some View {
        GeometryReader { geo in
            let fit = imageFit(in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = flow.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    quadOverlay(fit: fit)
                    cornerDots(fit: fit)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(dragGesture(fit: fit))

                    if let loc = dragLocation {
                        Loupe(image: image, fit: fit, focusViewPoint: loc)
                            .position(x: loc.x, y: max(loc.y - 110, 90))
                            .allowsHitTesting(false)
                    }
                }

                VStack {
                    promptBar
                    Spacer()
                    controls
                }
            }
        }
        .navigationTitle("Card corners")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Layout

    private func imageFit(in container: CGSize) -> ImageFit {
        let px = flow.capturedImage.map {
            CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale)
        } ?? .zero
        return ImageFit(imagePixelSize: px, containerSize: container)
    }

    private var allPlaced: Bool { corners.allSatisfy { $0 != nil } }
    private var placedCount: Int { corners.compactMap { $0 }.count }

    // MARK: Subviews

    private var promptBar: some View {
        VStack(spacing: 4) {
            Text("Tap the \(labels[min(activeCorner, 3)]) corner of the card")
                .font(.headline)
            Text("\(placedCount)/4 placed · keep the long edge horizontal · drag to fine-tune")
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
                        .frame(width: 14, height: 14)
                    Circle().stroke(.black, lineWidth: 1).frame(width: 14, height: 14)
                    Text("\(i + 1)").font(.caption2.bold())
                        .foregroundStyle(.white).offset(y: -16)
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
        .stroke(.green, lineWidth: 2)
        .allowsHitTesting(false)
    }

    // MARK: Gesture

    private func dragGesture(fit: ImageFit) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clamped = fit.clampToImage(value.location)
                dragLocation = clamped
                if draggingCorner == nil {
                    draggingCorner = nearestCorner(to: clamped, fit: fit) ?? activeCorner
                }
                if let i = draggingCorner {
                    corners[i] = fit.toImage(clamped)
                    activeCorner = i
                }
            }
            .onEnded { _ in
                dragLocation = nil
                draggingCorner = nil
                if let next = corners.firstIndex(where: { $0 == nil }) { activeCorner = next }
            }
    }

    private func nearestCorner(to viewPoint: CGPoint, fit: ImageFit, threshold: CGFloat = 28) -> Int? {
        var best: (Int, CGFloat)?
        for i in 0..<4 {
            guard let p = corners[i] else { continue }
            let v = fit.toView(p)
            let d = hypot(v.x - viewPoint.x, v.y - viewPoint.y)
            if d <= threshold, best == nil || d < best!.1 { best = (i, d) }
        }
        return best?.0
    }
}
