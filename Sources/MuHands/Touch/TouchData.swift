// created by musesum on 6/26/25

import UIKit
import MuFlo

public typealias Hash = Int

public struct TouchData {
    let force    : Float
    let radius   : Float
    let nextXY   : CGPoint
    let phase    : Int
    let azimuth  : CGFloat
    let altitude : CGFloat
    let hash     : Hash
    let type     : Int
    let time     : TimeInterval

    public init(force    : Float,
                radius   : Float,
                nextXY   : CGPoint,
                phase    : Int,
                azimuth  : CGFloat,
                altitude : CGFloat,
                hash     : Hash,
                type     : Int,
                time     : TimeInterval) {

        self.force    = force
        self.radius   = radius
        self.nextXY   = nextXY
        self.phase    = phase
        self.azimuth  = azimuth
        self.altitude = altitude
        self.hash     = hash
        self.type     = type
        self.time     = time
    }
}
