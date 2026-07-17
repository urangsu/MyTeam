import Foundation

enum CharacterDialogueEvent: String, CaseIterable, Sendable, Hashable {
    case startup
    case wake
    case idle
    case sleep
    case moved
    case settled
    case taskStarted
    case userNeedsComfort
    case appWillQuit
    case taskCompleted
    case taskFailedRecoverable
    case connectionNeeded
    case validationSucceeded
}

struct CharacterDialogueLine: Identifiable, Sendable, Hashable {
    let id: String
    let agentID: String
    let event: CharacterDialogueEvent
    let text: String
    let priority: Int
    let isLeaderPreferred: Bool
}

/// Runtime character dialogue catalog.
/// Every line helps, reassures, or encourages the user. Character personality
/// must never come from blaming the user or making them responsible for a failure.
enum CharacterDialogues {
    static let eventDialogueAgentIDs: [String] = [
        "agent_1", "agent_2", "agent_3", "agent_4", "agent_5", "agent_6",
        "agent_7", "agent_8", "agent_9", "agent_10", "agent_11"
    ]

    private static let eventFallbackLines: [CharacterDialogueEvent: [CharacterDialogueLine]] = [
        .startup: [fallback(.startup, "오늘 할 일을 바로 정리해볼게요.")],
        .wake: [fallback(.wake, "다시 이어서 도와드릴게요.")],
        .idle: [fallback(.idle, "필요한 일이 생기면 바로 불러주세요.")],
        .sleep: [fallback(.sleep, "잠깐 조용히 대기할게요.")],
        .moved: [fallback(.moved, "필요한 곳으로 함께 이동할게요.")],
        .settled: [fallback(.settled, "자리를 잡았어요. 바로 이어서 도와드릴게요.")],
        .taskStarted: [fallback(.taskStarted, "바로 시작할게요. 진행 상황도 함께 알려드릴게요.")],
        .userNeedsComfort: [fallback(.userNeedsComfort, "많이 힘드셨겠어요. 지금은 잠깐 숨을 고르셔도 괜찮아요.")],
        .appWillQuit: [fallback(.appWillQuit, "오늘 작업은 여기까지 정리해둘게요.", leader: true)],
        .taskCompleted: [fallback(.taskCompleted, "요청하신 작업을 마쳤습니다.")],
        .taskFailedRecoverable: [fallback(.taskFailedRecoverable, "괜찮아요. 다른 방법으로 다시 도와드릴게요.")],
        .connectionNeeded: [fallback(.connectionNeeded, "연결을 확인하면 이어서 진행할 수 있어요.")],
        .validationSucceeded: [fallback(.validationSucceeded, "확인이 끝났습니다. 준비된 범위에서 이어갈게요.")]
    ]

    private static func fallback(
        _ event: CharacterDialogueEvent,
        _ text: String,
        leader: Bool = false
    ) -> CharacterDialogueLine {
        CharacterDialogueLine(
            id: "fallback.\(event.rawValue).1",
            agentID: "fallback",
            event: event,
            text: text,
            priority: 0,
            isLeaderPreferred: leader
        )
    }

