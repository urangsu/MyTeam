import SwiftUI

// MARK: - WorkflowProgressIndicatorView
// Round 278 1-F: Claude/Gemini/ChatGPT 수준의 "동작 중" 인디케이터.
// 구성:
// 1. 좌측 펄스 dot — 에이전트 색상으로 발광 펄스
// 2. 점 3개 애니메이션 — 카톡 스타일 (TypingIndicatorView 기존 패턴 차용)
// 3. 상태 텍스트 — "팀장 작성 중: 회의록" 같은 한 줄 (TeamRuntimeStatusCopy)
//
// 타이머 정책: onDisappear에서 반드시 invalidate (ToolContractValidator 정책 준수).

struct WorkflowProgressIndicatorView: View {
    let statusText: String
    let accentColor: Color

    @State private var dotPhase: Int = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var dotTimer: Timer? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 좌측 펄스 dot
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
                .scaleEffect(pulseScale)
                .opacity(pulseScale == 1.0 ? 0.9 : 0.5)
                .shadow(color: accentColor.opacity(0.6), radius: pulseScale == 1.0 ? 4 : 1)

            // 상태 텍스트
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            // 점 3개 애니메이션
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentColor.opacity(dotPhase == i ? 1.0 : 0.3))
                        .frame(width: 4, height: 4)
                        .offset(y: dotPhase == i ? -2 : 0)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.10))
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }

    private func startAnimations() {
        // 점 단계 변경 (0.4초)
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
        // 펄스 (1.2초 사이클)
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseScale = 1.4
        }
    }

    private func stopAnimations() {
        dotTimer?.invalidate()
        dotTimer = nil
        pulseScale = 1.0
    }
}

// MARK: - WorkflowProgressBarView
// input bar 상단의 1px 무한 슬라이딩 바 (Gemini 스타일 indeterminate).

struct WorkflowProgressBarView: View {
    let accentColor: Color

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // 슬라이딩 하이라이트 — 좌→우 무한 이동
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(accentColor.opacity(0.10))
                    .frame(width: width, height: 1.5)
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(0.0),
                                accentColor.opacity(0.85),
                                accentColor.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.35, height: 1.5)
                    .offset(x: phase * (width + width * 0.35) - width * 0.35)
            }
        }
        .frame(height: 1.5)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
        .onDisappear {
            phase = 0
        }
    }
}

#if DEBUG
struct WorkflowProgressIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            WorkflowProgressIndicatorView(
                statusText: "팀장 작성 중: 회의록 초안",
                accentColor: .blue
            )
            WorkflowProgressIndicatorView(
                statusText: "다음 발언자를 정하고 있어요…",
                accentColor: .orange
            )
            WorkflowProgressBarView(accentColor: .blue)
                .padding(.horizontal)
        }
        .padding()
    }
}
#endif
