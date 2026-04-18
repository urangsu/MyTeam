import Foundation

open class Module {
    nonisolated public init() {}
}

final class PerceiverAttentionBlock: Module, @unchecked Sendable {
    var dim: Int
    nonisolated init(dim: Int = 100) {
        self.dim = dim
        super.init()
    }
}
