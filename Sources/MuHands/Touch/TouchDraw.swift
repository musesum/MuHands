
import QuartzCore
import MuFlo

public class TouchDraw {

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

    public var drawPoints: [DrawPoint] = []

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

        tilt˚    = input .bind("tilt"   ) { f,_ in self.tilt    = f.bool    }
        press˚   = brush .bind("press"  ) { f,_ in self.press   = f.bool    }
        size˚    = brush .bind("size"   ) { f,_ in self.size    = f.cgFloat }
        index˚   = brush .bind("index"  ) { f,_ in self.brush   = f.uint32  }
        prev˚    = line  .bind("prev"   ) { f,_ in self.prev    = f.cgPoint }
        next˚    = line  .bind("next"   ) { f,_ in self.next    = f.cgPoint }
        force˚   = input .bind("force"  ) { f,_ in self.force   = f.cgFloat }
        radius˚  = input .bind("radius" ) { f,_ in self.radius  = f.cgFloat }
        azimuth˚ = input .bind("azimuth") { f,_ in self.azimuth = f.cgPoint }
        fill˚    = screen.bind("fill"   ) { f,_ in setFill(f.float)
        }
        func setFill(_ f: Float) {
            drawPoints.removeAll(keepingCapacity: true)
            drawPoints.append(DrawPoint(fill: f))
        }
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

}

extension TouchDraw {

    public func drawPoint(_ point: CGPoint,
                          _ radius: CGFloat) {

        let drawPoint = DrawPoint(point, radius, brush, scale)
        drawPoints.append(drawPoint)
    }
}
