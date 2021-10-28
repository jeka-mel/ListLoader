import Foundation

public struct Paginator {
    /// How many items will be loaded per call.
    /// If not set - pagination will be considered as disabled.
    public let pageSize: Int?
    /// Indicates if all possible paged data was already loaded.
    var dataLimitReached: Bool = false
    /// Total count of existing items.
    public private(set) var itemsCount: Int
    /// Number of the items which were loaded from remote source.
    /// Important: Value of this property should be updated manually in custom implementations.
    public internal(set) var loadedCount: Int = 0

    public struct Credentials {
        public var take: Int?
        public var skip: Int?
        public init() {}
    }

    public enum Page: Int {
        case first = 0, next, current, none
    }

    public init(pageSize: Int?, itemsCount: Int = 0) {
        self.pageSize = pageSize
        self.itemsCount = itemsCount
    }
}

public extension Paginator.Credentials {

    var range: Range<Int>? {
        guard let t = take, let s = skip else { return nil }
        return s ..< (t+s)
    }

    /// Converts long (e.g. more than 100 items) request to a sequence of short ones.
    /// - Parameter limit: Max number of items in chunk
    func chunks(limit: Int) -> [Paginator.Credentials] {
        guard var _take = take, limit > 0, _take > limit else { return [self] }
        var result = [Paginator.Credentials]()
        let count = _take / limit + (_take % limit > 0 ? 1 : 0)
        for i in 0 ..< count {
            var creds = Paginator.Credentials()
            var chunk = limit
            if _take >= limit {
                _take -= limit
            } else {
                chunk = _take
            }
            creds.take = chunk
            if i == 0 {
                creds.skip = skip
            } else if let buf = result.last {
                creds.skip = (buf.take ?? limit) + (buf.skip ?? 0)
            } else {
                break
            }
            creds.take = chunk
            result.append(creds)
        }
        return result
    }
}

extension Paginator.Credentials: CustomStringConvertible {
    public var description: String {
        var _skip: String {
            if let s = skip { return String(s) }
            return "null"
        }
        var _take: String {
            if let t = take { return String(t) }
            return "null"
        }
        return "Credentials(skip: \(_skip), take: \(_take)"
    }
}

fileprivate extension Paginator {

    var take: Int {
        return pageSize ?? Int.max / 10
    }

    func offset(for page: Page) -> Int {
        if page == .first { return 0 }
        var _currentPage = currentPage
        if loadedCount % take == 0 {
            return loadedCount
        } else {
            _currentPage += 1
        }
        return _currentPage * take
    }
}

public extension Paginator {

    var currentPage: Int {
        return loadedCount / take
    }

    var isPaginationEnabled: Bool { return pageSize != nil }

    var canLoadNextPage: Bool {
        guard let ps = pageSize, dataLimitReached == false else {
            return false
        }
        if itemsCount == 0 { return true }
        return loadedCount == 0 || ( loadedCount % ps ) == 0
    }

    var isEmpty: Bool {
        return itemsCount == 0
    }

    func credentials(for page: Page) -> Credentials {
        var creds = Credentials()
        guard let take = self.pageSize else {
            return creds
        }
        var skip = 0
        switch page {
        case .none:
            return creds
        case .first:
            creds.take = take
            creds.skip = skip
        case .next:
            skip = offset(for: page)
            if let _ = pageSize, loadedCount == 0 && itemsCount > 0 {
                skip = itemsCount
            }
            creds.take = take
            creds.skip = skip
        case .current:
            var mOffset = offset(for: page)
            if mOffset == 0 {
                mOffset = itemsCount
                if mOffset < take {
                    mOffset = take
                }
            }
            let mTake = mOffset == 0 ? take : mOffset
            creds.take = mTake
            creds.skip = skip
        }
        return creds
    }

    func page(for creds: Credentials) -> Paginator.Page {
        if let range = creds.range {
            if range.contains(0) {
                if range.count == itemsCount {
                    return .current
                } else {
                    return .first
                }
            } else {
                if range.contains(itemsCount) {
                    return .next
                } else {
                    return .current
                }
            }
        } else {
            return .none
        }
    }

    /// Toggle `loadedCount` and `dataLimitReached`
    mutating func `switch`(to page: Paginator.Page, inItemsCount: Int) {
        let existingItemsCount = self.itemsCount
        func checkDataLimit() {
            if let ps = self.pageSize, self.loadedCount > 0 && inItemsCount < ps {
                self.dataLimitReached = true
            }
        }
        switch page {
        case .first:
            if self.loadedCount <= inItemsCount {
                self.loadedCount = inItemsCount
                checkDataLimit()
            }
        case .next:
            self.loadedCount += inItemsCount
            checkDataLimit()
        case .current:
            if inItemsCount > existingItemsCount {
                self.loadedCount += inItemsCount - existingItemsCount
            } else if inItemsCount == existingItemsCount {
                self.loadedCount = existingItemsCount
            }
        case .none:
            self.loadedCount = inItemsCount
        }
    }
}
