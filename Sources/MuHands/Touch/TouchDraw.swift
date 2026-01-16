import QuartzCore
import MuFlo
import Dispatch

public class TouchDraw: @unchecked Sendable {

    var root     : Flo?
    var tilt˚    : Flo?
    var press˚   : Flo?
    var size˚    : Flo?
    var index˚   : Flo?
    var prev˚    : Flo?
    var next˚    : Flo?
    var force˚   : Flo?
    var radius˚  : Flo?
    var azimuth˚ : Flo?
    var fill˚    : Flo?

    public private(set) var tilt    = false
    public private(set) var press   = true
    public private(set) var size    = CGFloat(1)
    public private(set) var brush   = UInt32(255)
    public private(set) var prev    = CGPoint.zero
    public private(set) var next    = CGPoint.zero
    public private(set) var force   = CGFloat(0)
    public private(set) var radius  = CGFloat(0)
    public private(set) var azimuth = CGPoint.zero
    public let scale: CGFloat

    private var drawPoints: [DrawPoint] = []
    private var lock = NSLock()

    public init(_ root: Flo,
                _ scale: CGFloat) {
        
        self.root = root
        self.scale = scale

        let sky    = root.bind("sky"   )
        let input  = sky .bind("input" )
        let draw   = root.bind("draw"  )
        let brush  = draw.bind("brush" )
        let line   = draw.bind("line"  )
        let screen = draw.bind("screen")

        tilt˚    = input .bind("tilt"   ) { [weak self] f,_ in self?.tilt    = f.bool    }
        press˚   = brush .bind("press"  ) { [weak self] f,_ in self?.press   = f.bool    }
        size˚    = brush .bind("size"   ) { [weak self] f,_ in self?.size    = f.cgFloat }
        index˚   = brush .bind("index"  ) { [weak self] f,_ in self?.brush   = f.uint32  }
        prev˚    = line  .bind("prev"   ) { [weak self] f,_ in self?.prev    = f.cgPoint }
        next˚    = line  .bind("next"   ) { [weak self] f,_ in self?.next    = f.cgPoint }
        force˚   = input .bind("force"  ) { [weak self] f,_ in self?.force   = f.cgFloat }
        radius˚  = input .bind("radius" ) { [weak self] f,_ in self?.radius  = f.cgFloat }
        azimuth˚ = input .bind("azimuth") { [weak self] f,_ in self?.azimuth = f.cgPoint }
        fill˚    = screen.bind("fill"   ) { [weak self] f,_ in self?.setFill(f.float) }
    }

    private func setFill(_ f: Float) {
        lock.lock()
        drawPoints.removeAll(keepingCapacity: true)
        drawPoints.append(DrawPoint(fill: f))
        lock.unlock()
    }

}

extension TouchDraw {
    /// get radius of TouchCanvasItem
    public func updateRadius(_ item: TouchCanvasItem) -> CGFloat {

        let visit = item.visit()

        // if using Apple Pencil and brush tilt is turned on
        if item.force > 0, tilt, !VisitType(rawValue: item.type).pinch {

            azimuth˚?.setNameNums([("x",-item.azimY),
                                   ("y",-item.azimX)], .fire, visit)
        }

        // if brush press is turned on
        var radiusNow = CGFloat(1)
        if press {
            if force > 0 || item.azimX != 0.0 {
                force˚?.setVal(Double(item.force), .fire, visit) // will update local azimuth via FloGraph
                radiusNow = size
            } else {
                radius˚?.setVal(Double(item.radius), .fire, visit)
                radiusNow = radius
            }
        } else {
            radiusNow = size
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
