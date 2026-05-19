# Panel Chrome Policy

**Version:** Round 241C  
**Date:** 2026-05-20

---

## Rule

패널의 하단 컨트롤 영역은 패널 chrome의 일부다.  
별도 floating card나 detached rounded rectangle로 표시하면 안 된다.

---

## 구현 기준

| 항목 | 요구사항 |
|---|---|
| 통합 방식 | `safeAreaInset(edge: .bottom)` 또는 VStack 최하단 고정 |
| 배경 | 패널과 같은 material / bgColor 사용 |
| 구분선 | 상단에 `Divider()` 하나 |
| 높이 | 34 ~ 38pt |
| 수평 패딩 | 패널 horizontal padding과 동일 |
| 덮지 않음 | 입력창/콘텐츠를 가리면 안 됨 |

## 금지 패턴

```swift
// ❌ 별도 RoundedRectangle background
VStack { ... }
.background(RoundedRectangle(cornerRadius: 12).fill(...))
.padding(8)

// ✅ 패널 통합
.safeAreaInset(edge: .bottom, spacing: 0) {
    VStack(spacing: 0) {
        Divider()
        HStack { /* controls */ }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }
}
```

## 컨트롤 목록 (현재)

- 음소거 토글 (`speaker.slash.fill` / `speaker.wave.2.fill`)
- 음성 모드 토글 (`waveform`)
- 다크모드 토글 (`moon.stars.fill` / `sun.max.fill`)
- 설정 버튼 (`gearshape.fill`)

업무 시작 UI보다 footer가 더 튀어 보이면 안 된다.  
작게, 조용하게, 항상 아래에.
