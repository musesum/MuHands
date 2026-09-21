import UIKit
import MuFlo

public struct TouchCanvasItem: Codable, Sendable {

    public let hash   : Hash   // unique id of touch
    public let time   : Double // time event was created
    public let nextX  : Float  // touch point x
    public let nextY  : Float  // touch point y
    public let force  : Float  // pencil pressure
    public let radius : Float  // size of dot
    public let azimX  : Double // pencil tilt X
    public let azimY  : Double // pencil tilt Y
    public let phase  : Int    // UITouch.Phase.rawValue
    public let type   : Int    // Visitor.type
    /// pencil altitude in radians, π/2 upright; fingers, joints, midi dots and
    /// items from a peer that predates the field all read upright, so the tilt
    /// shading in TouchDraw leaves their radius alone
    public let altitude : Double

    public static let upright = Double.pi / 2

    /// altitude arrived after the peer/tape wire format; a payload without
    /// the key decodes as upright rather than failing the whole item
    enum CodingKeys: String, CodingKey {
        case hash, time, nextX, nextY, force, radius, azimX, azimY, phase, type, altitude
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hash     = try c.decode(Hash.self,   forKey: .hash)
        time     = try c.decode(Double.self, forKey: .time)
        nextX    = try c.decode(Float.self,  forKey: .nextX)
        nextY    = try c.decode(Float.self,  forKey: .nextY)
        force    = try c.decode(Float.self,  forKey: .force)
        radius   = try c.decode(Float.self,  forKey: .radius)
        azimX    = try c.decode(Double.self, forKey: .azimX)
        azimY    = try c.decode(Double.self, forKey: .azimY)
        phase    = try c.decode(Int.self,    forKey: .phase)
        type     = try c.decode(Int.self,    forKey: .type)
        altitude = try c.decodeIfPresent(Double.self, forKey: .altitude) ?? Self.upright
    }

    public init(_ hash     : Hash,
                _ next     : CGPoint,
                _ radius   : Float,
                _ force    : Float,
                _ azimuth  : CGVector,
                _ phase    : UITouch.Phase,
                _ time     : TimeInterval,
                _ visit    : Visitor,
                _ altitude : CGFloat = TouchCanvasItem.upright) {

        // tested timeDrift between UITouches.time and Date() is around 30 msec
        self.time     = time
        self.hash     = hash
        self.nextX    = Float(next.x)
        self.nextY    = Float(next.y)
        self.radius   = Float(radius)
        self.force    = Float(force)
        self.azimX    = azimuth.dx
        self.azimY    = azimuth.dy
        self.phase    = Int(phase.rawValue)
        self.type     = visit.type.rawValue
        self.altitude = Double(altitude)
    }
    init(_ prevItem: TouchCanvasItem?,
         _ touchData: TouchData) {

        let azimuth = TouchCanvasItem.touchAzim(touchData)
        let (force,radius) = prevItem?.filterForceRadius(touchData.force,
                                                         touchData.radius) ?? (0,touchData.radius)
        self.time   = touchData.time
        self.hash   = touchData.hash
        self.nextX  = Float(touchData.nextXY.x)
        self.nextY  = Float(touchData.nextXY.y)
        self.radius = radius
        self.force  = force
        self.azimX  = azimuth.dx
        self.azimY  = azimuth.dy
        self.phase  = touchData.phase
        self.type   = VisitType.canvas.rawValue
        self.altitude = Double(touchData.altitude)
        //PrintLog("touchCanvasItem: \(nextX.digits(3)),\(nextY.digits(3))" )
    }

    init(_ prevItem : TouchCanvasItem? = nil,
         _ hash     : Int,
         _ force    : CGFloat,
         _ radius   : CGFloat,
         _ next     : CGPoint,
         _ phase    : UITouch.Phase,
         _ time     : TimeInterval,
         _ visit    : Visitor) {

        let (force,radius) = prevItem?.filterForceRadius(force,radius) ?? (0,Float(radius))
        self.time   = time
        self.hash   = hash
        self.nextX  = Float(next.x)
        self.nextY  = Float(next.y)
        self.radius = radius
        self.force  = force
        self.azimX  = 0
        self.azimY  = 0
        self.phase  = Int(phase.rawValue)
        self.type   = visit.type.rawValue
        self.altitude = Self.upright
    }

    init(_ prevItem : TouchCanvasItem? = nil,
         _ hash     : Int,
         _ force    : CGFloat,
         _ radius   : CGFloat,
         _ next     : CGPoint,
         _ phase    : UITouch.Phase,
         _ azimuth  : CGFloat,
         _ altitude : CGFloat,
         _ visit    : Visitor) {

        let azimuth = TouchCanvasItem.touchAzim(visit.type.rawValue, azimuth, altitude)
        let (force,radius) = prevItem?.filterForceRadius(force,radius) ?? (0,Float(radius))

        self.time   = Date().timeIntervalSince1970
        self.hash   = hash
        self.nextX  = Float(next.x)
        self.nextY  = Float(next.y)
        self.radius = radius
        self.force  = force
        self.azimX  = azimuth.dx
        self.azimY  = azimuth.dy
        self.phase  = Int(phase.rawValue)
        self.type   = visit.type.rawValue
        self.altitude = Double(altitude)
    }
    init(repeated: TouchCanvasItem) {

        self.time   = Date().timeIntervalSince1970
        self.hash   = repeated.hash
        self.nextX  = repeated.nextX
        self.nextY  = repeated.nextY
        self.radius = repeated.radius
        self.force  = repeated.force
        self.azimX  = repeated.azimX
        self.azimY  = repeated.azimY
        self.phase  = repeated.phase
        self.type   = repeated.type
        self.altitude = repeated.altitude
    }
    static func touchAzim(_ touchData: TouchData) -> CGVector {
        return touchAzim(touchData.type,
                         touchData.altitude,
                         touchData.azimuth)
    }

    static func touchAzim(_ type: Int, _ altitude: CGFloat, _ azimuth: CGFloat) -> CGVector {
        // test for pinch
        if VisitType(rawValue: type).pinch {
            return CGVector(dx: 0, dy: 0)
        } else {
            let alti = (.pi/2 - altitude) / .pi/2
            return CGVector(dx: -sin(azimuth) * alti, dy: cos(azimuth) * alti)
        }
    }


    func filterForceRadius(_ force: Float,
                           _ radius: Float) -> (force: Float,
                                                radius: Float) {
        let forceFilter  = Float(0.90)
        let radiusFilter = Float(0.95)

        let force  = (self.force  * forceFilter)  + (force  * (1-forceFilter))
        let radius = (self.radius * radiusFilter) + (radius * (1-radiusFilter))
        return(force, radius)
    }

    func filterForceRadius(_ force: CGFloat,
                           _ radius: CGFloat) -> (force: Float,
                                                  radius: Float) {
        return filterForceRadius(Float(force),Float(radius))
    }
    func repeated() -> TouchCanvasItem {
        return TouchCanvasItem(repeated: self)
    }

    var cgPoint: CGPoint { get {
        CGPoint(x: CGFloat(nextX), y: CGFloat(nextY))
    }}
    var visitFrom: String {
        VisitType(rawValue: type).log
    }
    public func visit() -> Visitor {
        return Visitor(0, VisitType(rawValue: type))
    }

    var isTouchBegan: Bool {
        phase == UITouch.Phase.began.rawValue
    }
    var isTouchDone: Bool {
        return [UITouch.Phase.ended.rawValue,
                UITouch.Phase.cancelled.rawValue]
            .contains(phase)
    }
}

