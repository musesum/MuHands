//  created by musesum on 2/5/19.

import UIKit
import MuFlo
import MuPeers // DataFrom

public typealias TouchDrawPoint = ((CGPoint, CGFloat)->())
public typealias TouchDrawRadius = ((TouchCanvasItem)->(CGFloat))

open class TouchCanvas: @unchecked Sendable {
    
    var touchRepeat = true
    var touchBuffers = [Int: TouchBuffer]()

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
        lock.lock(); defer { lock.unlock() }
        var removeKeys = [Int]()
        for (key, buf) in touchBuffers {
            let isDone = buf.flushTouches(touchRepeat)
            if isDone {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            touchBuffers.removeValue(forKey: key)
        }
    }

    public func beginJointState(_ jointState: JointState) {
        touchBuffers[jointState.hash] = TouchBuffer(jointState, self)
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
        lock.lock() ; defer { lock.unlock() }
        touchBuffers[touchData.hash] = TouchBuffer(touchData, self)
    }

    public func updateTouch(_ touchData: TouchData) {
        if immersive { return }
        lock.lock() ; defer { lock.unlock() }
        if let touchBuffer = touchBuffers[touchData.hash] {
            touchBuffer.addTouchItem(touchData)
        }
    }
    public func receiveItem(_ item: TouchCanvasItem, from: DataFrom) {
        if item.isTouchBegan {
            flushTouchCanvas()
        }
        lock.lock() ; defer { lock.unlock() }
        if let touchBuffer = touchBuffers[item.hash] {
            touchBuffer.addItem(item, from: .remote)
        } else {
            touchBuffers[item.hash] = TouchBuffer(item, self)
        }
    }
    public func resetItem(_ item: TouchCanvasItem) {
        lock.lock() ; defer { lock.unlock() }
        if let buffer = touchBuffers[item.hash] {
            buffer.resetAll()
            touchBuffers.removeValue(forKey: item.hash)
        }
    }
}
