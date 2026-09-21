//  created by musesum on 2/5/19.

import UIKit
import MuFlo
import MuPeers // DataFrom

public typealias TouchDrawPoint = ((CGPoint, CGFloat)->())
public typealias TouchDrawRadius = ((TouchCanvasItem)->(CGFloat))

open class TouchCanvas: @unchecked Sendable {
    
    var touchRepeat = true
    var touchBuffers = [Int: TouchBuffer]()
    var peerTouches = [String: Set<Int>]()

    public let touchDraw: TouchDraw
    /// every canvas touch begin, in view points; true takes the touch — no
    /// stroke for that touch id (the plato object subscribes)
    public var touchBegan: ((CGPoint) -> Bool)?
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
        // snapshot under the lock, draw outside it: flushTouches reaches the
        // canvas and the hand stream writes the same dictionary, so holding the
        // lock across the draw put the two threads in each other's way
        guard lock.lock(before: Date().addingTimeInterval(0.5)) else {
            return PrintLog("⁉️ TouchCanvas flush blocked 0.5s")
        }
        let frame = touchBuffers
        lock.unlock()

        var removeKeys = [Int]()
        for (key, buf) in frame {
            if buf.flushTouches(touchRepeat) {
                removeKeys.append(key)
            }
        }
        if removeKeys.isEmpty { return }
        lock.lock()
        for key in removeKeys {
            touchBuffers.removeValue(forKey: key)
        }
        lock.unlock()
    }

    /// the hand path writes the same dictionary `flushTouchCanvas` walks, from
    /// the ARKit stream rather than the render thread, and it took no lock —
    /// the immersive guards below make the locked touch entries unreachable in
    /// mixed and full, so this was the only writer there
    public func beginJointState(_ jointState: JointState) {
        lock.lock() ; defer { lock.unlock() }
        beginJointLocked(jointState)
    }

    public func updateJointState(_ jointState: JointState) {
        lock.lock() ; defer { lock.unlock() }
        if let touchBuffer = touchBuffers[jointState.hash] {
            touchBuffer.addTouchHand(jointState)
        } else {
            beginJointLocked(jointState)
        }
    }
    /// caller holds `lock`
    private func beginJointLocked(_ jointState: JointState) {
        touchBuffers[jointState.hash] = TouchBuffer(jointState, self)
    }
}

extension TouchCanvas { // + TouchData

    public func beginTouch(_ touchData: TouchData) {
        if immersive { return }
        // the eyedropper goes first: while it is armed every canvas touch is
        // a colour to take, whatever is under it, plato objects included
        if touchDraw.dropperTook(touchData.nextXY) { return }
        if touchBegan?(touchData.nextXY) == true { return } // no buffer: updates for this id draw nothing
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
        
        // Track remote touches by peer
        if case .remote(let peerId) = from {
            if peerTouches[peerId] == nil { peerTouches[peerId] = [] }
            peerTouches[peerId]?.insert(item.hash)
        }
        
        if let touchBuffer = touchBuffers[item.hash] {
            touchBuffer.addItem(item, from: .remote("?"))
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
    
    public func clearPeerTouches(_ peerId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let hashes = peerTouches[peerId] else { return }
        
        for hash in hashes {
            if let buffer = touchBuffers[hash] {
                buffer.resetAll() 
                touchBuffers.removeValue(forKey: hash)
            }
        }
        peerTouches.removeValue(forKey: peerId)
    }
}
