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
        let outWidth = Float(inSize.width)
        let outHeight = Float(inSize.height)
        let inWidth = Float(outSize.width)
        let inHeight = Float(outSize.height)
        guard outWidth > 0, outHeight > 0, inWidth > 0, inHeight > 0 else { return self }

        // aspect ratios
        let outAspect = outWidth / outHeight
        let inAaspect = inWidth / inHeight

        // touch in [0,1] of drawable
        let outX = point.x / outWidth
        let outY = point.y / outHeight

        // normalized crop rect inside the texture for aspect-fill
        var clipX: Float = 0,
            clipY: Float = 0,
            clipW: Float = 1,
            clipH: Float = 1

        if outAspect < inAaspect {
            clipW = outAspect / inAaspect
            clipX = (1 - clipW) * 0.5
        } else if outAspect > inAaspect {
            clipH = inAaspect / outAspect
            clipY = (1 - clipH) * 0.5
        }
        // map to texture pixel coordinates
        let normX = (outX * clipW + clipX) * inWidth
        let normY = (outY * clipH + clipY) * inHeight
        return DrawPoint(SIMD2<Float>(normX, normY), radius, color)
    }
}
