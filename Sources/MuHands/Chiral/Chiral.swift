// created by musesum on 3/17/24

import Foundation

//  allow non-VisionOS to indicate Chirality handedness
public enum Chiral: Int {
    case left   = 0
    case right  = 1

    public var name: String {
        switch self {
        case .left   : "left"
        case .right  : "right"
        }
    }
    public var icon: String {
        switch self {
        case .left   : "✋"
        case .right  : "🤚"
        }
    }
}
