import Foundation

public extension Refreshable where Self: ListLoader {

    func performRefresh(_ mode: RefreshMode, _ completion: @escaping (Error?) -> Void) {
        if isBusy {
            completion(RefreshError.queueIsBusy)
        } else {
            load(page: .current) { (result) in
                completion(result.error)
            }
        }
    }

    var canDoRefresh: Bool {
        guard let lr = lastRefresh, items.count != 0 else { return true }
        return Date().timeIntervalSince(lr) > refreshRate
    }
}

public extension ChunkLoadable where Self: Refreshable & ListLoader {
    func performRefresh(_ mode: RefreshMode, _ completion: @escaping (Error?) -> Void) {
        if isBusy {
            completion(RefreshError.queueIsBusy)
        } else {
            loadChunks(for: .current) { (result) in
                completion(result.error)
            }
        }
    }
}