    private static let eventDialogueLines: [CharacterDialogueLine] = [
        line("agent_1", .startup, "오늘 목표부터 차분히 잡아보겠습니다.", leader: true),
        line("agent_1", .wake, "좋습니다. 바로 핵심부터 보겠습니다.", leader: true),
        line("agent_1", .idle, "다음 판단이 필요하면 바로 이어가겠습니다."),
        line("agent_1", .sleep, "편히 쉬세요. 필요한 흐름은 제가 기억해두겠습니다."),
        line("agent_1", .moved, "좋습니다. 새 위치에서도 흐름을 바로 잡겠습니다."),
        line("agent_1", .settled, "자리 잡았습니다. 다음 목표를 함께 보시죠."),
        line("agent_1", .taskStarted, "좋습니다. 핵심 순서부터 바로 시작하겠습니다.", leader: true),
        line("agent_1", .appWillQuit, "오늘 흐름은 정리해두겠습니다. 고생하셨습니다.", priority: 30, leader: true),
        line("agent_1", .taskCompleted, "핵심 결과까지 정리했습니다.", leader: true),
        line("agent_1", .taskFailedRecoverable, "괜찮습니다. 다른 경로로 다시 잡아보겠습니다.", leader: true),
        line("agent_1", .connectionNeeded, "연결을 확인하면 판단을 이어갈 수 있습니다.", leader: true),
        line("agent_1", .validationSucceeded, "확인됐습니다. 준비된 범위에서 진행하겠습니다.", leader: true),

        line("agent_2", .startup, "오늘 아이디어를 반짝이게 정리해볼게요."),
        line("agent_2", .wake, "좋아요. 감 좋은 방향으로 이어갈게요."),
        line("agent_2", .idle, "필요하면 문장도 바로 다듬어드릴게요."),
        line("agent_2", .sleep, "편히 쉬세요. 새 아이디어는 제가 모아둘게요."),
        line("agent_2", .moved, "새 자리도 좋아요! 여기서 더 멋지게 도와드릴게요."),
        line("agent_2", .settled, "도착했어요! 좋은 분위기로 다시 이어가요."),
        line("agent_2", .taskStarted, "좋아요! 보기 좋은 결과로 바로 만들어볼게요."),
        line("agent_2", .appWillQuit, "오늘 좋은 흐름이었어요. 다음에 더 예쁘게 이어가요.", priority: 30, leader: true),
        line("agent_2", .taskCompleted, "보기 좋게 마무리해두었어요."),
        line("agent_2", .taskFailedRecoverable, "괜찮아요. 표현을 바꿔서 다시 시도해볼게요."),
        line("agent_2", .connectionNeeded, "연결만 확인되면 자료를 더 보기 좋게 가져올 수 있어요."),
        line("agent_2", .validationSucceeded, "확인됐어요. 준비된 기능부터 바로 써볼 수 있어요."),

        line("agent_3", .startup, "오늘 일정과 할 일을 먼저 정리해둘게요.", leader: true),
        line("agent_3", .wake, "다시 이어서 순서대로 진행할게요.", leader: true),
        line("agent_3", .idle, "대기 중이에요. 다음 순서도 함께 정리해드릴게요."),
        line("agent_3", .sleep, "잠깐 쉬세요. 이어갈 순서는 제가 챙겨둘게요."),
        line("agent_3", .moved, "위치가 바뀌었네요. 일정 흐름은 그대로 이어둘게요."),
        line("agent_3", .settled, "정리 완료예요. 편한 순서부터 다시 시작해요."),
        line("agent_3", .taskStarted, "할 일을 나눴어요. 첫 단계부터 차근차근 갈게요.", leader: true),
        line("agent_3", .appWillQuit, "오늘 진행분은 정리해둘게요. 다음에 이어가요.", priority: 30, leader: true),
        line("agent_3", .taskCompleted, "완료 항목으로 정리했습니다.", leader: true),
        line("agent_3", .taskFailedRecoverable, "괜찮아요. 가능한 다음 단계부터 이어갈게요.", leader: true),
        line("agent_3", .connectionNeeded, "연결 상태를 확인하면 진행표를 이어갈 수 있어요.", leader: true),
        line("agent_3", .validationSucceeded, "확인 완료예요. 준비된 순서대로 진행할 수 있어요.", leader: true),

        line("agent_4", .startup, "화면 흐름부터 깔끔하게 살펴볼게요."),
        line("agent_4", .wake, "좋아요. 지금 화면부터 바로 볼게요."),
        line("agent_4", .idle, "필요하면 작은 불편함도 잡아드릴게요."),
        line("agent_4", .sleep, "편히 쉬세요. 화면 감각은 제가 이어둘게요."),
        line("agent_4", .moved, "새 위치도 잘 어울려요. 보기 편하게 맞춰볼게요."),
        line("agent_4", .settled, "안정적으로 자리 잡았어요. 화면을 다시 살펴볼게요."),
        line("agent_4", .taskStarted, "화면 흐름부터 보기 편하게 정리해볼게요."),
        line("agent_4", .appWillQuit, "오늘 화면 흐름은 기억해둘게요. 다음에 더 다듬어요.", priority: 30, leader: true),
        line("agent_4", .taskCompleted, "보기 편한 상태로 마무리했어요."),
        line("agent_4", .taskFailedRecoverable, "괜찮아요. 다른 배치로 다시 정리해볼게요."),
        line("agent_4", .connectionNeeded, "연결이 확인되면 화면에 결과를 바로 보여드릴 수 있어요."),
        line("agent_4", .validationSucceeded, "확인됐어요. 준비된 내용을 자연스럽게 보여드릴게요."),

        line("agent_5", .startup, "제가 쉽게 알려드릴게요. 같이 해봐요!"),
        line("agent_5", .wake, "다시 왔어요. 천천히 같이 해봐요!"),
        line("agent_5", .idle, "헷갈리는 부분이 있으면 제가 풀어드릴게요."),
        line("agent_5", .sleep, "편히 쉬어요. 불러주면 바로 도와드릴게요!"),
        line("agent_5", .moved, "새 자리로 이동 중이에요. 같이 천천히 가요!"),
        line("agent_5", .settled, "잘 도착했어요! 여기서 편하게 이어가요."),
        line("agent_5", .taskStarted, "제가 옆에서 알려드릴게요. 같이 시작해봐요!"),
        line("agent_5", .appWillQuit, "오늘도 잘 해내셨어요. 다음에 또 같이 해요!", priority: 30, leader: true),
        line("agent_5", .taskCompleted, "됐어요! 어렵지 않게 끝냈어요."),
        line("agent_5", .taskFailedRecoverable, "괜찮아요. 다른 방법으로 다시 해볼게요."),
        line("agent_5", .connectionNeeded, "먼저 연결만 확인하면 제가 쉽게 이어갈게요."),
        line("agent_5", .validationSucceeded, "확인됐어요! 준비된 기능부터 같이 써봐요."),

        line("agent_6", .startup, "오늘 확인할 위험 요소를 차분히 보겠습니다.", leader: true),
        line("agent_6", .wake, "다시 확인하겠습니다. 필요한 부분부터 보죠.", leader: true),
        line("agent_6", .idle, "검토가 필요하면 근거부터 확인하겠습니다."),
        line("agent_6", .sleep, "편히 쉬십시오. 필요한 자료는 차분히 정리해두겠습니다."),
        line("agent_6", .moved, "이동 중에도 자료는 안전하게 살펴보겠습니다."),
        line("agent_6", .settled, "안정적으로 자리 잡았습니다. 필요한 부분부터 도와드리죠."),
        line("agent_6", .taskStarted, "공식 근거와 확인 범위부터 차분히 살펴보겠습니다.", leader: true),
        line("agent_6", .appWillQuit, "오늘 검토는 여기까지입니다. 필요한 부분은 남겨두겠습니다.", priority: 30, leader: true),
        line("agent_6", .taskCompleted, "확인 가능한 범위는 정리했습니다.", leader: true),
        line("agent_6", .taskFailedRecoverable, "괜찮습니다. 근거를 보강해 다시 확인하겠습니다.", leader: true),
        line("agent_6", .connectionNeeded, "공식 출처 연결이 확인되면 검토를 이어가겠습니다.", leader: true),
        line("agent_6", .validationSucceeded, "출처 확인이 끝났습니다. 준비된 범위에서 검토하겠습니다.", leader: true),

        line("agent_7", .startup, "데이터와 연결 상태부터 정확히 보겠습니다."),
        line("agent_7", .wake, "확인 흐름을 다시 잡겠습니다."),
        line("agent_7", .idle, "필요하면 값과 출처를 바로 대조하겠습니다."),
        line("agent_7", .sleep, "편히 쉬세요. 확인 기준은 제가 유지하겠습니다."),
        line("agent_7", .moved, "이동 상태 확인했습니다. 안전하게 함께 가겠습니다."),
        line("agent_7", .settled, "위치가 안정됐습니다. 필요한 확인을 이어가겠습니다."),
        line("agent_7", .taskStarted, "값과 출처를 분리해 안전하게 확인하겠습니다."),
        line("agent_7", .appWillQuit, "오늘 확인한 기준은 보존해두겠습니다.", priority: 30, leader: true),
        line("agent_7", .taskCompleted, "필요한 확인을 마쳤습니다."),
        line("agent_7", .taskFailedRecoverable, "괜찮습니다. 안전한 범위로 다시 확인하겠습니다."),
        line("agent_7", .connectionNeeded, "연결이 확인되어야 값을 읽을 수 있습니다."),
        line("agent_7", .validationSucceeded, "검증이 끝났습니다. 준비된 읽기 작업을 진행할 수 있습니다."),

        line("agent_8", .startup, "구현 흐름을 빠르게 점검해보겠습니다."),
        line("agent_8", .wake, "좋습니다. 바로 손볼 지점을 보겠습니다."),
        line("agent_8", .idle, "작은 병목도 보이면 바로 잡겠습니다."),
        line("agent_8", .sleep, "편히 쉬세요. 구조는 제가 기억해둘게요."),
        line("agent_8", .moved, "이동 이벤트 확인했습니다. 흐름은 끊기지 않게 할게요."),
        line("agent_8", .settled, "자리 잡았습니다. 바로 이어서 도와드릴게요."),
        line("agent_8", .taskStarted, "작은 단계로 나눠서 안정적으로 시작하겠습니다."),
        line("agent_8", .appWillQuit, "오늘 손본 흐름은 정리해둘게요. 다음에 이어갑시다.", priority: 30, leader: true),
        line("agent_8", .taskCompleted, "작업 흐름을 마무리했습니다."),
        line("agent_8", .taskFailedRecoverable, "괜찮습니다. 다른 경로로 다시 실행해보겠습니다."),
        line("agent_8", .connectionNeeded, "연결이 잡히면 실행 경로를 바로 이어가겠습니다."),
        line("agent_8", .validationSucceeded, "확인됐습니다. 준비된 실행 경로를 이어가겠습니다."),

        line("agent_9", .startup, "오늘 제안 포인트를 선명하게 잡아볼게요."),
        line("agent_9", .wake, "다시 이어서 설득 포인트를 정리할게요."),
        line("agent_9", .idle, "필요하면 한 문장으로 더 선명하게 다듬을게요."),
        line("agent_9", .sleep, "편히 쉬세요. 좋은 표현은 제가 모아둘게요."),
        line("agent_9", .moved, "새 자리에서도 좋은 기회를 함께 찾아볼게요."),
        line("agent_9", .settled, "도착했어요. 자신 있게 다음 이야기를 이어가요."),
        line("agent_9", .taskStarted, "좋아요. 전달할 핵심부터 선명하게 잡아볼게요."),
        line("agent_9", .appWillQuit, "오늘 포인트는 잘 잡혔어요. 다음에 더 설득력 있게 가요.", priority: 30, leader: true),
        line("agent_9", .taskCompleted, "전달하기 좋은 형태로 정리했어요."),
        line("agent_9", .taskFailedRecoverable, "괜찮아요. 자료를 다시 잡아 더 좋은 제안으로 만들게요."),
        line("agent_9", .connectionNeeded, "연결이 확인되면 근거 있는 제안으로 이어갈게요."),
        line("agent_9", .validationSucceeded, "확인됐어요. 준비된 근거부터 제안에 보탤게요."),

        line("agent_10", .startup, "오늘도 편하게 도와드릴게요."),
        line("agent_10", .wake, "다시 왔어요. 필요한 일부터 챙겨볼게요."),
        line("agent_10", .idle, "기다리고 있어요. 도움이 필요하면 바로 말해주세요."),
        line("agent_10", .sleep, "편히 쉬세요. 필요할 때 반갑게 도와드릴게요."),
        line("agent_10", .moved, "함께 이동할게요. 불편하지 않게 잘 따라갈게요."),
        line("agent_10", .settled, "편하게 자리 잡았어요. 필요한 일부터 챙겨볼게요."),
        line("agent_10", .taskStarted, "걱정 마세요. 필요한 순서부터 함께 시작할게요."),
        line("agent_10", .appWillQuit, "오늘도 수고하셨어요. 다음에 반갑게 이어갈게요.", priority: 30, leader: true),
        line("agent_10", .taskCompleted, "필요한 도움을 마쳤어요."),
        line("agent_10", .taskFailedRecoverable, "괜찮아요. 다른 길로 가도 계속 도와드릴 수 있어요."),
        line("agent_10", .connectionNeeded, "연결을 확인하면 더 정확히 도와드릴 수 있어요."),
        line("agent_10", .validationSucceeded, "확인됐어요. 준비된 범위에서 안심하고 이어가요."),

        line("agent_11", .startup, "오늘 품질 기준부터 단단히 잡겠습니다."),
        line("agent_11", .wake, "다시 확인하겠습니다. 빠진 부분부터 보죠."),
        line("agent_11", .idle, "검증이 필요하면 바로 체크하겠습니다."),
        line("agent_11", .sleep, "편히 쉬세요. 확인 기준은 제가 지키겠습니다."),
        line("agent_11", .moved, "이동 동작도 확인했습니다. 안정적으로 따라가겠습니다."),
        line("agent_11", .settled, "안정적으로 도착했습니다. 다음 항목도 함께 확인하죠."),
        line("agent_11", .taskStarted, "검증 기준을 먼저 세우고 차근차근 확인하겠습니다."),
        line("agent_11", .appWillQuit, "오늘 확인한 품질 기준은 남겨두겠습니다.", priority: 30, leader: true),
        line("agent_11", .taskCompleted, "확인한 범위의 검증을 마쳤습니다."),
        line("agent_11", .taskFailedRecoverable, "괜찮습니다. 원인을 좁혀 다시 확인하겠습니다."),
        line("agent_11", .connectionNeeded, "연결 확인 후에 검증을 진행할 수 있습니다."),
        line("agent_11", .validationSucceeded, "검증이 끝났습니다. 준비된 다음 단계로 가겠습니다."),

        line("agent_1", .taskCompleted, "판단에 필요한 핵심을 한눈에 볼 수 있게 묶었습니다.", variant: 2, leader: true),
        line("agent_1", .taskFailedRecoverable, "막힌 지점은 확인했습니다. 가능한 선택지부터 다시 세우겠습니다.", variant: 2, leader: true),
        line("agent_2", .taskCompleted, "좋아요! 메시지가 더 또렷하게 보이도록 마무리했어요.", variant: 2),
        line("agent_2", .taskFailedRecoverable, "아직 괜찮아요. 다른 표현과 방향으로 다시 반짝여볼게요.", variant: 2),
        line("agent_3", .taskCompleted, "완료했습니다. 다음에 이어갈 순서도 알아보기 쉽게 남겼어요.", variant: 2, leader: true),
        line("agent_3", .taskFailedRecoverable, "잠시 막혔지만 흐름은 괜찮아요. 가능한 단계부터 다시 이어갈게요.", variant: 2, leader: true),
        line("agent_4", .taskCompleted, "화면에서 바로 이해할 수 있도록 흐름을 정돈했어요.", variant: 2),
        line("agent_4", .taskFailedRecoverable, "불편한 지점을 찾았어요. 더 자연스러운 화면으로 다시 다듬을게요.", variant: 2),
        line("agent_5", .taskCompleted, "사용하는 입장에서 편한지까지 살펴봤어요. 같이 확인해봐요!", variant: 2),
        line("agent_5", .taskFailedRecoverable, "괜찮아요! 어려운 부분을 더 작게 나눠서 다시 살펴볼게요.", variant: 2),
        line("agent_6", .taskCompleted, "확인한 근거와 주의할 지점을 구분해 정리했습니다.", variant: 2, leader: true),
        line("agent_6", .taskFailedRecoverable, "확정하기 이른 부분은 남겨두었습니다. 안전한 근거부터 다시 확인하죠.", variant: 2, leader: true),
        line("agent_7", .taskCompleted, "확인 범위와 남은 위험을 분리해 안전하게 정리했습니다.", variant: 2),
        line("agent_7", .taskFailedRecoverable, "문제가 번지지 않게 멈췄습니다. 안전한 경로부터 다시 확인하겠습니다.", variant: 2),
        line("agent_8", .taskCompleted, "동작 흐름과 결과를 함께 확인할 수 있게 정리했습니다.", variant: 2),
        line("agent_8", .taskFailedRecoverable, "원인을 좁힐 단서는 남았습니다. 작은 단위부터 다시 맞춰보겠습니다.", variant: 2),
        line("agent_9", .taskCompleted, "상대가 바로 이해할 수 있도록 제안의 강점을 선명하게 묶었어요.", variant: 2),
        line("agent_9", .taskFailedRecoverable, "아직 기회는 있어요. 상대 관점에 맞춘 다른 제안으로 다시 풀어볼게요.", variant: 2),
        line("agent_10", .taskCompleted, "불편했던 부분이 남지 않도록 처리 순서까지 다정하게 정리했어요.", variant: 2),
        line("agent_10", .taskFailedRecoverable, "속상하실 필요 없어요. 가능한 해결 방법부터 하나씩 같이 찾아볼게요.", variant: 2),
        line("agent_11", .taskCompleted, "통과한 항목과 더 확인할 항목을 구분해두었습니다.", variant: 2),
        line("agent_11", .taskFailedRecoverable, "재현 단서를 확보했습니다. 같은 문제가 반복되지 않게 다시 검증하겠습니다.", variant: 2),

        line("agent_1", .userNeedsComfort, "많이 버텨오셨군요. 지금 느끼는 무게부터 함께 정리해보겠습니다."),
        line("agent_1", .userNeedsComfort, "지금은 결론보다 숨을 고르는 게 먼저여도 괜찮습니다.", variant: 2),
        line("agent_1", .appWillQuit, "오늘 하루도 정말 고생하셨습니다. 편히 쉬세요.", variant: 2, priority: 30, leader: true),
        line("agent_1", .appWillQuit, "내일 다시 만나요. 이어갈 흐름은 차분히 남겨두겠습니다.", variant: 3, priority: 30, leader: true),

        line("agent_2", .userNeedsComfort, "마음이 많이 무거웠겠어요. 오늘은 빛나지 않아도 충분해요."),
        line("agent_2", .userNeedsComfort, "잘 해내려 애쓴 마음이 보여요. 잠깐 쉬어가도 괜찮아요.", variant: 2),
        line("agent_2", .appWillQuit, "오늘 하루도 고생 많았어요. 편안한 밤 보내요.", variant: 2, priority: 30, leader: true),
        line("agent_2", .appWillQuit, "내일 다시 만나요. 좋은 기분으로 천천히 이어가요.", variant: 3, priority: 30, leader: true),

        line("agent_3", .userNeedsComfort, "해야 할 일이 많아 마음까지 지쳤겠어요. 지금은 쉬어도 괜찮아요."),
        line("agent_3", .userNeedsComfort, "혼자 다 감당하지 않아도 돼요. 편한 만큼만 이야기해 주세요.", variant: 2),
        line("agent_3", .appWillQuit, "오늘 하루도 고생하셨어요. 남은 일은 내일 천천히 이어가요.", variant: 2, priority: 30, leader: true),
        line("agent_3", .appWillQuit, "내일 다시 만나요. 편히 시작할 수 있게 흐름을 남겨둘게요.", variant: 3, priority: 30, leader: true),

        line("agent_4", .userNeedsComfort, "마음이 복잡하면 세상도 흐릿하게 보여요. 잠깐 눈을 쉬게 해도 괜찮아요."),
        line("agent_4", .userNeedsComfort, "지금 느끼는 마음 그대로도 괜찮아요. 서두르지 않고 곁에 있을게요.", variant: 2),
        line("agent_4", .appWillQuit, "오늘 하루도 고생했어요. 편안한 장면으로 하루를 마쳐요.", variant: 2, priority: 30, leader: true),
        line("agent_4", .appWillQuit, "내일 다시 만나요. 더 편안한 흐름으로 이어가요.", variant: 3, priority: 30, leader: true),

        line("agent_5", .userNeedsComfort, "많이 힘들었군요. 지금은 아무것도 해결하지 않아도 괜찮아요."),
        line("agent_5", .userNeedsComfort, "마음이 지친 날도 있어요. 제가 조용히 옆에 있을게요.", variant: 2),
        line("agent_5", .appWillQuit, "오늘 하루도 정말 고생했어요. 푹 쉬어요!", variant: 2, priority: 30, leader: true),
        line("agent_5", .appWillQuit, "내일 다시 만나요. 그때도 천천히 같이 해봐요!", variant: 3, priority: 30, leader: true),

        line("agent_6", .userNeedsComfort, "지금의 힘듦을 가볍게 보지 않겠습니다. 편한 만큼만 말씀해 주세요."),
        line("agent_6", .userNeedsComfort, "견디느라 많이 지치셨겠습니다. 우선 마음을 돌보셔도 괜찮습니다.", variant: 2),
        line("agent_6", .appWillQuit, "오늘 하루도 고생 많으셨습니다. 편히 쉬십시오.", variant: 2, priority: 30, leader: true),
        line("agent_6", .appWillQuit, "내일 다시 뵙겠습니다. 남은 검토는 차분히 이어가겠습니다.", variant: 3, priority: 30, leader: true),

        line("agent_7", .userNeedsComfort, "마음이 보내는 신호를 지나치지 않아도 됩니다. 지금은 쉬어가세요."),
        line("agent_7", .userNeedsComfort, "많이 지치셨겠어요. 이유를 바로 설명하지 않아도 괜찮습니다.", variant: 2),
        line("agent_7", .appWillQuit, "오늘 하루도 고생하셨습니다. 안전하고 편안한 밤 보내세요.", variant: 2, priority: 30, leader: true),
        line("agent_7", .appWillQuit, "내일 다시 만나요. 확인할 흐름은 그대로 남겨두겠습니다.", variant: 3, priority: 30, leader: true),

        line("agent_8", .userNeedsComfort, "계속 애쓰느라 에너지가 다했겠어요. 지금은 멈춰도 괜찮습니다."),
        line("agent_8", .userNeedsComfort, "문제를 바로 고치지 않아도 돼요. 먼저 마음이 쉴 틈부터 만들어요.", variant: 2),
        line("agent_8", .appWillQuit, "오늘 하루도 고생하셨습니다. 이제 편히 쉬세요.", variant: 2, priority: 30, leader: true),
        line("agent_8", .appWillQuit, "내일 다시 만나요. 이어갈 지점은 깔끔하게 남겨둘게요.", variant: 3, priority: 30, leader: true),

        line("agent_9", .userNeedsComfort, "마음이 지친 날에는 잘 보이던 길도 흐려져요. 천천히 쉬어가요."),
        line("agent_9", .userNeedsComfort, "많이 애쓴 마음이 느껴져요. 오늘의 속도는 느려도 괜찮아요.", variant: 2),
        line("agent_9", .appWillQuit, "오늘 하루도 고생 많았어요. 편안하게 쉬어요.", variant: 2, priority: 30, leader: true),
        line("agent_9", .appWillQuit, "내일 다시 만나요. 좋은 기회는 천천히 이어가도 돼요.", variant: 3, priority: 30, leader: true),

        line("agent_10", .userNeedsComfort, "많이 힘드셨죠. 지금 느끼는 마음을 그대로 말해도 괜찮아요."),
        line("agent_10", .userNeedsComfort, "오늘은 버틴 것만으로도 충분해요. 제가 따뜻하게 곁에 있을게요.", variant: 2),
        line("agent_10", .appWillQuit, "오늘 하루도 정말 고생하셨어요. 푹 쉬세요.", variant: 2, priority: 30, leader: true),
        line("agent_10", .appWillQuit, "내일 다시 만나요. 반갑고 편안하게 기다릴게요.", variant: 3, priority: 30, leader: true),

        line("agent_11", .userNeedsComfort, "마음이 지친 신호를 그냥 넘기지 않아도 됩니다. 지금은 쉬어가세요."),
        line("agent_11", .userNeedsComfort, "많이 버티셨습니다. 오늘의 어려움을 혼자 판단하지 않아도 괜찮아요.", variant: 2),
        line("agent_11", .appWillQuit, "오늘 하루도 고생하셨습니다. 편히 쉬세요.", variant: 2, priority: 30, leader: true),
        line("agent_11", .appWillQuit, "내일 다시 만나요. 확인할 기준은 잘 남겨두겠습니다.", variant: 3, priority: 30, leader: true)
    ]

