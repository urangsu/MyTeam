import Foundation
import CryptoKit

enum StableContentHash {
    /// SHA256 hash of data, returned as hex string
    static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// SHA256 hash of text, returned as hex string
    static func sha256Hex(_ text: String) -> String {
        sha256Hex(data: Data(text.utf8))
    }
}
