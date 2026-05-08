import Foundation
import SwiftUI

struct TeamCollaborationStatus: Equatable {
    enum Kind {
        case idle
        case thinking
        case planning
        case gathering
        case writing
        case generatingArtifact
        case waitingForUser
        case completed
        case failed
    }

    let kind: Kind
    let title: String
    let detail: String
    let agentName: String?
    let timestamp: Date?

    var iconName: String {
        switch kind {
        case .idle: return "pause.circle.fill"
        case .thinking: return "brain.head.profile"
        case .planning: return "calendar.badge.clock"
        case .gathering: return "magnifyingglass.circle.fill"
        case .writing: return "pencil.and.outline"
        case .generatingArtifact: return "doc.badge.gearshape"
        case .waitingForUser: return "hourglass.bottomhalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch kind {
        case .idle: return .secondary
        case .thinking: return .purple
        case .planning: return .blue
        case .gathering: return .orange
        case .writing: return .teal
        case .generatingArtifact: return .pink
        case .waitingForUser: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }

    var isActive: Bool {
        kind != .idle
    }
}
