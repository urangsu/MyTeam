import SwiftUI

// MARK: - UseCaseSelectionView

/// 온보딩 Step 1: 어떤 용도로 써볼까요?
struct UseCaseSelectionView: View {
    @Binding var selectedUseCases: Set<OnboardingUseCase>
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            // 타이틀
            VStack(spacing: 8) {
                Text("어떤 용도로 써볼까요?")
                    .font(.system(size: 22, weight: .bold))
                Text("선택한 용도에 맞게 MyTeam을 준비할게요.\n여러 개 골라도 됩니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 선택 그리드
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(OnboardingUseCase.allCases, id: \.self) { useCase in
                    UseCaseChip(
                        useCase: useCase,
                        isSelected: selectedUseCases.contains(useCase)
                    ) {
                        if selectedUseCases.contains(useCase) {
                            selectedUseCases.remove(useCase)
                        } else {
                            selectedUseCases.insert(useCase)
                        }
                    }
                }
            }

            // 계속 버튼
            Button(action: onContinue) {
                Text(selectedUseCases.isEmpty ? "일단 시작" : "다음")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .cornerRadius(10)
        }
        .padding(24)
    }
}

// MARK: - OnboardingUseCase

enum OnboardingUseCase: String, CaseIterable, Hashable {
    case workOrganization = "업무 정리"
    case fileAndPDF       = "파일·PDF"
    case stockAndNews     = "주식·뉴스"
    case weatherAndMove   = "날씨·이동"
    case dailyAssistant   = "생활비서"

    var icon: String {
        switch self {
        case .workOrganization: return "doc.text.fill"
        case .fileAndPDF:       return "paperclip"
        case .stockAndNews:     return "chart.line.uptrend.xyaxis"
        case .weatherAndMove:   return "cloud.sun.fill"
        case .dailyAssistant:   return "house.fill"
        }
    }

    var description: String {
        switch self {
        case .workOrganization: return "회의록, 보고서, 체크리스트"
        case .fileAndPDF:       return "파일 요약, PDF 분석"
        case .stockAndNews:     return "공시, 시세, 뉴스 분석"
        case .weatherAndMove:   return "날씨 확인, 이동 계획"
        case .dailyAssistant:   return "일상 정리, 메모, 할 일"
        }
    }
}

// MARK: - UseCaseChip

private struct UseCaseChip: View {
    let useCase: OnboardingUseCase
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: useCase.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(useCase.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary)
                    Text(useCase.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.1)
                          : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
