import SwiftUI

// macOS 신호등 스타일 버튼 (공용 컴포넌트)
struct TrafficLightsView: View {
    var onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // 닫기 (빨강)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .onTapGesture { onClose() }
            
            // 최소화 (노랑)
            Circle()
                .fill(Color.yellow)
                .frame(width: 12, height: 12)
            
            // 최대화 (초록)
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
        }
    }
}
