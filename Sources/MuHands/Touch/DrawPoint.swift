// created by musesum on 8/17/25

import Foundation

public struct DrawPoint {

    public var point: SIMD2<Float>
    public var radius: Float
    public var color: Float

    init(_ point: CGPoint,
         _ radius: CGFloat,
         _ color: UInt32,
         _ scale: CGFloat) {
        self.point = SIMD2(Float(point.x * scale),Float(point.y * scale))
        self.radius = Float(radius)
        self.color = Float(color)
    }
    init(fill: Float) {
        self.point = .zero
        self.radius = -1
        self.color = fill
    }

    init(_ point: SIMD2<Float>, _ radius: Float, _ color: Float) {
        self.point = point
        self.radius = radius
        self.color = color
    }

    /// normalize DrawPoint mapping between input and output sizes
    public func normalize(_ inSize: CGSize, _ outSize: CGSize) -> DrawPoint {
        let iw = Float(inSize.width)
        let ih = Float(inSize.height)
        let ow = Float(outSize.width)
        let oh = Float(outSize.height)
        guard iw > 0, ih > 0, ow > 0, oh > 0 else { return self }

        // aspect ratios
        let ia = iw / ih
        let oa = ow / oh

        // touch in [0,1] of drawable
        let ix = point.x / iw
        let iy = point.y / ih

        // normalized crop rect inside the texture for aspect-fill
        var clipX: Float = 0,
            clipY: Float = 0,
            clipW: Float = 1,
            clipH: Float = 1

        if ia < oa {
            clipW = ia / oa
            clipX = (1 - clipW) * 0.5
        } else if ia > oa {
            clipH = oa / ia
            clipY = (1 - clipH) * 0.5
        }
        // map to texture pixel coordinates
        let normX = (ix * clipW + clipX) * ow
        let normY = (iy * clipH + clipY) * oh
        return DrawPoint(SIMD2<Float>(normX, normY), radius, color)
    }
}
