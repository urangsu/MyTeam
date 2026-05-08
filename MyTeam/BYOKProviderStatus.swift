import Foundation

struct BYOKProviderStatus: Identifiable, Hashable {
    let id: String
    let displayName: String
    let providerKey: String
    let isConnected: Bool
    let storageLabel: String
    let helpText: String
}
