import Foundation

open class Module {
    public init() {}
}

final class MyModule: Module {
    var x: Int
    init(x: Int = 10) {
        self.x = x
        super.init()
    }
}
