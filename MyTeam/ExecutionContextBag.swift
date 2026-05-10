import Foundation

struct ExecutionContextBag: Equatable {
    private(set) var values: [String: String] = [:]

    var isEmpty: Bool {
        values.isEmpty
    }

    mutating func set(_ value: String, for key: String) {
        values[key] = value
    }

    func get(_ key: String) -> String? {
        values[key]
    }

    func mergedInput(for keys: [String]) -> String {
        keys
            .compactMap { key in
                guard let value = values[key], !value.isEmpty else { return nil }
                return "## \(key)\n\(value)"
            }
            .joined(separator: "\n\n")
    }
}

