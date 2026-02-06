//  created by musesum on 2/5/19.

import UIKit
import MuFlo
import MuPeers // DataFrom

public typealias TouchDrawPoint = ((CGPoint, CGFloat)->())
public typealias TouchDrawRadius = ((TouchCanvasItem)->(CGFloat))

open class TouchCanvas: @unchecked Sendable {
    
    var touchRepeat = true
    var touchBuffers = [Int: TouchCanvasBuffer]()
    public let touchDraw: TouchDraw
    
    public var immersive = false
    public var drawableSize = CGSize.zero
    public let scale: CGFloat
    private var lock = NSLock()

    public init(_ touchDraw: TouchDraw,
                _ scale: CGFloat) {
        self.touchDraw = touchDraw
        self.scale = scale
        Task { @MainActor in
            Peers.shared.addDelegate(self, for: .touchCanvas)
        }
    }

    public func flushTouchCanvas() {
        var removeKeys = [Int]()
        for (key, buf) in touchBuffers {
            let isDone = buf.flushTouches(touchRepeat)
            if isDone {
                removeKeys.append(key)
            }
        }
        lock.lock()
        for key in removeKeys {
            touchBuffers.removeValue(forKey: key)
        }
        lock.unlock()
    }

    public func beginJointState(_ jointState: JointState) {
        touchBuffers[jointState.hash] = TouchCanvasBuffer(jointState, self)
        //DebugLog { P("👐 beginJoint \(jointState.joint˚?.path(2) ?? "??")") }
    }

    public func updateJointState(_ jointState: JointState) {
        if let touchBuffer = touchBuffers[jointState.hash] {
            touchBuffer.addTouchHand(jointState)
            // DebugLog { P("👐 updateHand hash: \(jointState.hash)") }
        } else {
            beginJointState(jointState)
            // DebugLog { P("👐 updateHand ⁉️ hash\(jointState.hash)") }
        }
    }
}

extension TouchCanvas { // + TouchData

    public func beginTouch(_ touchData: TouchData) {
        if immersive { return }
        touchBuffers[touchData.hash] = TouchCanvasBuffer(touchData, self)
    }

    public func updateTouch(_ touchData: TouchData) {
        if immersive { return }
        if let touchBuffer = touchBuffers[touchData.hash] {
            touchBuffer.addTouchItem(touchData)
        }
    }
    public func receiveItem(_ item: TouchCanvasItem, from: DataFrom) {
        if item.isTouchBegan {
            flushTouchCanvas()
        }
        if let touchBuffer = touchBuffers[item.hash] {
            touchBuffer.buffer.addItem(item, from: .remote)
        } else {
            touchBuffers[item.hash] = TouchCanvasBuffer(item, self)
        }
    }
    public func resetItem(_ item: TouchCanvasItem) {
        if let buffer = touchBuffers[item.hash] {
            buffer.resetAll()
            touchBuffers.removeValue(forKey: item.hash)
        }
    }
}
