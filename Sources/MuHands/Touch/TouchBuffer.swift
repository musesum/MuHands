//  created by musesum on 8/22/23.

import UIKit
import MuFlo
import MuPeers
import NIOCore

open class TouchBuffer: @unchecked Sendable {
    private let itemId: Int

    // smooth and/or repeat last time
    private var previousItem: TouchCanvasItem?
    
    // each finger or brush gets its own double buffer
    public var buffer = CircularBuffer<(TouchCanvasItem, TimeInterval, DataFrom)>(initialCapacity: 8)
    private var indexNow = 0
    private var canvas: TouchCanvas
    private var isDone = false
    private var touchCubic = TouchCubic()
    private var touchLog = TouchLog()
    private var lock = NSLock()

    private var minLag: TimeInterval = 0.200 // static minimum timelag 200 msec
    private var maxLag: TimeInterval = 2.00 // stay within 2 second delay
    private var nextLag: TimeInterval = 1.00 // filtered next timelag
    private var filterLag: Double = 0.95

    private var prevItem: Item?
    private var prevItemTime: TimeInterval?
    private var prevFlushTime: TimeInterval?
    private var prevFuture: TimeInterval?

    public var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return buffer.isEmpty
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return buffer.count
    }


    public init(_ touch: TouchData,
                _ canvas: TouchCanvas) {
        
        self.canvas = canvas
        self.itemId = touch.hash

        addTouchItem(touch)
        Reset.addReset(itemId, self)
    }
    
    public init(_ item: TouchCanvasItem,
                _ canvas: TouchCanvas) {

        self.canvas = canvas
        self.itemId = item.hash
        addItem(item, from: .remote)
        Reset.addReset(itemId, self)
    }
    
    public init(_ joint: JointState,
                _ canvas: TouchCanvas) {
        
        self.canvas = canvas
        self.itemId = joint.joint.rawValue
        addTouchHand(joint)
        Reset.addReset(itemId, self)
    }

    public func addTouchHand(_ joint: JointState) {

        let force = CGFloat(joint.pos.z) * -200
        let radius = force
        let nextXY = CGPoint(x: CGFloat( joint.pos.x * 400 + 800),
                             y: CGFloat(-joint.pos.y * 400 + 800))
        
        let phase = joint.phase
        let time = joint.time

        touchLog.log(phase, nextXY, radius)
        
        let item = TouchCanvasItem(previousItem, joint.hash, force, radius, nextXY, phase, time, Visitor(0, [.pinch,.canvas]))
        addItem(item, from: .local)
        canvas.shareItem(item)
    }
    func shareItem(_ item: TouchCanvasItem) {
   
        Task.detached {
            await Peers.shared.sendItem(.touchCanvas) { @Sendable in
                try? JSONEncoder().encode(item)
            }
        }
    }

    public func addTouchItem(_ touchData: TouchData) {

        let item = TouchCanvasItem(previousItem, touchData)
        addItem(item, from: .local)
        let payload: Data? = try? JSONEncoder().encode(item)
        Task.detached {
            await Peers.shared.sendItem(.touchCanvas) {
                @Sendable in payload
            }
        }
    }

    func flushTouches(_ touchRepeat: Bool) -> Bool {
        
        if buffer.isEmpty,
           touchRepeat,
           let previousItem {
            // finger is stationary repeat last movement
            touchCubic.drawPoints(canvas.touchDraw.drawPoint)
            if previousItem.isTouchDone {
                isDone = true
            }

        } else {
            let state = flushBuf()
            switch state {
            case .doneBuf:
                isDone = true
            case .waitBuf:
                if touchRepeat,
                   previousItem != nil {
                    touchCubic.drawPoints(canvas.touchDraw.drawPoint)
                }
            case .nextBuf: break

            }
        }
        if isDone {
            Reset.removeReset(itemId)
        }
        return isDone
    }
}

extension TouchBuffer { // Timed Buffer

    public func addItem(_ item: Item, from: DataFrom) {

        let timeNow = Date().timeIntervalSince1970

        switch from {
        case .loop: fallthrough
        case .local:
            lock.lock()
            buffer.append((item, timeNow, from))
            lock.unlock()

        case .remote:
            let itemLag = timeNow - item.time
            nextLag = nextLag * filterLag + max(minLag, itemLag) * (1-filterLag)
            var futureTime = item.time + nextLag

            if let prevItem,
               let prevFuture {

                // preserve the duration between item events
                // but catchup on any delays
                let duration = item.time - prevItem.time
                let catchup = min(1, maxLag/itemLag)
                futureTime = max(futureTime, prevFuture + duration * catchup)
            }
            lock.lock()
            buffer.append((item, futureTime, from))
            lock.unlock()

            prevItem = item
            prevFuture = futureTime
        }
    }
    public func flushBuf() -> BufState {

        var state: BufState = .nextBuf
        while !buffer.isEmpty, state != .doneBuf {

            let timeNow = Date().timeIntervalSince1970

            lock.lock(); defer { lock.unlock() }

            guard let (item, futureTime, type) = buffer.first else { return .doneBuf }
            if futureTime > timeNow {  return .waitBuf }

            state = flushItem(item, type)

            NoTimeLog("\(self.itemId)", interval: 0.5 ) { P("⏱️ id.state: \(self.itemId).\(state.description)") }

            if state == .nextBuf {
                _ = buffer.removeFirst()
            }
        }
        return state
    }

    public typealias Item = TouchCanvasItem

    public func flushItem<Item>(_ item: Item, _ from: DataFrom) -> BufState {
        guard let item = item as? TouchCanvasItem else { return .nextBuf }
        let radius = canvas.touchDraw.updateRadius(item)
        let point = item.cgPoint
        isDone = item.isTouchDone
        previousItem = isDone ? nil : item.repeated()
        touchCubic.addPointRadius(point, radius, isDone)
        touchCubic.drawPoints(canvas.touchDraw.drawPoint)
        return isDone ? .doneBuf : .nextBuf
    }
}

extension TouchBuffer: ResetDelegate {
    public func resetAll() {
        PrintLog("TouchBuffer::resetAll id: \(itemId)")

        lock.lock()
        buffer.removeAll()
        lock.unlock()

        previousItem = nil
        indexNow = 0
        isDone = false
        touchCubic = TouchCubic()
        touchLog = TouchLog()
    }
}
