import QuartzCore
import MuFlo
import Dispatch

public class TouchDraw: @unchecked Sendable {

    var root     : Flo?
    var tilt˚    : Flo?
    var tiltReal˚ : Flo? // the real layer's own tilt switch
    var press˚   : Flo?
    /// the real layer's own press and size: each layer's brush is set apart,
    /// the way each layer's tilt and screen shift already are
    var pressReal˚ : Flo?
    var size˚    : Flo?
    var sizeReal˚ : Flo?
    var index˚   : Flo?
    var prev˚    : Flo?
    var next˚    : Flo?
    var force˚   : Flo?
    var radius˚  : Flo?
    var azimuth˚ : Flo?
    var azimuthReal˚ : Flo? // the same tilt, pushed into the real layer's shift
    var paint˚   : Flo?     // canvas.brush.paint: w 1 while the brush is on the real layer
    var fill˚    : Flo?
    var clear˚   : Flo?
    var pencilTilt˚ : Flo?  // sky.input.pencil.tilt: xy azimuth unit vector, z altitude 0…1
    var dropper˚ : Flo?     // canvas.dropper: the real leaf's eyedropper

    public private(set) var tilt    = false
    public private(set) var tiltReal = false
    public private(set) var press   = true
    public private(set) var pressReal = true
    public private(set) var size    = CGFloat(1)
    public private(set) var sizeReal = CGFloat(1)
    public private(set) var brush   = UInt32(255)
    public private(set) var prev    = CGPoint.zero
    public private(set) var next    = CGPoint.zero
    public private(set) var force   = CGFloat(0)
    public private(set) var radius  = CGFloat(0)
    public private(set) var azimuth = CGPoint.zero
    /// the eyedropper is armed: the next canvas touch takes a colour and
    /// leaves no stroke
    public private(set) var dropperOn = false
    public let scale: CGFloat

    private var drawPoints: [DrawPoint] = []
    private var lock = NSLock()

    public init(_ root: Flo,
                _ scale: CGFloat) {
        
        self.root = root
        self.scale = scale

        let sky    = root.bind("sky"   )
        let input  = sky .bind("input" )
        let pencil = input .bind("pencil")
        let canvas = root  .bind("canvas")
        let brush  = canvas.bind("brush" )
        let line   = canvas.bind("line"  )
        let screen = canvas.bind("screen")

        tilt˚    = input .bind("tilt"   ) { [weak self] f,_ in self?.tilt    = f.bool    }
        tiltReal˚ = input.bind("tiltReal") { [weak self] f,_ in self?.tiltReal = f.bool }
        press˚   = brush .bind("press"  ) { [weak self] f,_ in self?.press   = f.bool    }
        pressReal˚ = brush.bind("pressReal") { [weak self] f,_ in self?.pressReal = f.bool }
        size˚    = brush .bind("size"   ) { [weak self] f,_ in self?.size    = f.cgFloat }
        sizeReal˚ = brush.bind("sizeReal") { [weak self] f,_ in self?.sizeReal = f.cgFloat }
        index˚   = brush .bind("index"  ) { [weak self] f,_ in self?.brush   = f.uint32  }
        prev˚    = line  .bind("prev"   ) { [weak self] f,_ in self?.prev    = f.cgPoint }
        next˚    = line  .bind("next"   ) { [weak self] f,_ in self?.next    = f.cgPoint }
        force˚   = input .bind("force"  ) { [weak self] f,_ in self?.force   = f.cgFloat }
        radius˚  = input .bind("radius" ) { [weak self] f,_ in self?.radius  = f.cgFloat }
        azimuth˚ = input .bind("azimuth") { [weak self] f,_ in self?.azimuth = f.cgPoint }
        azimuthReal˚ = input.bind("azimuthReal")
        paint˚   = brush .bind("paint")
        fill˚    = screen.bind("fill"   ) { [weak self] f,_ in self?.setFill(f.float) }
        clear˚   = screen.bind("clear"  ) { [weak self] f,_ in self?.setClear(f.float) }
        pencilTilt˚ = pencil.bind("tilt")  // write-only: published per pencil sample
        dropper˚ = canvas.bind("dropper") { [weak self] f,_ in
            self?.dropperOn = (f.val("on") ?? 0) > 0.5 }
    }

