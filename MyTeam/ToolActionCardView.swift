import SwiftUI

struct ToolActionCardView: View {
    let descriptor: MyTeamToolDescriptor
    let state: ToolExecutionState
    let query: Binding<String>?
    let onRun: ((MyTeamToolDescriptor, String) -> Void)?
    let onRequestApproval: ((MyTeamToolDescriptor, String, String) -> Void)?
    let onOpenWorkspace: (MyTeamToolDescriptor) -> Void
    let onOpenConnection: ((ExternalProvider?) -> Void)?
    let onOpenAssistantConnection: ((AssistantConnector.Provider?) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(descriptor.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        stateBadge
                    }

                    Text(descriptor.shortDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if supportsInlineRun, let query {
                TextField(defaultQuery, text: query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }

            HStack {
                if let provider = descriptor.requiredCredential?.provider {
                    Text(provider.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if case .needsAssistantConnection(let provider) = state {
                    Text(provider.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if case .needsConnection(let provider) = state {
                    Button("연결", action: { onOpenConnection?(provider) })
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if case .needsAssistantConnection = state {
                    Button("연결", action: {
                        if case .needsAssistantConnection(let provider) = state {
                            onOpenAssistantConnection?(provider)
                        } else {
                            onOpenAssistantConnection?(nil)
                        }
                    })
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if case .needsValidation(let provider) = state {
                    Button("검증", action: { onOpenConnection?(provider) })
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if case .needsApproval(let reason) = state {
                    Button("승인", action: {
                        onRequestApproval?(descriptor, query?.wrappedValue ?? "", reason)
                    })
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(onRequestApproval == nil)
                } else if case .running = state {
                    runningPill
                } else {
                    if state.isRunnable, supportsInlineRun, let query, let onRun {
                        Button(runtimeButtonTitle, action: { onRun(descriptor, query.wrappedValue) })
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(query.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else if state.isRunnable {
                        Button(buttonTitle, action: { onOpenWorkspace(descriptor) })
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Button(buttonTitle, action: { onOpenWorkspace(descriptor) })
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(true)
                    }
                }
            }
            .frame(minHeight: 28)

            Group {
                if case .running = state {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                } else {
                    Color.clear
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var stateBadge: some View {
        Text(state.displayLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private var runningPill: some View {
        HStack(spacing: 5) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.62)
                .frame(width: 14, height: 14)
            Text("작업 중")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.blue.opacity(0.12)))
    }

    private var buttonTitle: String {
        switch descriptor.category {
        case .briefing, .document, .spreadsheet, .externalInfo, .calendar, .mail:
            return "스킬"
        case .voice:
            return "음성"
        case .system:
            return "열기"
        }
    }

    private var supportsInlineRun: Bool {
        switch descriptor.id {
        case "dart.disclosures.search", "news.search", "weather.current", "law.search",
             "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement",
             "briefing.today", "document.meetingMinutes", "document.rewrite", "spreadsheet.postprocess",
             "spreadsheet.googleSheets.read", "calendar.events.today":
            return true
        default:
            return false
        }
    }

    private var runtimeButtonTitle: String {
        switch descriptor.id {
        case "dart.disclosures.search", "weather.current", "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement":
            return "조회"
        case "law.search", "news.search":
            return "검색"
        case "briefing.today":
            return "정리"
        case "document.meetingMinutes", "document.rewrite":
            return "초안"
        case "spreadsheet.postprocess":
            return "정리"
        case "spreadsheet.googleSheets.read":
            return "읽기"
        case "calendar.events.today":
            return "확인"
        default:
            return "실행"
        }
    }

    private var defaultQuery: String {
        switch descriptor.id {
        case "dart.disclosures.search":
            return "회사명, 종목코드, 또는 OpenDART 고유번호"
        case "news.search":
            return "검색할 뉴스 키워드"
        case "weather.current":
            return "지역명"
        case "finance.krx.stockPrice":
            return "회사명 또는 종목코드"
        case "finance.krx.index":
            return "코스피, 코스닥, KRX300"
        case "finance.company.statement":
            return "회사명 또는 종목코드와 사업연도"
        case "law.search":
            return "법령명 또는 확인할 쟁점"
        case "briefing.today":
            return "오늘 로컬 업무 브리핑"
        case "document.meetingMinutes":
            return "회의 내용을 붙여넣으세요."
        case "document.rewrite":
            return "다듬을 문장이나 문서를 붙여넣으세요."
        case "spreadsheet.postprocess":
            return "붙여넣은 표나 메모를 입력하세요."
        case "spreadsheet.googleSheets.read":
            return "Sheets URL 또는 ID Sheet1!A1:D20"
        case "calendar.events.today":
            return "오늘 일정"
        default:
            return ""
        }
    }

    private var tint: Color {
        switch state {
        case .idle, .succeeded:
            return .green
        case .needsConnection, .needsAssistantConnection, .needsValidation, .needsApproval:
            return .orange
        case .failed:
            return .red
        case .running, .checkingReadiness:
            return .blue
        case .unavailable:
            return .secondary
        }
    }

    private var iconName: String {
        switch descriptor.category {
        case .briefing: return "sun.max.fill"
        case .document: return "doc.text.fill"
        case .spreadsheet: return "tablecells.fill"
        case .externalInfo: return "newspaper.fill"
        case .calendar: return "calendar"
        case .mail: return "envelope.fill"
        case .voice: return "waveform"
        case .system: return "gearshape.fill"
        }
    }
}
