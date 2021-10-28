import Foundation

public protocol ChunkLoadable {
    var chunkSize: Int { get }
}

public extension ChunkLoadable where Self: ListLoader {

    var chunkSize: Int {
        return paginator.pageSize ?? Int(Int16.max)
    }

    func loadChunks(for page: Paginator.Page, completion: ((Result<[ItemsList.Element], Error>) -> Void)? = nil) {
        let limit = chunkSize
        if page == .next && paginator.dataLimitReached {
            completion?(.failure(PullError.dataLimitReached))
            return
        }
        let creds = paginator.credentials(for: page)
        if creds.take ?? Int.max <= limit {
            load(page: page, completion: completion)
            return
        }
        let chunks = creds.chunks(limit: limit)
        DispatchQueue.global(qos: .default).async { [weak self] in
            do {
                guard let this = self else { throw PullError.operationCancelled }
                var result = [ItemsList.Element]()
                var errors = [Error]()
                let dg = DispatchGroup()
                for c in chunks {
                    dg.enter()
                    this.load(with: c) { (loaded) in
                        result.append(contentsOf: (try? loaded.get()) ?? [])
                        if let e = loaded.error { errors.append(e) }
                        dg.leave()
                    }
                }
                if dg.wait(timeout: .distantFuture) == .timedOut {
                    throw PullError.opertationTimeOut
                }
                DispatchQueue.main.sync {
                    completion?(Result {
                        if let e = errors.first { throw e }
                        return result
                    })
                }
            } catch {
                DispatchQueue.main.sync {
                    completion?(.failure(error))
                }
            }
        }
    }
}
