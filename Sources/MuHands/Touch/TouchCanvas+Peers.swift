//  created by musesum on 12/19/22.

import Foundation
import MuPeers

extension TouchCanvas: PeersDelegate {

    public func received(data: Data, from: DataFrom) {
        let decoder = JSONDecoder()
        if let item = try? decoder.decode(TouchCanvasItem.self, from: data) {
            receiveItem(item, from: from)
        }
    }
    public func resetItem(_ playItem: PlayItem) {
        let decoder = JSONDecoder()
        if let item = try? decoder.decode(TouchCanvasItem.self, from: playItem.data) {
            resetItem(item)
        }

    }
    public func shareItem(_ item: Any) {
        guard let item = item as? TouchCanvasItem else { return }
        Task.detached {
            await Peers.shared.sendItem(.touchCanvas) { @Sendable in
                try? JSONEncoder().encode(item)
            }
        }
    }
}
