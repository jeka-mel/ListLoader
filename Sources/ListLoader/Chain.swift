import Foundation

public enum ChainRule {
    /// New pages will be loaded one by one until won't meet the number of existing items.
    /// - parameter limit: A max number of pages that can be loaded.
    case end(limit: Int?)
    /// New pages will be loaded one by one until newly loaded item(s) will not be equal to existing.
    case intersection
}

extension ListLoader where ItemsList.Element: Hashable {

    /// This method performs loading of "first" data page and then,
    /// page by page until meet existing data in the response on a limit.
    /// If there's no existing items, only "first" page will be loaded.
    public func chainedRefresh(with rule: ChainRule = .intersection,
                               from page: Paginator.Page = .first,
                               completion: ((Error?) -> Void)? = nil) {
        load(page: page) { [weak self] result in
            do {
                guard let this = self else { throw PullError.queueError }
                let inIntems = try result.get()
                let exItems = this.items
                if inIntems.isEmpty {
                    this.paginator.dataLimitReached = true
                    throw PullError.dataLimitReached
                }
                switch rule {
                case .end(let limit):
                    if this.paginator.currentPage < (limit ?? Int.max) - 1, this.paginator.loadedCount < this.items.count {
                        this.chainedRefresh(with: rule, from: .next, completion: completion)
                    } else {
                        completion?(nil)
                    }
                case .intersection:
                    let inSet = Set(inIntems)
                    let exSet = Set(exItems)
                    if inSet.intersection(exSet).isEmpty, !this.paginator.dataLimitReached {
                        this.chainedRefresh(with: rule, from: .next, completion: completion)
                    } else {
                        this.paginator.loadedCount = this.items.count
                        completion?(nil)
                    }
                }
            } catch {
                completion?(error)
            }
        }
    }
}
