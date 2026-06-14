import SwiftUI

/// A magnifying loupe for precise landmark placement (§4 S4). Shows a zoomed,
/// crosshaired view of the image around `focusViewPoint`.
struct Loupe: View {
    let image: UIImage
    let fit: ImageFit
    /// The point of interest in *view* coordinates.
    let focusViewPoint: CGPoint
    var diameter: CGFloat = 140
    var magnification: CGFloat = 2.5

    var body: some View {
        let r = fit.displayedRect
        ZStack {
            // The image, scaled up around the focus point.
            Image(uiImage: image)
                .resizable()
                .frame(width: r.width * magnification, height: r.height * magnification)
                .offset(
                    x: -(focusViewPoint.x - r.minX) * magnification + diameter / 2,
                    y: -(focusViewPoint.y - r.minY) * magnification + diameter / 2
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
