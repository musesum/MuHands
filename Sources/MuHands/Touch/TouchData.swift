// created by musesum on 6/26/25

import UIKit

public typealias Hash = Int

public struct TouchData {
    let force    : Float
    let radius   : Float
    let nextXY   : CGPoint
    let phase    : Int
    let azimuth  : CGFloat
    let altitude : CGFloat
    let hash     : Hash

    public init(force    : Float,
                radius   : Float,
                nextXY   : CGPoint,
                phase    : Int,
                azimuth  : CGFloat,
                altitude : CGFloat,
                hash     : Hash) {

        self.force    = force
        self.radius   = radius
        self.nextXY   = nextXY
        self.phase    = phase
        self.azimuth  = azimuth
        self.altitude = altitude
        self.hash     = hash
    }
}
