import SwiftUI

// macOS 신호등 스타일 버튼 (공용 컴포넌트)
struct TrafficLightsView: View {
    var onClose: () -> Void
    var onMinimize: (() -> Void)? = nil   // Round 273: 미구현 상태였던 노랑 버튼 액션 추가
    var onMaximize: (() -> Void)? = nil   // Round 273: 미구현 상태였던 초록 버튼 액션 추가

    var body: some View {
        HStack(spacing: 8) {
            // 닫기 (빨강)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .onTapGesture { onClose() }

            // 최소화 (노랑)
            Circle()
                .fill(onMinimize != nil ? Color.yellow : Color.yellow.opacity(0.4))
                .frame(width: 12, height: 12)
                .onTapGesture { onMinimize?() }

            // 최대화 (초록)
            Circle()
                .fill(onMaximize != nil ? Color.green : Color.green.opacity(0.4))
                .frame(width: 12, height: 12)
                .onTapGesture { onMaximize?() }
        }
    }
}
