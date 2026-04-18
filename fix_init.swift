import Foundation

open class Module {
    nonisolated public init() {}
}

final class VoiceEncoder: Module, @unchecked Sendable {
    var x: Int

    nonisolated init(x: Int) {
        self.x = x
        super.init()
    }

    nonisolated override convenience init() {
        self.init(x: 10)
    }
}
