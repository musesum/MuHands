//  created by musesum on 8/22/23.

import UIKit
import MuFlo
import MuPeers

open class TouchCanvasBuffer: @unchecked Sendable {
    private let itemId: Int

    // smooth and/or repeat last time
    private var previousItem: TouchCanvasItem?
    
    // each finger or brush gets its own double buffer
    public let buffer: TimedBuffer<TouchCanvasItem>
    private var indexNow = 0
    private var canvas: TouchCanvas
    private var isDone = false
    private var touchCubic = TouchCubic()
    private var touchLog = TouchLog()

    public init(_ touch: TouchData,
                _ canvas: TouchCanvas) {
        
        self.canvas = canvas
        self.buffer = TimedBuffer<TouchCanvasItem>(capacity: 8)
        self.itemId = touch.hash

        buffer.delegate = self
        addTouchItem(touch)
        Reset.addReset(itemId, self)
    }
    
    public init(_ item: TouchCanvasItem,
                _ canvas: TouchCanvas) {

        self.canvas = canvas
        self.buffer = TimedBuffer<TouchCanvasItem>(capacity: 8)
        self.itemId = item.hash

        buffer.delegate = self
        buffer.addItem(item, from: .remote)

        Reset.addReset(itemId, self) //..... was id
    }
    
    public init(_ joint: JointState,
                _ canvas: TouchCanvas) {
        
        self.canvas = canvas
        self.buffer = TimedBuffer<TouchCanvasItem>(capacity: 8)
        self.itemId = joint.joint.rawValue
        buffer.delegate = self
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
        buffer.addItem(item, from: .local)
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
        buffer.addItem(item, from: .local)
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
            let state = buffer.flushBuf()
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
            tearDown()
        }
        return isDone
    }
}

extension TouchCanvasBuffer: TimedBufferDelegate {
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

extension TouchCanvasBuffer: ResetDelegate {
    public func resetAll() {
        print("TapeCanvasBuffer::\(#function)") //.....
        buffer.resetAll() // assuming reset() empties the buffer; replace with buffer.clear() if that is the correct API
        previousItem = nil
        indexNow = 0
        isDone = false
        touchCubic = TouchCubic()
        touchLog = TouchLog()
    }
    public func tearDown() {
        buffer.tearDown() //..... redundant?
        Reset.removeReset(itemId)
    }
}
