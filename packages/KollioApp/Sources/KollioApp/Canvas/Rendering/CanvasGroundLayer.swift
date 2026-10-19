import Foundation
import KollioCore
import SwiftUI

/// The ground, drawn: a dot grid that scales with the world.
///
/// This layer exists for one reason — so a person can feel where they are while
/// panning and zooming. Everything analytical lives in `CanvasGround.scale`
/// and is tested; what remains here is placing dots and nothing else. It sits
/// behind the relationships and the nodes, first in the stack, and it never
/// takes a hit: the pointer belongs to the document, never to the paper.
struct CanvasGroundLayer: View {
    let camera: Camera
    let visibleWorld: CGRect
    let dotColor: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            EmptyView()
        } else {
            Canvas { context, size in
                let scale = CanvasGround.scale(zoom: camera.zoom)
                guard scale.draws else { return }

                // The step was chosen for the screen, so the loop walks the world
                // at the world stride and places each dot through the camera.
                // The dot itself keeps one diameter at every zoom: one that grew
                // with zoom would be a texture, and the ground is not a texture.
                let stride = scale.worldStep
                let radius = 0.8
                let opacity: Double = scale.isMajor ? 0.55 : 0.4

                var x = (visibleWorld.minX / stride).rounded(.down) * stride
                while x <= visibleWorld.maxX {
                    var y = (visibleWorld.minY / stride).rounded(.down) * stride
                    while y <= visibleWorld.maxY {
                        let screen = camera.toScreen(Position(x: x, y: y))
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: screen.x - radius,
                                y: screen.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )),
                            with: .color(dotColor.opacity(opacity))
                        )
                        y += stride
                    }
                    x += stride
                }
            }
            .allowsHitTesting(false)
        }
    }
}
