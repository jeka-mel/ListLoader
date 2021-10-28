import Foundation

/// Implementations of this protocol aimed to be responsible for downloading a paginated (or not) list data from backend.
/// It also should have a control over adding items to target collection (`List`).
/// Protocol methods providing an ability to handle serial requests
public protocol ListLoader: AnyObject {

    associatedtype ItemsList: Collection

    var items: ItemsList { get }
    var paginator: Paginator { get set }
    /// Serial queue for all incoming operations which are being passed to the list
    var queue: SerialQueue { get }

    /// Dispatch queue in which `getNewItems` and `pushNewItems` will be executed.
    var itemsQueue: DispatchQueue { get }

    func getNewItems(using credentials: Paginator.Credentials, completion: @escaping (Swift.Result<[ItemsList.Element], Error>) -> Void)
    func pushNewItems(_ inItems: [ItemsList.Element], range: Range<Int>?, completion: @escaping (Error?) -> Void)

    /// Notification listeners.
    var listener: PullsListener? { get }
}

public protocol PullsListener: AnyObject {
    func pullerDidStart<P: ListLoader>(_ puller: P)
    func pullerDidFinish<P: ListLoader>(_ puller: P, with result: Result<[P.ItemsList.Element], Error>)
}

public enum PullError: Error {
    case dataLimitReached
    case operationCancelled
    case opertationTimeOut
    case queueError
    case invalidCredentials
}

public extension ListLoader {
    var callBackQueue: DispatchQueue { .main }
}

private extension ListLoader {

    func onStart() {
        callBackQueue.sync { [weak self] in
            guard let this = self else { return }
            this.listener?.pullerDidStart(this)
        }
    }

    func onFinished(_ result: Result<[ItemsList.Element], Error>) {
        callBackQueue.sync { [weak self] in
            guard let this = self else { return }
            this.listener?.pullerDidFinish(this, with: result)
        }
    }

    func get(with creds: Paginator.Credentials) -> Result<[ItemsList.Element], Error> {
        let sem = DispatchSemaphore(value: 0)
        var buf: Result<[ItemsList.Element], Error>!
        itemsQueue.sync { [weak self] in
            guard let this = self else { return }
            this.getNewItems(using: creds) { result in
                buf = result
                sem.signal()
            }
        }
        let timeout = sem.wait(wallTimeout: .distantFuture)
        if timeout != .success {
            return Result.failure(PullError.opertationTimeOut)
        }
        return buf ?? Result.failure(PullError.queueError)
    }

    func push(_ arr: [ItemsList.Element], range: Range<Int>?) throws {
        let sem = DispatchSemaphore(value: 0)
        var error: Error?
        itemsQueue.sync { [weak self] in
            guard let this = self else { return }
            this.pushNewItems(arr, range: range) { (pushError) in
                error = pushError
                sem.signal()
            }
        }
        let timeout = sem.wait(wallTimeout: .distantFuture)
        if timeout != .success {
            throw PullError.opertationTimeOut
        }
        if let e = error { throw e }
    }
}

public extension ListLoader {

    typealias Item = ItemsList.Element

    var isBusy: Bool { !queue.operations.isEmpty }

    var isEmpty: Bool { items.isEmpty }

    func load(with creds: Paginator.Credentials, completion: ((Result<[ItemsList.Element], Error>) -> Void)? = nil) {
        let page = paginator.page(for: creds)
        let loadOperation = BlockOperation()
        // Load operation closure
        loadOperation.addExecutionBlock { [weak self, weak loadOperation] in
            do {
                var range: Range<Int>?
                guard let this = self, let lo = loadOperation else { throw PullError.operationCancelled }
                // Load a piece of list
                if creds.skip ?? 0 > 0 && this.paginator.dataLimitReached {
                    throw PullError.dataLimitReached
                }
                // Callback on load started
                this.onStart()
                // Load items
                let buf = this.get(with: creds)
                guard !lo.isCancelled else { throw PullError.operationCancelled }
                range = creds.range
                let arr = try buf.get()
                this.paginator.switch(to: page, inItemsCount: arr.count)
                // Add new items
                try this.push(arr, range: range)
                // Callback on finished
                this.onFinished(buf)
                // Completion
                this.callBackQueue.sync { completion?(.success(arr)) }
            } catch {
                self?.onFinished(.failure(error))
                self?.callBackQueue.sync { completion?(.failure(error)) }
            }
        }
        // Fire load operation
        queue.addOperation(loadOperation)
    }

    func load(page: Paginator.Page, completion: ((Result<[ItemsList.Element], Error>) -> Void)? = nil) {
        if page == .next, paginator.dataLimitReached {
            completion?(.failure(PullError.dataLimitReached))
        } else {
            load(with: paginator.credentials(for: page), completion: completion)
        }
    }
}
