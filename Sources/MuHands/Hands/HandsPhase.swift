// created by musesum on 7/16/25

import SwiftUI
import MuFlo

public enum TouchPhase: Int {
    case began  = 0
    case update = 1
    case ended  = 3

    public var begin  : Bool { self == .began  }
    public var update : Bool { self == .update }
    public var end    : Bool { self == .ended  }

    public var description: String {
        switch self {
        case .began  : return "begin"
        case .update : return "update"
        case .ended  : return "end"
        }
    }
    public static func min(_ state: leftRight<TouchPhase?>) -> TouchPhase {
        let lvalue = state.left ?? .ended
        let rvalue = state.right ?? .ended
        return lvalue.rawValue < rvalue.rawValue ? lvalue : rvalue
    }
}

public struct PinchState {
    let phase: TouchPhase
    let finger: JointEnum

}
@MainActor
open class HandsPhase: ObservableObject {

    @Published public var update: Int = 0
    public var state: leftRight<TouchPhase?> = .init(nil,nil)
    public var taps: LeftRight<Int> = .init(0,0)

    private var flo˚: LeftRight<Flo>!
    private var began: LeftRight<TimeInterval> = .init(0,0)
    private var ended: LeftRight<TimeInterval> = .init(0,0)

    public init(_ root˚: Flo) {
        let pinch = root˚.bind("hand.pinch" )

        let left = pinch.bind("left" ) { f,_ in  self.pinched(f, .left) }
        let right = pinch.bind("right") { f,_ in self.pinched(f, .right) }
        self.flo˚ = .init(left, right)
    }
    func pinched(_ flo: Flo, _ chiral: Chiral) {
        guard let rawPhase = flo.intVal("phase") else {
            return err("'phase' expression not found.") }
        guard let phase = TouchPhase(rawValue: rawPhase) else {
            return err("rawPhase: \(rawPhase) invalid.") }

        let timeNow = Date().timeIntervalSince1970

        switch phase {
        case .began:
            began.set(chiral, timeNow)
        case .ended:
            began.set(chiral, timeNow)
            let delta = ended.get(chiral) - began.get(chiral)
            let tapsNow = delta < 0.3 ? taps.get(chiral) + 1 : 0
            taps.set(chiral, tapsNow)
        default: break
        }

        Task { @MainActor in
            switch chiral {
            case .left  : state = .init(phase, nil)
            case .right : state = .init(nil, phase)
            }
            update += 1
        }
        func err(_ msg: String) {
            PrintLog("⁉️\(chiral.icon) \(#function) \(msg)")
        }
    }

    public var handsState: String {
        var ret = ""
        if let phase = state.left {
            switch phase  {
            case .began : ret += "🔰"
            case .ended : ret += "🛑"
            default     : ret += "🔷"
            }
        } else {
            ret += "⬜︎"
        }
        ret += "👐"
        if let phase = state.right {
            switch phase  {
            case .began : ret += "🔰"
            case .ended : ret += "🛑"
            default     : ret += "🔷"
            }
        } else {
            ret += "⬜︎"
        }
        if taps.left > 0 || taps.right > 0 {
            ret += " taps: \(taps.left)👐\(taps.right)"
        }
        return ret
    }
}

