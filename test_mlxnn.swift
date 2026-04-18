import Foundation
import MLX
import MLXNN

final class MyModule: Module {
    var x: Int
    init(x: Int = 10) {
        self.x = x
        super.init()
    }
}
