import Foundation

struct PipelineContext: Equatable {
    private var bag = ExecutionContextBag()

    mutating func set(_ value: String, for key: String) {
        bag.set(value, for: key)
    }

    func get(_ key: String) -> String? {
        bag.get(key)
    }

    func mergedInput(for order: AgentWorkOrder) -> String {
        bag.mergedInput(for: order.pipelineInputKeys)
    }

    func asExecutionContextBag() -> ExecutionContextBag {
        bag
    }

    init() {}

    init(_ bag: ExecutionContextBag) {
        self.bag = bag
    }

    var values: [String: String] {
        bag.values
    }
}
