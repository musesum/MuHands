// created by musesum on 3/17/24

import ARKit
import MuFlo

#if os(visionOS)

// @unchecked Sendable: session/handTracking are touched only from the async
// start/update/monitor chain; annotation admits the existing access pattern
// to Swift 6 without changing behavior.
open class HandsTracker: ObservableObject, @unchecked Sendable {

    let session = ARKitSession()
    var handTracking: HandTrackingProvider?
    let handsPose: LeftRight<HandPose>

    public init(_ handsFlo: LeftRight<HandPose>) {

        self.handsPose = handsFlo
    }

    public func startHands() async {

        do {
            if HandTrackingProvider.isSupported,
              handTracking == nil
            {
                PrintLog("🤲 start handTracking.")
                handTracking = HandTrackingProvider()
                try await session.run([handTracking!])
                await updateHands()
                await monitorSessionEvents()
            }
        } catch {
            PrintLog("⁉️ 🤲 handTracking error: \(error)")
        }
    }

    public func updateHands() async {
        guard let handTracking else { return }
        for await update in handTracking.anchorUpdates {
            
            if update.event == .updated,
               update.anchor.isTracked {

                switch update.anchor.chirality {
                case .left : await handsPose.left.updateAnchor(update.anchor, handsPose.right)
                case .right: await handsPose.right.updateAnchor(update.anchor, handsPose.left)
                }
            }
        }
    }
    public func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                if type == .handTracking && status != .allowed {
                    // Ask the user to grant hand tracking authorization again in Settings.
                }
            default:
                PrintLog("Session event \(event)")
            }
        }
    }
}
#else
/// this is a stub for non-visionOS devices to
/// accept HandTracker events via MuPeers (Bonjour)
#endif
