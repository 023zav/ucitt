import SwiftUI

/// A magnifying loupe for precise landmark placement (§4 S4). Shows a zoomed,
/// crosshaired view of the image around `focusViewPoint`.
struct Loupe: View {
    let image: UIImage
    let fit: ImageFit
    /// The point of interest in *view* coordinates.
    let focusViewPoint: CGPoint
    var diameter: CGFloat = 150
    var magnification: CGFloat = 2.2

    var body: some View {
        let r = fit.displayedRect
        let w = r.width * magnification
        let h = r.height * magnification
        ZStack {
            // The zoomed image is centered in the loupe, then shifted so the
            // focus point lands at the loupe's center. Because SwiftUI centers
            // the image, the shift is measured from the image's HALF-SIZE
            // (w/2, h/2) — not the loupe radius — to the focus point.
            Image(uiImage: image)
                .resizable()
                .frame(width: w, height: h)
                .offset(
                    x: w / 2 - (focusViewPoint.x - r.minX) * magnification,
                    y: h / 2 - (focusViewPoint.y - r.minY) * magnification
                )
            crosshair
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 4)
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().fill(.yellow).frame(width: 1, height: diameter)
            Rectangle().fill(.yellow).frame(width: diameter, height: 1)
            Circle().stroke(.yellow, lineWidth: 1).frame(width: 12, height: 12)
        }
    }
}
