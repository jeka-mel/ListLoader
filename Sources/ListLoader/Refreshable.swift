import Foundation

public enum RefreshMode {
    case force, outdated
}

public protocol Refreshable {
    /// How often `refresh action` can be executed.
    var refreshRate: TimeInterval { get }
    /// Date when last refresh was performed.
    var lastRefresh: Date? { get set }
    /// Actual data refresh action.
    func performRefresh(_ mode: RefreshMode, _ completion: @escaping (Error?) -> Void)
    /// Main method indicating if refresh is possible.
    /// - **Default implementation is provided.**
    /// - Can be overriden in the extesions for more specific usage.
    var canDoRefresh: Bool { get }
}

public enum RefreshError: Error {
    case queueIsBusy
    case upToDate
    case timeOut
}

extension Refreshable {

    public func refresh(_ mode: RefreshMode, completion: ((Error?) -> Void)? = nil) {
        if mode == .outdated && canDoRefresh == false {
            completion?(RefreshError.upToDate)
        } else {
            var this = self
            performRefresh(mode) { (error) in
                this.lastRefresh = Date()
                completion?(error)
            }
        }
    }
}

extension Refreshable where Self: ListLoader {

    public func syncRefresh(_ mode: RefreshMode) -> Result<[Item], Error> {
        return .init { () -> [Item] in
            let sem = DispatchSemaphore(value: 0)
            var error: Error?
            refresh(mode) { (e) in
                error = e
                sem.signal()
            }
            let r = sem.wait(timeout: .distantFuture)
            if r == .timedOut { throw RefreshError.timeOut }
            if let e = error { throw e }
            return self.items as? [Self.Item] ?? []
        }
    }
}
