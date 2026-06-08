import Foundation

actor ToolExecutionRouter {
    static let shared = ToolExecutionRouter()

    func readiness(for descriptor: MyTeamToolDescriptor) async -> ToolExecutionState {
        guard FeatureGate.allows(descriptor) else {
            return .unavailable(distributionMessage(for: descriptor))
        }

        guard descriptor.isImplemented else {
            return .unavailable("이 기능은 준비 중입니다.")
        }

        if let requirement = descriptor.requiredCredential {
            let health = await MainActor.run {
                CredentialHealthService.shared.health(for: requirement.provider)
            }
            switch health.state {
            case .notConnected:
                return .needsConnection(requirement.provider)
            case .untested, .testUnavailable:
                return .needsValidation(requirement.provider)
            case .testFailed:
                return .failed(MyTeamToolFailure(
                    title: "연결 확인 실패",
                    message: "키 권한 또는 발급 상태를 확인하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "openConnection", title: "연결 설정", role: .normal)
                    ]
                ))
            case .connected:
                break
            }
        }

        let decision = ToolPermissionPolicy.decision(for: descriptor.permissionLevel)
        if decision.requiresApproval {
            return .needsApproval(decision.userFacingReason)
        }

        return .idle
    }

    func run(_ descriptor: MyTeamToolDescriptor) async -> ToolExecutionState {
        let state = await readiness(for: descriptor)
        guard state.isRunnable else { return state }

        return .failed(MyTeamToolFailure(
            title: "실행 연결 준비 중",
            message: "이 기능은 Tool Registry에 등록됐고, 실제 실행 연결은 다음 단계에서 붙입니다.",
            recoveryActions: [
                MyTeamNextAction(id: "openConnection", title: "필요한 연결 설정", role: .normal)
            ]
        ))
    }

    private func distributionMessage(for descriptor: MyTeamToolDescriptor) -> String {
        switch FeatureGate.current {
        case .appStore:
            return "\(descriptor.displayName)은 App Store 프로필에서 비활성입니다."
        case .direct:
            return "\(descriptor.displayName)은 Direct 프로필에서 사용할 수 없습니다."
        case .developer:
            return "\(descriptor.displayName)은 현재 개발자 프로필에서 사용할 수 없습니다."
        }
    }
}
