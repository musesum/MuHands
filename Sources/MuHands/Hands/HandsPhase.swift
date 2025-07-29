// created by musesum on 7/16/25

import SwiftUI
import MuFlo

public enum PinchPhase: Int {
    case begin  = 0
    case update = 1
    case hover  = 2
    case end    = 3

    var begin  : Bool { self == .begin  }
    var update : Bool { self == .update }
    var hover  : Bool { self == .hover  }
    var end    : Bool { self == .end    }

    public var description: String {
        switch self {
        case .begin:  return "begin"
        case .update: return "update"
        case .hover:  return "hover"
        case .end:    return "end"
        }
    }
}
public struct PinchState {
    let phase: PinchPhase
    let finger: JointEnum

}
@MainActor
open class HandsPhase: ObservableObject {

    @Published public var state: leftRight<PinchPhase?> = .init(nil,nil)
    @Published public var update: Int = 0
    private var flo˚: LeftRight<Flo>!

    public init(_ root˚: Flo) {
        let pinch = root˚.bind("hand.pinch" )

        let left = pinch.bind("left" ) { f,_ in
            if let phase = f.intVal("phase") {
                guard let pinchPhase = PinchPhase(rawValue: phase) else { return PrintLog("⁉️✋ uncaught phase: \(phase)") }

                if [.begin, .end].contains(pinchPhase) {
                    PrintLog("✋ left phase: \(pinchPhase.rawValue)")
                }
                Task { @MainActor in
                    self.state = .init(pinchPhase, nil)
                    self.update += 1
                }
            }
        }
        let right = pinch.bind("right") { f,_ in
            if let phase = f.intVal("phase") {
                guard let pinchPhase = PinchPhase(rawValue: phase) else { return PrintLog("⁉️🤚uncaught phase: \(phase)") }

                if [.begin, .end].contains(pinchPhase)  {
                    PrintLog("🤚 right phase: \(pinchPhase.rawValue)")
                }
                Task { @MainActor in
                    self.state = .init(nil, pinchPhase)
                    self.update += 1
                }
            }
        }
        self.flo˚ = .init(left, right)
    }

    public var icon: String {
        var ret = ""
        if let phase = state.left {
            switch phase  {
            case .begin : ret += "🔰"
            case .end   : ret += "♦️"
            default     : ret += "🔸"
            }
        } else {
            ret += "⬜︎"
        }
        ret += "👐"
        if let phase = state.right {
            switch phase  {
            case .begin : ret += "🔰"
            case .end   : ret += "♦️"
            default     : ret += "🔸"
            }
        } else {
            ret += "⬜︎"
        }
        return ret
    }
}

