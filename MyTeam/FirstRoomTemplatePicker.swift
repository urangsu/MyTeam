import SwiftUI

// MARK: - FirstRoomTemplatePicker

/// 온보딩 Step 2: 시작할 방을 고르세요.
struct FirstRoomTemplatePicker: View {
    @Binding var selectedTemplate: RoomTemplate?
    var onStart: () -> Void
    var onConnectAPI: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("시작할 방을 고르세요")
                    .font(.system(size: 18, weight: .bold))
                Text("첫 방은 나중에 바꿀 수 있어요")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(RoomTemplate.allCases, id: \.self) { template in
                        RoomTemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template
                        ) {
                            selectedTemplate = template
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .background(WindowDragBlocker())
            .frame(minHeight: 150)

            Divider().opacity(0.12)

            VStack(spacing: 10) {
                Button(action: onStart) {
                    Text("이 방으로 시작")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(10)

                Button(action: onConnectAPI) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                        Text("AI / API 먼저 연결하기")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - RoomTemplate

enum RoomTemplate: String, CaseIterable, Hashable {
    case work   = "업무방"
    case life   = "생활방"
    case stock  = "주식방"

    var icon: String {
        switch self {
        case .work:   return "briefcase.fill"
        case .life:   return "house.fill"
        case .stock:  return "chart.bar.fill"
        }
    }

    var description: String {
        switch self {
        case .work:
            return "회의록, 보고서, 체크리스트, 파일 분석"
        case .life:
            return "날씨, 할 일, 생활 정보, 메모"
        case .stock:
            return "공시, 시세, 뉴스 분석, 투자 메모"
        }
    }

    var shortDescription: String {
        switch self {
        case .work:
            return "문서, 파일"
        case .life:
            return "메모, 일정"
        case .stock:
            return "공시, 시세"
        }
    }

    var accentColor: Color {
        switch self {
        case .work:  return .blue
        case .life:  return .green
        case .stock: return .orange
        }
    }

    static func recommended(for useCases: Set<OnboardingUseCase>) -> RoomTemplate {
        if useCases.contains(.stockAndNews) {
            return .stock
        }
        if useCases.contains(.dailyAssistant) || useCases.contains(.weatherAndMove) {
            return .life
        }
        return .work
    }
}

// MARK: - RoomTemplateCard

private struct RoomTemplateCard: View {
    let template: RoomTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.accentColor.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: template.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(template.accentColor)
                }

                // 텍스트
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(template.shortDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 선택 표시
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(template.accentColor)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? template.accentColor.opacity(0.07)
                          : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? template.accentColor.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