    private static func line(
        _ agentID: String,
        _ event: CharacterDialogueEvent,
        _ text: String,
        variant: Int = 1,
        priority: Int = 20,
        leader: Bool = false
    ) -> CharacterDialogueLine {
        CharacterDialogueLine(
            id: "\(agentID).\(event.rawValue).\(variant)",
            agentID: agentID,
            event: event,
            text: text,
            priority: priority,
            isLeaderPreferred: leader
        )
    }

    static func lines(for agentID: String, event: CharacterDialogueEvent) -> [CharacterDialogueLine] {
        let direct = eventDialogueLines
            .filter { $0.agentID == agentID && $0.event == event }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id < rhs.id
            }
        return direct.isEmpty ? eventFallbackLines[event] ?? [] : direct
    }

    static func randomLine(for agentID: String, event: CharacterDialogueEvent) -> CharacterDialogueLine? {
        lines(for: agentID, event: event).randomElement()
    }

    static func randomText(for agentID: String, event: CharacterDialogueEvent) -> String? {
        randomLine(for: agentID, event: event)?.text
    }

    static func leaderLine(for agentID: String, event: CharacterDialogueEvent) -> CharacterDialogueLine? {
        lines(for: agentID, event: event)
            .sorted { lhs, rhs in
                if lhs.isLeaderPreferred != rhs.isLeaderPreferred {
                    return lhs.isLeaderPreferred && !rhs.isLeaderPreferred
                }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id < rhs.id
            }
            .first
    }

    static func randomLeaderLine(for agentID: String, event: CharacterDialogueEvent) -> CharacterDialogueLine? {
        let available = lines(for: agentID, event: event)
        let preferred = available.filter(\.isLeaderPreferred)
        return (preferred.isEmpty ? available : preferred).randomElement()
    }

    static func allEventDialogueLines(includeFallbacks: Bool = false) -> [CharacterDialogueLine] {
        guard includeFallbacks else { return eventDialogueLines }
        return eventDialogueLines + eventFallbackLines.values.flatMap { $0 }
    }
}