    /// the eyedropper's half of a canvas touch: while it is armed, the touch
    /// hands its point to the next frame instead of drawing. The point goes
    /// over in drawable pixels, the units a stroke travels in
    public func dropperTook(_ point: CGPoint) -> Bool {
        guard dropperOn, let dropper˚ else { return false }
        dropper˚.setNameNums([("x", Double(point.x * scale)),
                              ("y", Double(point.y * scale)),
                              ("tap", 1)], .fire, Visitor(0))
        return true
    }

    /// pulse the false layer to a palette fraction; drops any pending strokes
    /// so the fill is the only draw command left for this frame.
    private func setFill(_ f: Float) {
        lock.lock()
        drawPoints.removeAll(keepingCapacity: true)
        drawPoints.append(DrawPoint(fill: f))
        lock.unlock()
    }

    /// pulse the real layer to transparent; same drop-and-queue as setFill so
    /// the two pulses stay consistent with each other.
    private func setClear(_ f: Float) {
        lock.lock()
        drawPoints.removeAll(keepingCapacity: true)
        drawPoints.append(DrawPoint(clear: f))
        lock.unlock()
    }

}

extension TouchDraw {
    /// get radius of TouchCanvasItem
    public func updateRadius(_ item: TouchCanvasItem) -> CGFloat {

        let visit = item.visit()
        let pinch = VisitType(rawValue: item.type).pinch

        // fingers report altitude 0 (or π/2) and force 0; a joint, midi dot or
        // an old peer carries the upright default. anything unusable reads
        // upright so the shading below stays at ×1 for everything but a pencil
        let upright = CGFloat(TouchCanvasItem.upright)
        let alt = item.altitude
        let altitude = (alt.isFinite && alt > 0) ? min(CGFloat(alt), upright) : upright
        let isPencil = !pinch && (item.force > 0 || altitude < upright - 0.01)
        // the lift sample (ended or cancelled) carries UIKit's estimate of the
        // tilt as the tip leaves the glass, never corrected afterwards; the
        // shift it would drive is sticky, so the stroke's last drawn tilt stands
        let lifting = item.isTouchDone

        // publish pencil tilt every sample: xy is the azimuth unit vector in the
        // same sign convention as the sky.input.azimuth shift, z the altitude
        // 0 flat … 1 upright. azimX/azimY are that vector already scaled by
        // tilt, so normalising them recovers the direction without the angle
        if isPencil, !lifting {
            let len = hypot(item.azimX, item.azimY)
            let ux = len > 0 ? -item.azimY / len : 0
            let uy = len > 0 ? -item.azimX / len : 0
            pencilTilt˚?.setNameNums([("x", ux), ("y", uy),
                                      ("z", Double(altitude / upright))], .fire, visit)
        }

        // if using Apple Pencil and brush tilt is turned on
        // the tilt shifts the layer the brush is on, real or false, each
        // behind its own switch
        let real = (paint˚?.val("w") ?? 0) > 0.5
        if item.force > 0, !lifting, real ? tiltReal : tilt, !pinch {

            let target = real ? azimuthReal˚ : azimuth˚
            target?.setNameNums([("x",-item.azimY),
                                 ("y",-item.azimX)], .fire, visit)
        }

        // if brush press is turned on -- the layer being painted has its own
        // press switch and its own size, so the two brushes are set apart
        let pressOn = real ? pressReal : press
        let sizeNow = real ? sizeReal : size
        var radiusNow = CGFloat(1)
        if pressOn {
            if force > 0 || item.azimX != 0.0 {
                force˚?.setVal(Double(item.force), .fire, visit) // will update local azimuth via FloGraph
                radiusNow = sizeNow
            } else {
                radius˚?.setVal(Double(item.radius), .fire, visit)
                radiusNow = radius
            }
        } else {
            radiusNow = sizeNow
        }
        // tilt shading: with tilt and press both on, a pencil lying flat paints
        // about three times wider; upright is ×1, so fingers never change
        if pressOn, real ? tiltReal : tilt, isPencil {
            radiusNow *= 1 + 2 * (1 - altitude / upright)
        }
        return radiusNow
    }

    public func takeDrawPoints() -> [DrawPoint] {

        lock.lock()
        let points = drawPoints
        drawPoints.removeAll()
        lock.unlock()
        
        return points

    }
}

extension TouchDraw {

    public func drawPoint(_ point: CGPoint,
                          _ radius: CGFloat) { 

        let drawPoint = DrawPoint(point, radius, brush, scale)
        lock.lock()
        drawPoints.append(drawPoint)
        lock.unlock()
    }
}
