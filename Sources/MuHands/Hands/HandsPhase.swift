// created by musesum on 7/16/25

import SwiftUI
import MuFlo

public enum PinchState: Int {
    case begin  = 0
    case update = 1
    case hover  = 2
    case end    = 3

    var begin  : Bool { self == .begin  }
    var update : Bool { self == .update }
    var hover  : Bool { self == .hover  }
    var end    : Bool { self == .end    }
}
@MainActor
open class HandsPhase: ObservableObject {

    @Published public var state: leftRight<PinchState> = .init(.end, .end)
    private var flo˚: LeftRight<Flo>!

    public init(_ root˚: Flo) {
        let pinch = root˚.bind("hand.pinch" )

        let left = pinch.bind("left" ) { f,_ in
            if let phase = f.intVal("phase") {
               guard let state = PinchState(rawValue: phase) else { return PrintLog("❌✋uncaught phase: \(phase)") }

                if [.begin, .end].contains(state) {
                    PrintLog("✋ left phase: \(state.rawValue)")

                    Task { @MainActor in
                        self.state = .init(state, self.state.right)
                    }
                }
            }
        }
        let right = pinch.bind("right") { f,_ in
            if let phase = f.intVal("phase") {
                guard let state = PinchState(rawValue: phase) else { return PrintLog("❌🤚uncaught phase: \(phase)") }

                if [.begin, .end].contains(state)  {
                    PrintLog("🤚 right phase: \(state.rawValue)")

                    Task { @MainActor in
                        self.state = .init(self.state.left, state)
                    }
                }
            }
        }
        self.flo˚ = .init(left, right)
    }

}

