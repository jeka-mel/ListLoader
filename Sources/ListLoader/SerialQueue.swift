import Foundation

public class SerialQueue: OperationQueue {

    override public var maxConcurrentOperationCount: Int {
        get { return 1 }
        set { }
    }

    public override init() {
        super.init()
        super.maxConcurrentOperationCount = 1
    }
}

public extension OperationQueue {

    static var serial: OperationQueue {
        return SerialQueue()
    }
}
