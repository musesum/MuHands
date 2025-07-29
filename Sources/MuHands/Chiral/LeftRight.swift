// created by musesum on 1/22/24

import Foundation

open class LeftRight<T> {
    public let left: T
    public let right: T
    public init(_ left: T, _ right: T) {
        self.left = left
        self.right = right
    }
}
public struct leftRight<T: Equatable>: Equatable {
    public let left: T
    public let right: T
    public init(_ left: T, _ right: T) {
        self.left = left
        self.right = right
    }
}
