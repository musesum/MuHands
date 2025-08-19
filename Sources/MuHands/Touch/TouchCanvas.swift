//  created by musesum on 2/5/19.

import UIKit
import MuFlo
import MuPeers

public typealias TouchDrawPoint = ((CGPoint, CGFloat)->())
public typealias TouchDrawRadius = ((TouchCanvasItem)->(CGFloat))

open class TouchCanvas: @unchecked Sendable {
    
    var touchRepeat = true
    var touchBuffers = [Int: TouchCanvasBuffer]()
    public let touchDraw: TouchDraw
    
    public let share: Share
    public var immersive = false
    public var drawableSize = CGSize.zero
    public let scale: CGFloat


    public init(_ touchDraw: TouchDraw,
                _ scale: CGFloat,
                _ share: Share) {
        self.touchDraw = touchDraw
        self.scale = scale
        self.share = share
        share.peers.addDelegate(self, for: .touchFrame)
    }

    public func flushTouchCanvas() {
        var removeKeys = [Int]()
        for (key, buf) in touchBuffers {
            let isDone = buf.flushTouches(touchRepeat)
            if isDone { removeKeys.append(key) }
        }
        for key in removeKeys {
            touchBuffers.removeValue(forKey: key)
        }
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
    public func remoteItem(_ item: TouchCanvasItem) {
        if let touchBuffer = touchBuffers[item.hash] {
            touchBuffer.buffer.addItem(item, bufType: .remoteBuf)
        } else {
            touchBuffers[item.hash] = TouchCanvasBuffer(item, self)
        }
    }
}
