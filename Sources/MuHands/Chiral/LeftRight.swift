// created by musesum on 1/22/24

import Foundation

open class LeftRight<T> {
    public var left: T { both.0 }
    public var right: T { both.1 }
    private var both: (T,T)

    public init(_ left: T, _ right: T) {
        self.both = (left, right)
    }
    func set(_ chiral: Chiral,_ t: T) {
        switch chiral {
        case .left: both.0 = t
        case .right: both.1 = t
        }
    }
    func get(_ chiral: Chiral) -> T {
        switch chiral {
        case .left: return both.0
        case .right: return both.1
        }
    }
}
public struct leftRight<T: Equatable>: Equatable {
    public static func == (lhs: leftRight<T>, rhs: leftRight<T>) -> Bool {
        (lhs.left == rhs.left) &&
        (lhs.right == rhs.right)
    }
    
    public var left: T { both.0 }
    public var right: T { both.1 }
    private let both: (T,T)
    public init(_ left: T, _ right: T) {
        self.both = (left, right)
    }
}
