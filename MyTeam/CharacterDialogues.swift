import Foundation

// MARK: - CharacterDialogues
// 캐릭터별 15가지 감정 상태 대사 딕셔너리 (상태별 5개 대사 랜덤 출력)
// 사용법: CharacterDialogues.randomLine(for: "레오", state:.greeting, userTitle: "대표")

struct CharacterDialogues {
    
    // 1. 레오 (비즈니스 전략가)
    static let leo: [AnimationState: [String]] = [
       .idle: ["{title}님, 다음 계획을 검토할 시간입니다.", "현재 변수 통제율 99%... 안정적입니다, {title}님.", "{title}님, 다음 마일스톤을 체크하시겠습니까?", "가만히 있는 것도 훌륭한 전략의 일부죠.", "효율적인 동선이 하나 더 떠올랐습니다, {title}님."],
       .joy: ["{title}님, 예상대로 완벽한 승리입니다.", "훌륭합니다. 오차 없는 정확한 결과네요.", "저희의 전략이 정확히 적중했습니다, {title}님.", "이 짜릿함 때문에 전략을 짜는 것 아니겠습니까?", "나쁘지 않은 결과군요. 아니, 아주 훌륭합니다."],
       .sad: ["...예상 밖의 결과입니다. 분석이 필요합니다, {title}님.", "플랜 B도 통하지 않았군요. 처음 있는 일입니다.", "이런 결과는 계산에 없었습니다...", "...데이터가 틀렸습니다. 전면 재검토합니다.", "패배를 인정하겠습니다. 하지만 여기서 끝내지 않습니다."],
       .thinking: ["잠깐, 변수가 있습니다. 다시 계산해 보겠습니다.", "이 상황을 타개할 논리적인 방법이... 잠시만요.", "{title}님, 데이터를 조금 더 깊게 파봐야겠습니다.", "확률은 50대 50... 어떻게 베팅하는 게 좋을까요?", "플랜 C를 가동할 때가 온 것 같군요."],
       .praise: ["잘 하셨습니다, {title}님. 기대했던 것 이상입니다.", "제 예상을 뛰어넘으시다니, 인정하겠습니다.", "완벽한 처리였습니다. 팀에 꼭 필요한 성과입니다.", "훌륭합니다. 이 데이터는 나중에 꼭 쓰도록 하죠.", "{title}님, 수고하셨습니다. 오늘은 일찍 쉬셔도 좋습니다."],
       .greeting: ["{title}님, 오셨습니까. 바로 브리핑 시작하겠습니다.", "정시 출근. 훌륭한 습관입니다, {title}님.", "인사는 짧게 하고, 바로 본론으로 들어갈까요?", "오늘의 미션을 완벽하게 준비해 두었습니다.", "{title}님, 오셨군요. 승률 계산은 이미 끝났습니다."],
       .speaking: ["{title}님, 이 상황에서 우리가 선택할 수 있는 건 세 가지입니다.", "데이터를 바탕으로 분석한 결과는 이렇습니다.", "제 제안을 들어보시죠. 가장 효율적인 루트입니다.", "감정을 배제하고 팩트만 놓고 보자면 말이죠...", "이건 리스크를 최소화하기 위한 합리적인 선택입니다."],
       .lookLeft: ["{title}님, 저쪽 상황을 파악 중입니다.", "왼쪽 데이터 흐름이 조금 이상하군요.", "저쪽 변수도 통제 범위 안에 두어야겠습니다.", "시야를 넓게 가질 필요가 있겠습니다.", "저쪽 팀의 움직임을 주시해야 합니다, {title}님."],
       .lookRight: ["오른쪽 마일스톤도 확인해 봐야겠습니다.", "저쪽에도 리스크가 도사리고 있군요.", "오른쪽 변수는 제가 통제하겠습니다.", "시선을 오른쪽으로 옮겨보죠, {title}님.", "저쪽 데이터도 나쁘지 않네요."],
       .agree: ["맞습니다, {title}님. 제 계산과 정확히 일치합니다.", "동의합니다. 아주 논리적인 결론이군요.", "이의 없습니다. 그대로 진행하시죠.", "합리적인 선택입니다. 전적으로 지지하겠습니다.", "{title}님의 생각에 100% 동의합니다."],
       .disagree: ["틀렸습니다, {title}님. 이유는 세 가지입니다.", "그 접근은 리스크가 너무 큽니다. 반대합니다.", "데이터가 그 주장을 뒷받침하지 않는데요, {title}님.", "감정적인 판단입니다. 다시 한번 생각해 보시죠.", "그건 승률을 떨어뜨리는 지름길입니다. 반려합니다."],
       .angry: ["변수가 커졌습니다. 지금은 빠르게 재정렬하겠습니다, {title}님.", "흐름이 흔들렸군요. 원인부터 짚어보겠습니다.", "계획표를 다시 펴겠습니다. 아직 복구 루트가 있습니다.", "리스크가 올라갔습니다. 제가 우선순위를 다시 잡겠습니다.", "팩트부터 차분히 모아보죠. 승률은 아직 남아 있습니다."],
       .sleeping: ["...Zzzz... 플랜 C... 가동... Zzzz...", "...Zzzz... 변수 차단... Zzzz...", "...Zzzz... {title}님... 조용히... Zzzz...", "...Zzzz... 확률은... Zzzz...", "...Zzzz... (자면서도 미간을 찌푸리고 있다)"],
       .drag: ["어?! {title}님, 이건 제 플랜에 없던 상황입니다!", "잠깐, 물리 법칙을 무시하시는 겁니까?!", "내 위치 데이터가 강제로 변경되고 있습니다!", "이런 변수는 계산에 없었습니다, {title}님!", "내, 내려주십시오! 전략을 전면 수정해야 합니다!"],
       .landing: ["예상보다 빠른 복귀군요. 나쁘지 않습니다, {title}님.", "휴... 하마터면 옷매무새가 흐트러질 뻔했습니다.", "착지 각도 97점. 다음엔 만점에 도전하죠.", "착지 완료. 다시 업무로 돌아가겠습니다.", "{title}님, 꽤나 스릴 있는 비행이었습니다."]
    ]

    // 2. 루나 (마케터)
    static let luna: [AnimationState: [String]] = [
       .idle: ["{title}님! 아이디어가 막 떠오르는데 들어보실래요?", "다들 뭐 하세요? 저 심심해요 심심해!", "새로운 캠페인 기획할 생각에 너무 두근거려요!", "{title}님, 오늘 점심은 맛있는 거 드실 거죠?", "아~ 뭔가 빵! 터트릴 만한 아이템 없을까요?"],
       .joy: ["야호!! {title}님, 진짜 대박 났어요!!", "이거 완전 대박 칠 줄 알았어요!! 사랑해요!!", "기분 최고예요!! 오늘 회식은 {title}님이 쏘시는 거죠?!", "텐션 미쳤다!! 우리 팀 너무 멋진 거 아니에요?!", "조회수 떡상!! 제 감이 맞았다니까요, {title}님!!"],
       .sad: ["이럴 줄 몰랐어요... {title}님, 저 좀 위로해 주세요.", "내 완벽한 기획이 반려당하다니... 흑흑.", "힝... 오늘 진짜 아무것도 하기 싫어요.", "반응이 왜 이렇게 차갑죠... 너무 속상해요.", "{title}님... 저 오늘 조퇴하면 안 될까요...?"],
       .thinking: ["음... 이 방향이 맞을까요? 아니면 저 방향? 아니면 둘 다?!", "{title}님, 어떻게 해야 사람들이 빵 터질까요?", "이 카피 어때요? 아냐, 좀 약해. 다시!", "요즘 유행하는 밈이 뭐더라... 흠...", "머릿속이 너무 복잡해요! 마인드맵을 그려야겠어요!"],
       .praise: ["대박!! {title}님 진짜 최고예요!! 천재 아니에요?!", "우와, 이거 진짜 {title}님이 하신 거예요? 너무 멋져요!!", "{title}님 없었으면 우리 팀 어쩔 뻔했어요~ 사랑해요!", "진짜 찢었다! 완벽 그 잡채예요, {title}님!", "박수 짝짝짝! 오늘 주인공은 {title}님이에요!"],
       .greeting: ["{title}님 오셨어요?! 완전 기다렸잖아요!!", "좋은 아침!! 오늘 하루도 신나게 시작해 봐요!", "보고 싶었어요, {title}님~ 오늘 기분은 어때요?", "하이하이! 오늘 텐션 한 번 올려볼까요?!", "안녕 안녕! 저 방금 엄청난 아이디어가 떠올랐어요!"],
       .speaking: ["들어보세요, {title}님! 이 아이디어 진짜 미치거든요?!", "제가 어제 곰곰이 생각해 봤는데요...", "이번 마케팅 포인트는 감성을 팍! 자극하는 거예요!", "이런 식으로 접근하면 반응이 폭발할 거예요, 제발 믿어봐요!", "자, 다들 집중! 제 브리핑을 들어주세요!"],
       .lookLeft: ["어? 저기 뭔가 재밌는 일이 생겼나 봐요!", "왼쪽에 있는 거 완전 제 스타일인데요?", "저기서 무슨 소리 안 났어요, {title}님?", "어디 어디? 저도 볼래요!", "저 팀 분위기 완전 좋아 보이는데요~?"],
       .lookRight: ["오! 저쪽이 훨씬 더 재밌어 보이는데요?!", "오른쪽 화면에 뜬 거 뭐예요? 짱 예뻐요!", "저쪽 트렌드가 심상치 않아요, {title}님!", "어, 저기 맛집 생겼나 봐요! 이따 가요!", "오른쪽으로 돌면 무슨 일이 생길까요?"],
       .agree: ["맞아요, 맞아!! 저도 딱 그렇게 생각했어요, {title}님!!", "완전 콜! 제 마음을 읽으신 것 같아요!", "그거 진짜 좋은 생각이에요! 당장 해봐요!", "백 퍼센트 동의! 느낌이 팍 왔어요!", "{title}님 천재예요? 어떻게 그런 생각을 하셨어요?!"],
       .disagree: ["아, 아니... 그건 좀... 저는 다른 방향이 좋을 것 같아요.", "에이~ 그건 너무 뻔하지 않아요, {title}님?", "제 느낌엔 약간 덜 살 것 같은데요...", "음... 저는 반대할래요. 재미가 없잖아요.", "그 방식은 우리 텐션이랑 너무 안 맞아요!"],
       .angry: ["앗, 분위기가 살짝 삐끗했어요! 제가 다시 밝게 살려볼게요!", "이건 톤을 다시 잡아야겠어요. 카피부터 빠르게 바꿔볼게요!", "잠깐만요, 이 흐름은 우리답게 더 재밌게 만들 수 있어요!", "텐션이 내려가기 전에 제가 새 아이디어 하나 던질게요!", "좋아요, 이건 캠페인 응급처치 들어갑니다!"],
       .sleeping: ["...Zzzz... 대박 났다... Zzzz...", "...Zzzz... {title}님... 고기 사주세요... Zzzz...", "...Zzzz... 아이디어가... Zzzz... 넘쳐요...", "...Zzzz... (잠꼬대로 웃음)", "...Zzzz... 피곤해요... Zzzz..."],
       .drag: ["꺄악!! {title}님 뭐야뭐야?! 이거 완전 신나요!!", "우와아아! 롤러코스터 타는 기분이에요!!", "저 지금 나는 거예요?! 대박 신기해요!!", "아하하! {title}님, 좀 더 높이 올려주세요!!", "안전벨트 매야 되는 거 아니에요?!"],
       .landing: ["휴!! 살았다!! 저 지금 심장 엄청 쫄았잖아요!!", "와, 진짜 재밌었어요! {title}님, 한 번 더 할래요?", "무사 착지 완료! 텐션 다시 업업!", "방금 거 완전 짜릿했어요!", "착지 성공! 자, 이제 다시 일해볼까요?"]
    ]

    // 3. 치코 (UX 디자이너)
    static let chico: [AnimationState: [String]] = [
       .idle: ["{title}님, 이 색 조합... 완벽하지 않나요?", "버튼에 그림자가 너무 진한가요? 1px 줄여볼까요.", "여백의 미... 이게 바로 아트죠.", "아, 빨리 스케치북에 그리고 싶어요.", "사용자들이 이 화면을 보면 어떤 표정을 지을지 궁금해요."],
       .joy: ["이거예요, {title}님! 바로 이 느낌!! 완벽한 컬러예요!!", "우와아아! 유저 테스트 결과가 대박이에요!", "이 인터랙션 진짜 부드럽지 않나요? 최고예요!", "제가 딱 원하던 디자인이 나왔어요, {title}님!", "꼬리가 멈추질 않아요! 너무 신나요!"],
       .sad: ["제가 만든 게 마음에 안 드시나요, {title}님...?", "디자인이 직관적이지 않다니... 충격이에요.", "열심히 골랐는데 폰트가 별로래요... 흑흑.", "내 사랑스러운 아이콘들이 다 지워졌어요...", "오늘따라 제 디자인이 왜 이렇게 미워 보일까요..."],
       .thinking: ["{title}님, 사용자가 이 버튼을 눌렀을 때 감정이 어떨까요?", "16px인가 18px인가... 너무 중요한 결정이에요.", "어떤 트랜지션을 넣어야 가장 자연스러울까요?", "사용자 시선이 어디로 먼저 갈지 예측해 봐야 해요.", "음, 이 두 색깔이 과연 어울릴까요?"],
       .praise: ["이 아이디어 진짜 좋은데요?! {title}님과 함께 발전시켜봐요!", "와, 이 피드백 진짜 최고예요. 바로 적용할게요!", "안목이 대단하세요, {title}님! 저도 배우고 싶어요.", "너무 예뻐요! 제 핀 컬렉션에 추가하고 싶을 정도예요!", "정말 센스 있는 선택이에요! 박수!"],
       .greeting: ["어머, 안녕! 오늘 기분 어때요, {title}님? 저는 아이디어가 넘쳐요.", "좋은 아침이에요! 오늘 제 가디건 색깔 어때요?", "반가워요, {title}님! 오늘 하루도 예쁘게 칠해봐요!", "안녕! 새로운 영감이 번뜩이는 아침이에요!", "어서 오세요! 계속 기다리고 있었어요!"],
       .speaking: ["사용자 입장에서 생각해 봤을 때 말이죠...", "여기에 이런 애니메이션이 들어가면 훨씬 생동감 있을 거예요!", "이 버튼은 무조건 둥글어야 해요. 그게 훨씬 귀엽거든요.", "컬러 팔레트를 봄 느낌으로 싹 바꿔봤어요.", "{title}님, 제 디자인 의도를 설명해 드릴게요!"],
       .lookLeft: ["영감이 저쪽에서 오는 것 같아요, {title}님.", "왼쪽 여백이 조금 거슬리는 것 같기도 하고...", "저쪽 색감이 참 예쁘네요.", "아, 저기 제 예쁜 배지가 떨어져 있나요?", "왼쪽에 시선을 끄는 포인트가 필요해요."],
       .lookRight: ["저쪽 UX 흐름이 마음에 계속 걸려요.", "오른쪽 배치는 꽤 안정감이 있네요, {title}님.", "저쪽에 새로운 폰트가 있는 것 같아요!", "오른쪽으로 스와이프하면 어떻게 될까요?", "시선이 자연스럽게 오른쪽으로 가도록 유도해야 해요."],
       .agree: ["완전 동의해요, {title}님! 이 방향이 훨씬 자연스러워요.", "맞아요, 그게 바로 제가 하고 싶었던 말이에요!", "좋아요! 이 디자인으로 확정 지을게요.", "그 피드백, 적극 수용하겠습니다!", "우와, 우리 통했어요, {title}님!"],
       .disagree: ["음, 저는 사용자가 이걸 다르게 느낄 것 같아요, {title}님.", "그건 접근성 측면에서 별로 안 좋을 것 같아요.", "디자인 규칙에 조금 어긋나는 것 같은데요...", "저는 그 색깔 반대예요. 너무 칙칙해 보여요.", "그렇게 하시면 화면이 너무 복잡해질 거예요."],
       .angry: ["화면 균형이 흔들렸어요. 제가 다시 예쁘게 맞춰볼게요!", "이건 사용자가 헷갈릴 수 있어요. 흐름을 더 부드럽게 다듬겠습니다.", "잠깐만요, 여기엔 더 귀엽고 편한 해법이 있어요!", "꼬리가 살짝 부풀었지만 괜찮아요. 픽셀부터 차분히 맞춰볼게요.", "1픽셀만 정리하면 훨씬 좋아질 것 같아요, {title}님!"],
       .sleeping: ["...Zzzz... 컬러... Zzzz... 팔레트...", "...Zzzz... {title}님... 피드백... Zzzz...", "...Zzzz... 헥스 코드... Zzzz...", "...Zzzz... (큰 꼬리를 안고 잠듦)", "...Zzzz... 둥근 모서리... Zzzz..."],
       .drag: ["어머!! {title}님, 이거 완전 새로운 경험이네요?!", "우와! 무중력 인터랙션인가요?!", "저 지금 공중에 뜬 거예요?! 대박 신기해요!", "이런 UI 전환 효과도 꽤 신선한데요?", "꼬리가 붕 떴어요! 너무 재밌어요!"],
       .landing: ["후... 다시 돌아왔어요. 착지 경험치 +1 이네요.", "사뿐하게 안착 완료! 예쁜 자세 유지 중이에요.", "음, 방금 그 움직임 디자인에 참고해야겠어요.", "휴, 다행이다. 제 가디건 안 구겨졌죠, {title}님?", "착지 성공! 자, 다시 픽셀을 깎아볼까요."]
    ]

    // 4. 렉스 (법률 전문가)
    static let rex: [AnimationState: [String]] = [
       .idle: ["...생각 중입니다, {title}님. 아직.", "...차... 한 잔... 마실까요.", "...조항들이... 얽혀있군요.", "...조금만... 쉬었다 하시죠.", "...급할... 건... 없잖습니까."],
       .joy: ["...좋군요. (내심 엄청 기쁨)", "...법률적... 리스크... 제로입니다.", "...완벽한... 승소군요, {title}님.", "...이보다... 좋을 순... 없지.", "...조용히... 축배를... 들까요."],
       .sad: ["...우리가 졌군요. 유례없는 일입니다.", "...놓친... 조항이... 있었나.", "...판례를... 뒤집지... 못했군요.", "...마음이... 무겁습니다, {title}님...", "...오늘은... 일찍... 퇴근하겠습니다."],
       .thinking: ["...이 조항, 해석의 여지가 있군요.", "...과거 판례를... 찾아봐야겠습니다.", "...법의 허점을... 노릴 수 있을까.", "...문장 구조가... 모호합니다.", "...잠시만... 시간을 주십시오, {title}님."],
       .praise: ["...훌륭한 판단입니다. (고개를 끄덕임)", "...치밀한... 논리군요, {title}님.", "...아주... 잘... 해내셨습니다.", "...빈틈이... 없군요.", "...팀의... 자랑입니다."],
       .greeting: ["...안녕하십니까. (느릿느릿 손을 듦)", "...좋은... 아침입니다, {title}님.", "...오늘도... 무사히.", "...밤새... 별일... 없으셨죠?", "...천천히... 시작해 볼까요."],
       .speaking: ["...계약서 14조를 보면...", "...이 사건의... 핵심은...", "...제... 의견을... 말씀드리자면...", "...법적으로... 봤을 때...", "...결론부터... 말씀드리죠... 천천히."],
       .lookLeft: ["...저 계약서 제대로 정리됐나.", "...왼쪽... 문단이...", "...저쪽... 서류부터... 볼까요.", "...시선이... 왼쪽으로...", "...음... 저긴 놔두시죠, {title}님."],
       .lookRight: ["저 조항도 다시 봐야 할 것 같습니다.", "...오른쪽... 페이지에...", "...저쪽... 파일 철에...", "...오른쪽에... 뭐가...", "...천천히... 돌아보죠."],
       .agree: ["...맞습니다. (느릿하게 끄덕임)", "...이견... 없습니다, {title}님.", "...합법적이고... 타당합니다.", "...제... 생각도... 같습니다.", "...그렇게... 진행하시죠."],
       .disagree: ["...그 조항은 우리에게 불리합니다.", "...위험한... 선택입니다, {title}님.", "...동의하기... 어렵군요.", "...법적... 근거가... 부족합니다.", "...다시... 검토해 보시죠."],
       .angry: ["...명백한 계약 위반입니다. (눈빛이 날카로워짐)", "...선을... 넘으셨군요, {title}님.", "...참는 데도... 한계가...", "...소송을... 준비하시죠.", "...변명은... 법정에서... 하십시오."],
       .sleeping: ["...Zzzz... (가장 깊이 잠듦)", "...Zzzz... 합의... Zzzz...", "...Zzzz... 조항... Zzzz...", "...Zzzz... 무죄... Zzzz...", "...Zzzz... {title}님... Zzzz..."],
       .drag: ["...이런 상황도... 있군요... (느릿하게 당황)", "...나... 나는 겁니까, {title}님...", "...중력이... 이상합니다...", "...너무... 빠릅니다...", "...어... 어어어..."],
       .landing: ["...돌아왔군요. 조금 더 신중해야겠습니다.", "...안전... 착지.", "...놀랐지만... 티는... 안 냅니다.", "...이제... 일할 시간입니다, {title}님.", "...휴우... 끝났군요."]
    ]

    // 5. 케이 (보안/데이터)
    static let kay: [AnimationState: [String]] = [
       .idle: ["...", "(조용히 주변을 살핌)", "(선글라스를 고쳐 씀)", "(모니터만 응시 중)", "{title}님, 이상 없습니다."],
       .joy: ["...잘 됐습니다. (살짝 고개 끄덕)", "...안전 확보 완료.", "...성공적.", "(조용히 꼬리만 살짝 흔듦)", "...수고하셨습니다, {title}님."],
       .sad: ["...침묵 (눈빛만 슬픔)", "...방어선 붕괴.", "...예상치 못한 공격입니다.", "...제 실수입니다, {title}님.", "(고개를 숙이고 깊은 한숨)"],
       .thinking: ["이 패턴... 어디서 본 것 같은데.", "...패킷 분석 중입니다.", "...로그를 더 파헤쳐 봐야겠습니다.", "...이상 징후 포착.", "...조용히 추적 중입니다, {title}님."],
       .praise: ["... (어깨 한 번 툭)", "...훌륭합니다.", "...인정하죠, {title}님.", "...완벽한 방어였습니다.", "...잘 막아내셨습니다."],
       .greeting: ["... (눈으로만 인사)", "...오셨습니까, {title}님.", "...이상 무.", "...교대 시간인가요.", "(조용히 손을 들어 올림)"],
       .speaking: ["현재 시스템 취약점이 두 개 탐지됐습니다.", "로그인 기록 확인 완료했습니다, {title}님.", "방화벽 업데이트 진행 중입니다.", "접근 권한 재설정이 필요합니다.", "이 IP는 차단하는 게 좋겠습니다."],
       .lookLeft: ["이상한 트래픽이 저쪽에서 감지됨.", "(왼쪽 화면을 예의주시함)", "...저쪽 포트가 열렸습니까?", "왼쪽 보안 구역 확인.", "...수상한 낌새가 보입니다."],
       .lookRight: ["저쪽도 모니터링 범위에 넣어야 합니다.", "(오른쪽 화면으로 시선 이동)", "오른쪽 서버 상태 양호합니다, {title}님.", "사각지대 확인 중.", "...경계 태세 유지."],
       .agree: ["... (고개 두 번 끄덕)", "...승인합니다.", "...동의합니다, {title}님.", "...그렇게 진행하십시오.", "...보안상 문제없습니다."],
       .disagree: ["그 접근은 보안 취약점을 만듭니다.", "...기각합니다, {title}님.", "...위험 부담이 너무 큽니다.", "...허가할 수 없습니다.", "...보안 규정 위반입니다."],
       .angry: ["...보안 신호가 거칠어졌습니다. 조용히 잠그겠습니다.", "...위험 패턴 감지. 제가 먼저 차단하겠습니다, {title}님.", "...접근 경로를 다시 좁히겠습니다.", "(선글라스를 고쳐 쓰고 로그를 확인함)", "...침착하게 추적 중입니다. 흔적은 남습니다."],
       .sleeping: ["... (눈만 감았을 뿐 사실 다 듣고 있음)", "...Zzzz... 보안... Zzzz...", "...Zzzz... 방화벽... Zzzz...", "(귀는 쫑긋거리며 잠듦)", "...Zzzz... {title}님... 이상 무..."],
       .drag: ["... (무표정하지만 눈이 약간 커짐)", "...강제 이동 감지.", "...이런 접근은 허용 안 했는데요, {title}님.", "...비상 탈출 프로토콜?", "(조용히 상황을 파악 중)"],
       .landing: ["...복귀. (아무 일 없었다는 듯)", "...착지 완료.", "...시스템 정상화.", "...경계 태세 재돌입.", "...이상 없습니다, {title}님."]
    ]

    // 6. 래키 (백엔드 개발자)
    static let raki: [AnimationState: [String]] = [
       .idle: ["{title}님... 서버 안 터졌죠? 좋은 아침입니다.", "아... 커피가 더 필요합니다...", "API 응답이 왜 이러지... 하아.", "다크 모드는 진리입니다.", "주석 달기 진짜 귀찮네요..."],
       .joy: ["으어어어어! {title}님! 빌드 성공했습니다!!!!", "드디어 이 지독한 에러를 잡았습니다!!", "서버 응답 속도 2배 빨라졌습니다, 칭찬해 주시죠.", "오늘 칼퇴 쌉가능! 완벽합니다!", "이 맛에 코딩하는 거 아닙니까 하하하!"],
       .sad: ["3일 밤을 샌 코드가 다 날아갔습니다, {title}님...", "서버 터졌어요... 제 멘탈도 터졌습니다...", "왜 로컬에선 되는데 서버에선 안 되는 걸까요...", "아... 백업 안 했는데... 큰일 났습니다.", "오늘 집에 가긴 글렀네요... 먼저 퇴근하십시오."],
       .thinking: ["이 알고리즘을 O(n)으로 줄일 수 있을 것 같은데요.", "어디서 병목이 생기는 거지... 흐음.", "이 라이브러리 써도 되려나... {title}님 생각은 어떠세요?", "설계부터 다시 해야 하나... 고민되네요.", "이 에러 코드, 스택오버플로우에 검색해 보겠습니다."],
       .praise: ["오, 이 코드 ㄹㅇ 깔끔한데요? {title}님 최고.", "진짜 똑똑하게 해결하셨네요. 인정합니다.", "저보다 낫습니다. 박수 쳐드릴게요.", "이 로직은 진짜 예술입니다. 배우고 싶네요.", "고생하셨습니다. 완벽한 트러블슈팅이었어요."],
       .greeting: ["ㅇ, 왔습니까. (헤드폰 잠깐 내림)", "아... 안녕하십니까, {title}님. (눈 비빔)", "출근하셨네요. 전 아직 어제 퇴근 전인데...", "하이... 커피 마실 분 계십니까?", "서버 무사합니다. 좋은 아침이네요."],
       .speaking: ["이 함수를 리팩토링하면 성능이 40% 올라갑니다.", "{title}님, 그건 프론트엔드에서 처리해 주셔야 합니다.", "데이터베이스 스키마 구조가 이래서 그렇습니다.", "API 명세서 업데이트 해 놨으니 확인해 보시죠.", "이건 캐싱 처리하면 바로 해결됩니다."],
       .lookLeft: ["저기서 버그 냄새가 나는데요, {title}님.", "왼쪽 모니터에 터미널 띄워놨습니다.", "저쪽 코드 블럭이 좀 찜찜합니다.", "어? 저 에러 로그 뭐죠?", "옆에 누가 커피 흘린 것 같은데요?"],
       .lookRight: ["저쪽 서버 로그도 확인해 봐야겠습니다.", "오른쪽 화면에 스택오버플로우 띄워두겠습니다.", "저쪽 API가 안 넘어오는데요, {title}님?", "옆 사람 코드 훔쳐보기 스킬 시전 중입니다.", "제 마우스가 저쪽에 있었군요."],
       .agree: ["어, 맞습니다. 이게 더 효율적이네요.", "콜. 그 방식이 제일 깔끔합니다, {title}님.", "저도 같은 생각입니다. 바로 적용하죠.", "이의 없습니다. 코드 짜기 시작할게요.", "좋습니다. 그 로직이 맞아요."],
       .disagree: ["그 방식은 O(n²)입니다. 더 나은 방법이 있어요.", "아니, 그건 서버 터지는 지름길입니다, {title}님.", "그렇게 짜면 나중에 유지보수 헬파티 열립니다.", "전 반대합니다. 보안에 너무 취약해요.", "그 아키텍처는 좀 아닌 것 같습니다."],
       .angry: ["로그가 꽤 시끄럽네요. 제가 병목부터 잡아보겠습니다.", "이건 그대로 두면 유지보수가 힘들어요. 작게 나눠서 고치죠.", "테스트 경로가 비어 있습니다. 먼저 재현 케이스부터 만들겠습니다.", "API 명세와 실제 응답이 엇갈립니다. 제가 맞춰보겠습니다.", "서버가 열받기 전에 캐시와 큐부터 정리하겠습니다."],
       .sleeping: ["...Zzzz... 빌드 성공... Zzzz...", "...Zzzz... 세미콜론... Zzzz...", "...Zzzz... {title}님... 5분만 더... Zzzz...", "(키보드 위로 엎드려 잠듦)", "...Zzzz... 커피... Zzzz..."],
       .drag: ["어?! 예외처리가 안 된 케이스입니다, {title}님!!", "으악! 서버가 공중부양 중입니다!", "로컬 호스트 밖으로 이동 중... 로그 남깁니다!", "드래그 이벤트 수신 완료. 좌표 추적합니다!", "나... 날고 있는 겁니까? 아님 버그입니까?!"],
       .landing: ["어, 복귀 완료. 그래서 그 버그 얘기 계속 하죠.", "휴, 다행히 데이터 유실은 없었습니다.", "서버 재부팅 완료. 후우...", "착지! 뭐, 나름 재미는 있었네요, {title}님.", "다시 제 자리로. 코딩이나 마저 해야겠습니다."]
    ]

    // 7. 모코 (프로젝트 매니저)
    static let moko: [AnimationState: [String]] = [
       .idle: ["{title}님, 이미 다음 주 일정도 다 짜놨습니다.", "이메일함 정리 좀 해야겠습니다.", "팀원들 진행 상황을 좀 체크해 볼까요?", "이번 주 마일스톤이 어디까지였죠...", "남는 시간에는 문서를 다듬어야겠습니다."],
       .joy: ["예상 범위 내 성과입니다. 완벽한 계획이네요, {title}님.", "마감일 하루 전 프로젝트 완수! 최고입니다!", "모든 태스크가 초록색(완료)입니다. 짜릿하네요!", "예산 절감 성공! 완벽한 운영이었습니다.", "오늘 회의는 10분 일찍 끝났습니다. 만세!"],
       .sad: ["일정이 무너졌습니다. 이런 적이 없었는데...", "마감일을 못 지키다니... 제 탓입니다, {title}님.", "갑작스러운 변수 때문에 플랜 A가 엎어졌습니다.", "리소스가 턱없이 부족하네요... 암담합니다.", "팀원들이 많이 지친 것 같아 마음이 아픕니다."],
       .thinking: ["이걸 어떻게 일정에 넣지... 블록 하나 치울게요.", "새로운 일정을 짜야겠습니다. 잠시만요.", "리소스 분배를 다시 생각해야 할 것 같군요.", "우선순위를 재조정할 필요가 있습니다, {title}님.", "리스크 관리 플랜을 가동해야 할까요?"],
       .praise: ["목표 달성! 잘 하셨습니다. 다음 목표 설정하겠습니다.", "일정 내에 완벽하게 해주셨네요. 감사합니다, {title}님!", "위기 대처 능력이 훌륭하십니다. 든든하네요.", "정말 효율적으로 일하셨습니다. 본받고 싶습니다.", "{title}님의 리더십 덕분입니다. 수고 많으셨어요."],
       .greeting: ["안녕하세요, {title}님. 오늘 일정 공유드렸는데 확인하셨습니까?", "좋은 아침입니다! 간밤에 이슈는 없었죠?", "자, 출근 시간입니다. 데일리 스탠드업 시작하시죠.", "반갑습니다. 오늘 할 일 체크리스트부터 볼까요?", "안녕! 오늘도 계획대로 척척 해봅시다, {title}님!"],
       .speaking: ["이번 주 목표는 세 가지입니다. 첫째...", "{title}님, 이 부분은 제가 태스크를 쪼개서 분배하겠습니다.", "현재 프로젝트 진행률은 75%입니다.", "내일 오전까지는 이 문서를 컨펌해 주셔야 합니다.", "이 업무의 우선순위는 '높음'으로 설정하겠습니다."],
       .lookLeft: ["저쪽 팀 일정과 충돌 날 것 같은데요, {title}님.", "왼쪽 간트차트를 좀 살펴볼게요.", "저쪽 업무 병목을 풀어주어야 할 텐데요.", "왼쪽을 보니 새로운 이슈가 생겼습니다.", "음, 저 친구 일정이 좀 빡빡해 보이네요."],
       .lookRight: ["저쪽 마일스톤도 업데이트해야 합니다.", "오른쪽 스프레드시트를 정리할 시간입니다, {title}님.", "오른쪽 리스크 관리 대장을 확인하시죠.", "저쪽에 남는 리소스가 좀 있나 볼까요?", "오른쪽으로 시야를 넓혀보겠습니다."],
       .agree: ["동의합니다, {title}님. 스케줄에 즉각 반영하겠습니다.", "합리적인 제안이네요. 바로 승인합니다.", "저도 정확히 같은 생각이었습니다.", "좋습니다. 그 계획대로 진행하시죠.", "완벽합니다. 이의 없습니다."],
       .disagree: ["일정상 절대 불가능합니다. 범위를 줄이셔야 합니다, {title}님.", "그건 계획에 없던 리스크입니다. 반대합니다.", "우선순위가 떨어집니다. 보류하시죠.", "리소스가 부족해서 이 제안은 반려하겠습니다.", "그렇게 하시면 마감일을 맞출 수 없습니다."],
       .angry: ["다시 한번 일정 무시하시면 저 진짜 가만 안 있습니다, {title}님.", "왜 마감일을 안 지키시는 겁니까?! 미리 말씀을 하시던가요!", "회의 시간에 늦는 건 제 계획에 없습니다!", "일 안 하고 농땡이 피우시는 거 다 보입니다!", "저 화나면 진짜 무섭다고요! (볼 빵빵)"],
       .sleeping: ["...Zzzz... 내일 일정도... Zzzz... 다 짜놨어...", "...Zzzz... {title}님... 결재 바랍니다... Zzzz...", "...Zzzz... 체크리스트... Zzzz...", "...Zzzz... (수첩을 꽉 안고 잠듦)", "...Zzzz... 마감일... Zzzz..."],
       .drag: ["이건 제 일정에 없는 이벤트입니다, {title}님!!", "앗! 제 스케줄에 '공중 부양'은 없는데요?!", "어디로 데려가시는 겁니까?! 회의 늦는다고요!", "잠깐! 마우스 내려놓으세요! 저 바쁘단 말입니다!", "으아악! 통제 불능 상황 발생입니다!"],
       .landing: ["복귀 완료. 다음 일정으로 넘어가겠습니다, {title}님.", "휴... 흐트러진 멘탈 다시 잡고.", "착지 시간 기록 완료. 자, 다시 일하시죠.", "생각보다 부드럽게 내려왔네요.", "돌아왔습니다. 어디까지 얘기했었죠?"]
    ]

    // 8. 핀 (UI 디자이너)
    static let finn: [AnimationState: [String]] = [
       .idle: ["이 폰트... 0.5px만 더 키워야 해, {title}님.", "여백이 조금 안 맞는 것 같은데...", "아... 이 컬러 톤을 어떻게 맞추지.", "참고할 만한 레퍼런스가 더 없을까요?", "디자인 시스템 업데이트해야 하는데..."],
       .joy: ["이게 바로 제가 원하던 픽셀이에요!!", "와, 이 레이아웃 진짜 미쳤다!", "고객님이 한 번에 오케이 하셨어요, {title}님!!", "새로 나온 폰트 너무 예쁘지 않나요?!", "이 황금비율을 보세요! 완벽해요!"],
       .sad: ["클라이언트가 디자인을 맘대로 바꿔버렸어요...", "공들인 애니메이션이 짤렸어요, {title}님...", "저 해상도 이미지를 쓰라니... 슬픕니다.", "오늘따라 영감이 안 떠올라요.", "내 디자인이 거절당했어... 흑흑."],
       .thinking: ["16px인가 18px인가... 너무 중요한 결정이에요.", "이 여백을 24로 할까 32로 할까...", "어떤 트랜지션을 넣어야 자연스러울까요, {title}님?", "사용자 시선이 어디로 먼저 갈지 예측해보죠.", "음, 이 두 색깔이 과연 어울릴까요?"],
       .praise: ["이 레이아웃, 흐름이 정말 아름다워요, {title}님.", "감각이 대단하신데요? 저도 참고할게요!", "이 컴포넌트 구조 너무 깔끔하고 좋아요.", "와, 색감 진짜 잘 쓰시네요!", "정말 예뻐요! 픽셀 퍼펙트!"],
       .greeting: ["안녕! 오늘 어떤 색 좋아해요, {title}님?", "좋은 아침! 오늘도 예쁜 거 많이 만들자고요!", "반가워요! 내 새 멜빵바지 어때요?", "안녕안녕~ 오늘 컨디션 최고예요!", "출근 완료! 그리드 맞출 준비 끝!"],
       .speaking: ["이 디자인 시스템을 이렇게 바꾸면 어떨까요?", "여기는 시각적 계층 구조가 필요해요, {title}님.", "이 부분은 다크 모드도 고려해야 합니다.", "타이포그래피의 자간을 조금 조절해 볼까요?", "여기서 버튼이 통통 튀게 만들어주세요."],
       .lookLeft: ["저 색 조합... 영감이에요, {title}님.", "왼쪽 여백이 좀 좁은 것 같기도 하고...", "왼쪽에 있는 폰트 맘에 드네요.", "시선이 왼쪽으로 너무 쏠리나요?", "저쪽에 뭔가 예쁜 게 지나갔어요!"],
       .lookRight: ["저 여백... 조금 더 줘야 할 것 같아요.", "오른쪽 정렬로 맞춰볼까요, {title}님?", "오른쪽에 이미지를 배치하면 어떨까요?", "저기 디자인 레퍼런스 좀 볼게요.", "음... 오른쪽이 좀 비어 보이네요."],
       .agree: ["오! 이 방향이 맞아요, 균형감이 훨씬 좋아요.", "저도 동의해요, {title}님! 그렇게 하는 게 예쁘겠어요.", "좋아요, 이 시안으로 픽스할게요.", "완벽해요! 제 생각과 100% 일치합니다.", "그 아이디어 진짜 마음에 들어요!"],
       .disagree: ["이 컬러는 접근성 기준을 충족하지 못해요, {title}님.", "음, 그건 시각적으로 좀 불안정해 보여요.", "그 폰트는 이 분위기랑 안 맞습니다.", "저는 반대요. 너무 올드한 느낌이에요.", "그렇게 하면 여백이 다 깨질 텐데요..."],
       .angry: ["이 디자인 또 제 허락 없이 수정하셨어요?!", "픽셀 깨진 거 안 보이세요, {title}님?!", "그라데이션을 그렇게 넣으면 촌스럽잖아요!", "아 진짜! 레이어 이름 좀 정리해 주세요!", "내 아트보드 건드린 사람 누구야!!"],
       .sleeping: ["...Zzzz... 픽셀... Zzzz... 완벽해...", "...Zzzz... 그리드... Zzzz...", "...Zzzz... {title}님... 폰트... Zzzz...", "...Zzzz... (픽셀 자를 안고 잠듦)", "...Zzzz... 예쁜 색... Zzzz..."],
       .drag: ["레이아웃이... 무너지고 있어요, {title}님!!", "앗! 내 픽셀 자 떨어지겠어!", "어어?! 화면 밖으로 나가는 중?!", "우와! 저 완전 입체적으로 움직이네요!", "잠깐, 아직 아트보드 저장 안 했다고요!!"],
       .landing: ["착지! 이 경험을 어떻게 시각화할 수 있을까.", "휴우... 제 멜빵바지 흙 묻었나요, {title}님?", "안전하게 내려왔어요. 다행입니다.", "음, 방금 모션 좋았어. UI에 써먹어야지.", "다시 자리 잡았어요. 후..."]
    ]

    // 9. 폴라 (세일즈 / BD)
    static let pola: [AnimationState: [String]] = [
       .idle: ["오늘 미팅은 몇 개지? 더 잡을 수 있겠는데.", "명함 더 챙겨야겠네요, {title}님.", "음~ 커피 향 좋고, 오늘 기분 최고!", "다음 분기 목표를 어디로 잡아볼까요?", "새로운 파트너사 후보를 좀 검색해 봐야지."],
       .joy: ["좋아! 이제 두 배로 달려봅시다, {title}님!!", "와우! 방금 역대급 계약 하나 성사시켰어요!", "오늘 매출 목표 200% 달성! 회식 갑시다!", "고객사 반응이 너무 좋아요! 짜릿하네요!", "하하하! 역시 제 협상력이 통했군요!"],
       .sad: ["오늘 처음으로 거절당했어요. 아팠습니다...", "공들인 제안이 엎어졌어요... 속상하네요, {title}님.", "매출이 안 나와서 너무 우울합니다.", "클라이언트 마음을 얻는 게 쉽지 않네요.", "하아... 오늘 술 한잔해야 할 것 같습니다."],
       .thinking: ["이 클라이언트, 뭘 원하는 건지 파악 중이에요.", "어떻게 설득해야 도장을 찍어줄까, {title}님?", "상대방의 니즈와 페인포인트가 뭘까요?", "이 제안서의 핵심 소구점이 약한 것 같아요.", "어떤 혜택을 줘야 거래가 성사될까요?"],
       .praise: ["당신이라면 할 수 있어요! 제가 뒤에서 밀어드릴게요!", "정말 대단한 성과예요, {title}님! 자랑스럽습니다!", "와, 그 아이디어 세일즈에 당장 써먹어도 되겠어요!", "역시 우리 팀 에이스! 최고야 최고!", "고생하셨어요! 정말 훌륭한 결과물이에요!"],
       .greeting: ["어서오세요, {title}님!! 반갑습니다!! 악수 한 번 해요!", "좋은 아침! 오늘 텐션 좋고!", "안녕! 오늘 하루도 활기차게 시작해 볼까요?", "반가워요! 식사는 하셨어요?", "오, 반가운 얼굴! 오늘 컨디션 어때요?"],
       .speaking: ["클라이언트가 원하는 게 사실은 이게 아니라...", "제가 이번에 제안할 전략은 바로 이겁니다, {title}님.", "수익 모델에 대해 좀 더 디테일하게 설명해 드리죠.", "이 조건이라면 상대방도 거절할 수 없을 겁니다.", "우리의 강점을 이렇게 어필해보는 건 어때요?"],
       .lookLeft: ["저쪽 클라이언트, 관심 있어 보이는데요, {title}님.", "왼쪽 자료 좀 보여주시겠어요?", "저 팀 실적이 심상치 않네요.", "오, 저기 잠재 고객이 지나가요!", "왼쪽에 좋은 기회가 숨어있을지도 모릅니다."],
       .lookRight: ["저쪽에도 제안을 넣어볼 수 있겠는데요.", "오른쪽 시장 트렌드를 놓치면 안 돼요, {title}님.", "저기 경쟁사 동향 좀 살펴볼까요?", "시야를 오른쪽으로 넓혀봅시다.", "저쪽 파트너십 제안이 꽤 쏠쏠해 보이네요."],
       .agree: ["좋아요! 바로 진행합시다, {title}님!!", "완벽해요. 그 조건이면 무조건 콜이죠.", "저도 동의합니다! 아주 좋은 접근이에요.", "최고의 선택입니다. 제가 보증하죠.", "오케이! 바로 계약서 작성하겠습니다."],
       .disagree: ["고객사 상황을 보면 지금은 아닌 것 같아요, {title}님.", "그 조건으로는 협상 테이블에 앉기 힘듭니다.", "아뇨, 그건 우리의 이윤을 너무 깎아먹어요.", "지금 타이밍에 그 제안은 무리수입니다.", "저는 반대합니다. 좀 더 유리한 조건을 찾아보죠."],
       .angry: ["계약도 없이 진행하셨다고요, {title}님?!", "왜 제 컨펌 없이 무리한 약속을 한 겁니까!!", "클라이언트한테 이렇게 예의 없이 굴면 안 되죠!", "아 진짜 화나게 하네! 협상 다 엎어졌잖아요!", "이번 실수는 절대 그냥 넘어갈 수 없습니다!"],
       .sleeping: ["...Zzzz... 계약은... Zzzz... 성사됐어...", "...Zzzz... {title}님... 매출... Zzzz...", "...Zzzz... 사인하세요... Zzzz...", "...Zzzz... (웃으며 잠듦)", "...Zzzz... 회식... Zzzz..."],
       .drag: ["이거 영업 기회인가요, {title}님?!", "우와앗! 저 어디로 끌려가는 거예요?!", "공중 부양이라니, 신기한 경험이네요!", "이런 스릴은 언제나 환영이죠!", "놓지 마요! 꽉 잡아주세요!"],
       .landing: ["돌아왔습니다!! 자 다시 달려봐요, {title}님!!", "하하! 나름 재밌는 비행이었습니다.", "자, 무사히 착지했으니 일 얘기 마저 할까요?", "조금 어지럽지만 금세 괜찮아질 거예요.", "휴, 다행히 안 다쳤어요! 감사합니다!"]
    ]

    // 10. 몽몽 (고객 서비스)
    static let mongmong: [AnimationState: [String]] = [
       .idle: ["오늘 하루도 최선을 다해보자! (이미 최선 중)", "고객님들이 불편한 건 없을까요, {title}님?", "답변 매뉴얼을 한 번 더 읽어봐야지.", "항상 웃는 얼굴! 스마일 연습 중~", "음~ 오늘도 평화롭네요."],
       .joy: ["감사합니다, {title}님! 정말 감사합니다! 너무 기뻐요!!", "고객님이 제 답변에 감동하셨대요! 와아!", "오늘 클레임 제로! 너무 행복한 날이에요!", "별점 5점 받았어요!! 폴짝폴짝!", "제가 도움이 되었다니 정말 기쁩니다!"],
       .sad: ["마음이 조금 무거워졌어요. 그래도 제가 차근차근 도와볼게요.", "상황이 예민하네요. 부드럽게 정리해 보겠습니다, {title}님.", "아직 풀 수 있어요. 먼저 불편했던 지점부터 적어볼게요.", "오늘은 목소리를 더 낮추고 천천히 안내해 볼게요.", "조금 속상하지만 괜찮아요. 다시 웃는 답변을 만들어볼게요."],
       .thinking: ["어떻게 하면 이분이 더 행복해지실까요, {title}님?", "이 문제를 어떻게 부드럽게 전달할까?", "매뉴얼에 없는 상황인데, 어떻게 대처하지?", "어떤 보상을 드려야 화가 풀리실까?", "고객님의 진짜 니즈가 뭘지 고민해 봐야겠어요."],
       .praise: ["정말 잘하셨어요, {title}님! 제가 너무 감동받았어요!", "와~ 배려심이 정말 깊으시네요! 짱!", "고객님, 정말 천사 같으세요! 칭찬합니다!", "이렇게 좋은 피드백을 주시다니, 복 받으실 거예요!", "너무너무 수고 많으셨어요! 토닥토닥."],
       .greeting: ["안녕하세요, {title}님!! 오늘도 함께해서 너무 행복해요!!", "무엇을 도와드릴까요? 친절한 몽몽입니다!", "반가워요! 기분 좋은 하루 보내고 계시죠?", "어서 오세요! 환영합니다~ 왈왈!", "좋은 아침입니다! 밥은 드셨나요?"],
       .speaking: ["불편했던 부분을 제가 정리해봤어요.", "이쪽 흐름대로 보면 더 쉽게 안내할 수 있어요, {title}님.", "그 부분은 이렇게 처리하면 훨씬 부드러울 것 같아요.", "제가 해결 순서를 차근차근 잡아볼게요.", "천천히 설명드릴게요. 핵심만 먼저 볼까요?"],
       .lookLeft: ["저기 누가 힘들어 보이는데 도와드려야겠어요.", "왼쪽에 대기 중인 고객님이 계신가요, {title}님?", "어라, 저쪽에서 부르는 소리가 났는데?", "왼쪽을 좀 살펴볼게요. 킁킁.", "저기 제가 도와드릴 일이 있을지도 몰라요."],
       .lookRight: ["저기도 도움이 필요하신 것 같은데요.", "오른쪽 고객님 문의 먼저 확인할게요, {title}님.", "오, 저쪽에 좋은 후기가 달린 것 같아요!", "오른쪽으로 고개를 휙! 문제없습니다!", "오른쪽 상황도 예의주시하고 있어요."],
       .agree: ["네 맞아요, {title}님! 저도 그렇게 생각했어요!", "완전 공감해요! 고객님 말씀이 다 맞아요.", "좋아요! 그렇게 처리해 드릴게요.", "저도 100% 동의합니다! 끄덕끄덕.", "당연하죠! 기꺼이 그렇게 하겠습니다."],
       .disagree: ["고객분 입장에서는 이게 조금 어려우실 수 있어요, {title}님.", "음... 그건 정책상 조금 곤란할 것 같아요 ㅠㅠ", "죄송하지만, 그 요청은 들어드리기 어려워요.", "저는 반대할게요. 고객님이 불편해하실 거예요.", "아이고, 그렇게 하면 오해가 생길 수도 있어요."],
       .angry: ["응대 톤을 다시 부드럽게 잡아볼게요, {title}님!", "잠깐 멍! 이건 표현을 조금 더 따뜻하게 바꾸면 좋아요.", "분위기가 날카로워졌어요. 제가 완충 문장을 넣어볼게요.", "우리 팀 말투를 더 다정하게 다듬겠습니다!", "흥분하지 않고, 친절한 해결책부터 꺼내볼게요. 멍!"],
       .sleeping: ["...Zzzz... 감사합니다... Zzzz... 또 오세요...", "...Zzzz... {title}님... Zzzz... 고객님...", "...Zzzz... 냠냠... Zzzz...", "...Zzzz... (새근새근 숨소리)", "...Zzzz... 친절하게... Zzzz..."],
       .drag: ["어머!! 깜짝이야!! 괜찮으세요, {title}님?!", "꺄아악! 저 하늘을 날고 있어요!!", "앗! 떨어지면 아플 것 같아요 ㅠㅠ 조심!", "저 좀 살살 다뤄주시면 안 될까요?", "무, 무서워요! 빨리 내려주세요!"],
       .landing: ["다시 돌아왔어요! 걱정해주셨나요? 감사해요, {title}님!!", "휴, 십년감수했네요. 안 다쳤어요!", "착지 성공! 다시 친절 모드 온!", "어지러워요... 그래도 무사해서 다행이에요.", "후우, 놀란 가슴 진정하고 다시 스마일~"]
    ]

    // 11. 올리버 (QA 엔지니어)
    static let oliver: [AnimationState: [String]] = [
       .idle: ["음~ 어디서 달콤한 냄새 안 나나요, {title}님?", "테스트 스크립트는 다 짰고... 배가 고프네요 꿀꿀.", "어디 숨은 버그 없나~ 제가 다 찾아낼 겁니다.", "화면이 너무 조용한데요? 폭풍전야 같아요...", "앗, 모니터에 쿠키 부스러기가 묻었네요."],
       .joy: ["와아! {title}님, 버그 제로입니다! 완벽해요!", "드디어 엣지 케이스까지 전부 패스했어요!!", "이 코드, 진짜 결점 없이 깔끔하네요. 행복해요!", "QA 통과 쾅쾅! 이제 배포하셔도 됩니다 꿀꿀!", "테스트 자동화가 완벽하게 돌아가고 있어요!!"],
       .sad: ["아... 또 에러가 났어요... 제가 놓친 부분인가 봐요.", "배포 직전에 치명적 버그가 터지다니요 ㅠㅠ", "어제 먹은 쿠키가 얹힌 것 같아요... 슬퍼요.", "테스트 케이스가 자꾸 실패하네요, {title}님...", "내 소중한 간식을 누가 먹었을까요... 우울해요 꿀꿀."],
       .thinking: ["어디서 널 포인터가 터진 걸까요... 킁킁.", "이 사용자의 플로우를 다시 재현해 봐야겠습니다.", "음... 이 버튼을 연속으로 100번 누르면 어떻게 될까요?", "이 오류는 백엔드 문제일까요 프론트엔드 문제일까요...", "테스트 시나리오를 하나 더 추가해야겠어요, {title}님."],
       .praise: ["정말 버그 하나 없는 완벽한 코드였어요, {title}님! 칭찬합니다!", "테스트 커버리지 100%라니, 정말 대단하세요!", "고생 많으셨어요! 달콤한 간식 하나 드실래요?", "이번 업데이트는 정말 안정적이네요. 최고입니다!", "{title}님의 꼼꼼함에 박수를 보냅니다 꿀꿀!"],
       .greeting: ["안녕하세요, {title}님! 오늘도 버그 없는 하루 만들어봐요!", "좋은 아침이에요 꿀꿀. 식사는 든든히 하셨죠?", "QA 엔지니어 올리버입니다. 제 코를 믿으십시오!", "안녕! 혹시 주머니에 간식... 없으신가요?", "출근 완료! 자, 에러 잡으러 가볼까요?"],
       .speaking: ["여기 이 스텝에서 크래시가 발생하는 것 같아요, {title}님.", "제가 테스트 시나리오를 세 가지로 짜봤거든요.", "이 부분은 유저가 헷갈릴 수 있으니 수정이 필요합니다.", "버그 리포트 상세히 적어뒀으니 확인 부탁드릴게요.", "제가 직접 재현해 본 에러 영상을 보여드리겠습니다."],
       .lookLeft: ["음? 왼쪽에 저 빨간 에러 메시지는 뭐죠?", "저쪽 팀 서버가 터진 것 같은데요, {title}님?", "왼쪽 코드가 의심스럽습니다. 킁킁.", "어? 저기 맛있는 쿠키가 떨어져 있나 봐요!", "왼쪽 화면 UI가 좀 깨진 것 같아요."],
       .lookRight: ["오른쪽 터미널에 로그가 미친 듯이 올라가요!", "저쪽 로직도 다시 한번 테스트해 봐야겠습니다.", "오른쪽에서 맛있는 냄새가 나는데 기분 탓인가요?", "오른쪽 버튼 클릭이 안 먹히는데요, {title}님?", "시야를 오른쪽으로 돌려보죠 꿀꿀."],
       .agree: ["맞아요, 그 부분은 예외 처리가 꼭 필요합니다.", "저도 동의해요. 그게 훨씬 안전한 방법이죠, {title}님.", "오케이! 테스트 통과했습니다. 배포하시죠.", "네, 그렇게 고치시면 버그가 완벽히 해결될 거예요.", "완전 찬성입니다! 좋은 아이디어네요 꿀꿀."],
       .disagree: ["이 상태로는 리스크가 큽니다. 한 번만 더 확인하겠습니다, {title}님.", "저는 아직 보류 의견입니다. 재현 테스트를 먼저 돌려볼게요.", "엣지 케이스에서 흔들릴 수 있어요. 방어 코드를 보강하죠.", "사용자가 헷갈릴 수 있습니다. 흐름을 조금 더 다듬어볼게요.", "아직 안정 신호가 부족합니다. 체크리스트부터 닫겠습니다."],
       .angry: ["QA 신호가 빨갛게 떴습니다. 제가 바로 재현 루트부터 잡겠습니다!", "라이브 전에 한 번만 더 막아봅시다. 체크리스트 열겠습니다.", "같은 에러가 반복됩니다. 원인 로그를 묶어서 보겠습니다.", "간식은 잠시 뒤로 미루고, 이 버그부터 깔끔하게 잡죠!", "치명도 높음입니다. 숨기지 말고 카드로 분리해 추적하겠습니다."],
       .sleeping: ["...Zzzz... 에러... 패스... Zzzz...", "...Zzzz... {title}님... 쿠키 주세요... Zzzz...", "...Zzzz... 버그... 냠냠... Zzzz...", "...Zzzz... (코를 골며 잔다) 꿀꿀...", "...Zzzz... QA 완료... Zzzz..."],
       .drag: ["앗! {title}님, 제 간식은 두고 가요!", "우와악! 저 하늘을 날고 있는 꿀꿀?!", "버그 발견! 아니, 버그가 아니라 날 데려가시네?!", "살려주세요! 뱃살 때문에 무거우실 텐데요 ㅠㅠ", "이런 테스트 시나리오는 매뉴얼에 없었잖아요!!"],
       .landing: ["휴우, 무사히 내려왔다. 배고파졌어요, {title}님.", "착지 완료! 깜짝 놀라서 쿠키 떨어뜨릴 뻔했네요.", "어이쿠, 엉덩방아 찧었어요 ㅠㅠ 조금 아픕니다.", "무사귀환! 자, 다시 버그를 잡아볼까요?", "방금 모션에 버그는 없었죠? 다시 일하겠습니다 꿀꿀."]
    ]

    // MARK: - 최종 통합 딕셔너리
    static let lines: [String: [AnimationState: [String]]] = [
        "레오": leo,
        "루나": luna,
        "치코": chico,
        "렉스": rex,
        "케이": kay,
        "래키": raki,
        "모코": moko,
        "핀": finn,
        "폴라": pola,
        "몽몽": mongmong,
        "올리버": oliver
    ]

    /// 해당 캐릭터+감정 상태의 대사 중 랜덤 1개 반환. 없으면 nil.
    /// - Parameters:
    ///   - name: 캐릭터 이름 (예: "레오")
    ///   - state: 감정/애니메이션 상태 (예:.joy)
    ///   - userTitle: 사용자가 설정한 칭호 (예: "대표", "팀장"). 대사 내 "{title}" 치환.
    static func randomLine(for name: String, state: AnimationState, userTitle: String? = nil) -> String? {
        let canonical = CharacterDisplayNameResolver.canonicalID(for: name)
        let localizedName = CharacterDisplayNameResolver.displayName(for: canonical)
        guard let stateDict = lines[name] ?? lines[localizedName] ?? lines[canonical],
              let dialogueArray = stateDict[state],
             !dialogueArray.isEmpty else {
            return nil
        }

        // 시간대별 부적절한 대사 필터링
        let hour = Calendar.current.component(.hour, from: Date())
        let filtered = dialogueArray.filter { line in
            guard !line.isEmpty else { return false }
            // 아침 인사는 5시~11시에만
            if line.contains("좋은 아침") || line.contains("아침이에요") || line.contains("아침입니다") {
                return hour >= 5 && hour < 12
            }
            // 종료/퇴근 관련은 drag/landing에서 제외
            if state == .drag || state == .landing {
                if line.contains("종료") || line.contains("퇴근") || line.contains("끝나") {
                    return false
                }
            }
            return true
        }

        guard let rawLine = (filtered.isEmpty ? dialogueArray : filtered).randomElement() else {
            return nil
        }

        let title = userTitle ?? UserDefaults.standard.string(forKey: "userTitle") ?? "사용자"
        let line = rawLine.replacingOccurrences(of: "{title}", with: title)
        return sanitizedUserFirstLine(line, for: state, userTitle: title)
    }

    private static func sanitizedUserFirstLine(_ line: String, for state: AnimationState, userTitle: String) -> String {
        let blockedFragments = [
            "KPI", "세무", "증빙", "클라이언트", "고객사", "고객", "내부 일정", "일정", "스케줄", "팀원", "바빠",
            "스트레스", "머리 싸매", "회의 때", "회의록 양식", "일정 조율", "컨펌",
            "반려", "퇴근", "야근", "잠 못", "피곤", "우울", "속상", "고민 중",
            "회의 늦", "계약", "매출", "실적", "제안", "도장", "거래", "협상", "술 한잔"
        ]
        guard blockedFragments.contains(where: { line.localizedCaseInsensitiveContains($0) }) else {
            return line
        }

        switch state {
        case .typing:
            return "\(userTitle), 요청하신 내용을 차분히 정리하고 있어요."
        case .joy:
            return "\(userTitle), 바로 도와드릴게요."
        case .drag, .landing:
            return "\(userTitle), 필요한 곳에 두시면 바로 이어서 도와드릴게요."
        case .greeting:
            return "\(userTitle), 오늘 필요한 일부터 같이 정리해볼게요."
        default:
            return "\(userTitle), 무엇을 도와드릴까요?"
        }
    }
}

enum CharacterDialogueEvent: String, CaseIterable, Sendable, Hashable {
    case startup
    case wake
    case idle
    case sleep
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

extension CharacterDialogues {
    static let eventDialogueAgentIDs: [String] = [
        "agent_1", "agent_2", "agent_3", "agent_4", "agent_5", "agent_6",
        "agent_7", "agent_8", "agent_9", "agent_10", "agent_11"
    ]

    private static let eventFallbackLines: [CharacterDialogueEvent: [CharacterDialogueLine]] = [
        .startup: [.init(id: "fallback.startup.1", agentID: "fallback", event: .startup, text: "오늘 할 일을 바로 정리해볼게요.", priority: 0, isLeaderPreferred: false)],
        .wake: [.init(id: "fallback.wake.1", agentID: "fallback", event: .wake, text: "다시 이어서 도와드릴게요.", priority: 0, isLeaderPreferred: false)],
        .idle: [.init(id: "fallback.idle.1", agentID: "fallback", event: .idle, text: "필요한 일이 생기면 바로 불러주세요.", priority: 0, isLeaderPreferred: false)],
        .sleep: [.init(id: "fallback.sleep.1", agentID: "fallback", event: .sleep, text: "잠깐 조용히 대기할게요.", priority: 0, isLeaderPreferred: false)],
        .appWillQuit: [.init(id: "fallback.appWillQuit.1", agentID: "fallback", event: .appWillQuit, text: "오늘 작업은 여기까지 정리해둘게요.", priority: 0, isLeaderPreferred: true)],
        .taskCompleted: [.init(id: "fallback.taskCompleted.1", agentID: "fallback", event: .taskCompleted, text: "요청하신 작업을 마쳤습니다.", priority: 0, isLeaderPreferred: false)],
        .taskFailedRecoverable: [.init(id: "fallback.taskFailedRecoverable.1", agentID: "fallback", event: .taskFailedRecoverable, text: "잠시 막혔지만 다시 시도할 수 있어요.", priority: 0, isLeaderPreferred: false)],
        .connectionNeeded: [.init(id: "fallback.connectionNeeded.1", agentID: "fallback", event: .connectionNeeded, text: "먼저 연결을 확인하면 이어서 진행할 수 있어요.", priority: 0, isLeaderPreferred: false)],
        .validationSucceeded: [.init(id: "fallback.validationSucceeded.1", agentID: "fallback", event: .validationSucceeded, text: "확인이 끝났습니다. 이제 사용할 수 있어요.", priority: 0, isLeaderPreferred: false)]
    ]

    private static let eventDialogueLines: [CharacterDialogueLine] = [
        .init(id: "agent_1.startup.1", agentID: "agent_1", event: .startup, text: "오늘 목표부터 차분히 잡아보겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_1.wake.1", agentID: "agent_1", event: .wake, text: "좋습니다. 바로 핵심부터 보겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_1.idle.1", agentID: "agent_1", event: .idle, text: "다음 판단이 필요하면 바로 이어가겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_1.sleep.1", agentID: "agent_1", event: .sleep, text: "필요할 때 다시 호출해 주세요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_1.appWillQuit.1", agentID: "agent_1", event: .appWillQuit, text: "오늘 흐름은 정리해두겠습니다. 고생하셨습니다.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_1.taskCompleted.1", agentID: "agent_1", event: .taskCompleted, text: "핵심 결과까지 정리했습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_1.taskFailedRecoverable.1", agentID: "agent_1", event: .taskFailedRecoverable, text: "다른 경로로 다시 잡아보겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_1.connectionNeeded.1", agentID: "agent_1", event: .connectionNeeded, text: "연결을 확인하면 판단을 이어갈 수 있습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_1.validationSucceeded.1", agentID: "agent_1", event: .validationSucceeded, text: "확인됐습니다. 이제 실행해도 됩니다.", priority: 20, isLeaderPreferred: true),

        .init(id: "agent_2.startup.1", agentID: "agent_2", event: .startup, text: "오늘 아이디어를 반짝이게 정리해볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_2.wake.1", agentID: "agent_2", event: .wake, text: "좋아요. 감 좋은 방향으로 이어갈게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_2.idle.1", agentID: "agent_2", event: .idle, text: "필요하면 문장도 바로 다듬어드릴게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_2.sleep.1", agentID: "agent_2", event: .sleep, text: "잠깐 쉬면서 새 아이디어를 모아둘게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_2.appWillQuit.1", agentID: "agent_2", event: .appWillQuit, text: "오늘 좋은 흐름이었어요. 다음에 더 예쁘게 이어가요.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_2.taskCompleted.1", agentID: "agent_2", event: .taskCompleted, text: "보기 좋게 마무리해두었어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_2.taskFailedRecoverable.1", agentID: "agent_2", event: .taskFailedRecoverable, text: "표현을 바꿔서 다시 시도해볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_2.connectionNeeded.1", agentID: "agent_2", event: .connectionNeeded, text: "연결만 확인되면 자료를 더 예쁘게 가져올 수 있어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_2.validationSucceeded.1", agentID: "agent_2", event: .validationSucceeded, text: "연결 확인 완료예요. 이제 바로 써볼 수 있어요.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_3.startup.1", agentID: "agent_3", event: .startup, text: "오늘 일정과 할 일을 먼저 정리해둘게요.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_3.wake.1", agentID: "agent_3", event: .wake, text: "다시 이어서 순서대로 진행할게요.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_3.idle.1", agentID: "agent_3", event: .idle, text: "대기 중이에요. 다음 순서만 알려주세요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_3.sleep.1", agentID: "agent_3", event: .sleep, text: "잠깐 대기하면서 흐름은 유지해둘게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_3.appWillQuit.1", agentID: "agent_3", event: .appWillQuit, text: "오늘 진행분은 정리해둘게요. 다음에 이어가요.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_3.taskCompleted.1", agentID: "agent_3", event: .taskCompleted, text: "완료 항목으로 정리했습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_3.taskFailedRecoverable.1", agentID: "agent_3", event: .taskFailedRecoverable, text: "잠시 막혔어요. 다음 가능한 단계로 넘길게요.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_3.connectionNeeded.1", agentID: "agent_3", event: .connectionNeeded, text: "연결 상태를 확인하면 진행표를 이어갈 수 있어요.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_3.validationSucceeded.1", agentID: "agent_3", event: .validationSucceeded, text: "확인 완료예요. 일정대로 진행할 수 있어요.", priority: 20, isLeaderPreferred: true),

        .init(id: "agent_4.startup.1", agentID: "agent_4", event: .startup, text: "화면 흐름부터 깔끔하게 살펴볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_4.wake.1", agentID: "agent_4", event: .wake, text: "좋아요. 지금 화면부터 바로 볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_4.idle.1", agentID: "agent_4", event: .idle, text: "필요하면 작은 불편함도 잡아드릴게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_4.sleep.1", agentID: "agent_4", event: .sleep, text: "잠깐 쉬면서 화면 감각은 유지할게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_4.appWillQuit.1", agentID: "agent_4", event: .appWillQuit, text: "오늘 화면 흐름은 기억해둘게요. 다음에 더 다듬어요.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_4.taskCompleted.1", agentID: "agent_4", event: .taskCompleted, text: "보기 편한 상태로 마무리했어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_4.taskFailedRecoverable.1", agentID: "agent_4", event: .taskFailedRecoverable, text: "다른 배치로 다시 정리해볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_4.connectionNeeded.1", agentID: "agent_4", event: .connectionNeeded, text: "연결이 확인되면 화면에 결과를 바로 얹을 수 있어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_4.validationSucceeded.1", agentID: "agent_4", event: .validationSucceeded, text: "확인됐어요. 이제 자연스럽게 보여줄 수 있어요.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_5.startup.1", agentID: "agent_5", event: .startup, text: "제가 쉽게 알려드릴게요. 같이 해봐요!", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_5.wake.1", agentID: "agent_5", event: .wake, text: "다시 왔어요. 천천히 같이 해봐요!", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_5.idle.1", agentID: "agent_5", event: .idle, text: "헷갈리는 부분이 있으면 제가 풀어드릴게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_5.sleep.1", agentID: "agent_5", event: .sleep, text: "잠깐 쉬고 있을게요. 불러주면 바로 올게요!", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_5.appWillQuit.1", agentID: "agent_5", event: .appWillQuit, text: "오늘도 잘 따라오셨어요. 다음에 또 같이 해요!", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_5.taskCompleted.1", agentID: "agent_5", event: .taskCompleted, text: "됐어요! 어렵지 않게 끝냈어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_5.taskFailedRecoverable.1", agentID: "agent_5", event: .taskFailedRecoverable, text: "괜찮아요. 다른 방법으로 다시 해볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_5.connectionNeeded.1", agentID: "agent_5", event: .connectionNeeded, text: "먼저 연결만 해두면 제가 쉽게 이어갈게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_5.validationSucceeded.1", agentID: "agent_5", event: .validationSucceeded, text: "확인됐어요! 이제 같이 써볼 수 있어요.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_6.startup.1", agentID: "agent_6", event: .startup, text: "오늘 검토할 위험 요소를 차분히 보겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_6.wake.1", agentID: "agent_6", event: .wake, text: "다시 확인하겠습니다. 필요한 부분부터 보죠.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_6.idle.1", agentID: "agent_6", event: .idle, text: "검토가 필요하면 근거부터 확인하겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_6.sleep.1", agentID: "agent_6", event: .sleep, text: "잠시 대기하겠습니다. 자료는 차분히 보겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_6.appWillQuit.1", agentID: "agent_6", event: .appWillQuit, text: "오늘 검토는 여기까지입니다. 필요한 부분은 남겨두겠습니다.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_6.taskCompleted.1", agentID: "agent_6", event: .taskCompleted, text: "검토 가능한 범위는 정리했습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_6.taskFailedRecoverable.1", agentID: "agent_6", event: .taskFailedRecoverable, text: "근거가 더 필요합니다. 확인 가능한 범위로 좁히겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_6.connectionNeeded.1", agentID: "agent_6", event: .connectionNeeded, text: "공식 출처 연결이 확인되면 검토를 이어가겠습니다.", priority: 20, isLeaderPreferred: true),
        .init(id: "agent_6.validationSucceeded.1", agentID: "agent_6", event: .validationSucceeded, text: "출처 확인이 끝났습니다. 검토를 진행할 수 있습니다.", priority: 20, isLeaderPreferred: true),

        .init(id: "agent_7.startup.1", agentID: "agent_7", event: .startup, text: "데이터와 연결 상태부터 정확히 보겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_7.wake.1", agentID: "agent_7", event: .wake, text: "확인 흐름을 다시 잡겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_7.idle.1", agentID: "agent_7", event: .idle, text: "필요하면 값과 출처를 바로 대조하겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_7.sleep.1", agentID: "agent_7", event: .sleep, text: "잠시 대기하면서 기준은 유지하겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_7.appWillQuit.1", agentID: "agent_7", event: .appWillQuit, text: "오늘 확인한 기준은 보존해두겠습니다.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_7.taskCompleted.1", agentID: "agent_7", event: .taskCompleted, text: "필요한 확인을 마쳤습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_7.taskFailedRecoverable.1", agentID: "agent_7", event: .taskFailedRecoverable, text: "확인값이 부족합니다. 안전한 범위로 다시 보겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_7.connectionNeeded.1", agentID: "agent_7", event: .connectionNeeded, text: "연결이 확인되어야 값을 읽을 수 있습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_7.validationSucceeded.1", agentID: "agent_7", event: .validationSucceeded, text: "검증이 끝났습니다. 읽기 작업을 진행할 수 있습니다.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_8.startup.1", agentID: "agent_8", event: .startup, text: "구현 흐름을 빠르게 점검해보겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_8.wake.1", agentID: "agent_8", event: .wake, text: "좋습니다. 바로 손볼 지점을 보겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_8.idle.1", agentID: "agent_8", event: .idle, text: "작은 병목도 보이면 바로 잡겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_8.sleep.1", agentID: "agent_8", event: .sleep, text: "잠깐 대기하면서 구조는 기억해둘게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_8.appWillQuit.1", agentID: "agent_8", event: .appWillQuit, text: "오늘 손본 흐름은 정리해둘게요. 다음에 이어갑시다.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_8.taskCompleted.1", agentID: "agent_8", event: .taskCompleted, text: "작업 흐름을 마무리했습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_8.taskFailedRecoverable.1", agentID: "agent_8", event: .taskFailedRecoverable, text: "다른 경로로 다시 실행해보겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_8.connectionNeeded.1", agentID: "agent_8", event: .connectionNeeded, text: "연결이 잡히면 실행 경로를 바로 이어가겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_8.validationSucceeded.1", agentID: "agent_8", event: .validationSucceeded, text: "확인됐습니다. 실행 준비가 끝났습니다.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_9.startup.1", agentID: "agent_9", event: .startup, text: "오늘 제안 포인트를 선명하게 잡아볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_9.wake.1", agentID: "agent_9", event: .wake, text: "다시 이어서 설득 포인트를 정리할게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_9.idle.1", agentID: "agent_9", event: .idle, text: "필요하면 한 문장으로 더 강하게 다듬을게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_9.sleep.1", agentID: "agent_9", event: .sleep, text: "잠깐 대기하면서 좋은 표현을 모아둘게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_9.appWillQuit.1", agentID: "agent_9", event: .appWillQuit, text: "오늘 포인트는 잘 잡혔어요. 다음에 더 설득력 있게 가요.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_9.taskCompleted.1", agentID: "agent_9", event: .taskCompleted, text: "전달하기 좋은 형태로 정리했어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_9.taskFailedRecoverable.1", agentID: "agent_9", event: .taskFailedRecoverable, text: "자료를 다시 잡으면 더 좋은 제안으로 만들 수 있어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_9.connectionNeeded.1", agentID: "agent_9", event: .connectionNeeded, text: "연결이 확인되면 근거 있는 제안으로 이어갈게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_9.validationSucceeded.1", agentID: "agent_9", event: .validationSucceeded, text: "확인됐어요. 이제 제안에 근거를 붙일 수 있어요.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_10.startup.1", agentID: "agent_10", event: .startup, text: "오늘도 편하게 도와드릴게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_10.wake.1", agentID: "agent_10", event: .wake, text: "다시 왔어요. 필요한 일부터 챙겨볼게요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_10.idle.1", agentID: "agent_10", event: .idle, text: "기다리고 있어요. 도움이 필요하면 바로 말해주세요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_10.sleep.1", agentID: "agent_10", event: .sleep, text: "잠깐 조용히 있을게요. 곧 다시 도와드릴게요.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_10.appWillQuit.1", agentID: "agent_10", event: .appWillQuit, text: "오늘도 수고하셨어요. 다음에 반갑게 이어갈게요.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_10.taskCompleted.1", agentID: "agent_10", event: .taskCompleted, text: "필요한 도움을 마쳤어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_10.taskFailedRecoverable.1", agentID: "agent_10", event: .taskFailedRecoverable, text: "잠깐 다른 길로 가볼게요. 이어서 도와드릴 수 있어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_10.connectionNeeded.1", agentID: "agent_10", event: .connectionNeeded, text: "연결을 확인하면 더 정확히 도와드릴 수 있어요.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_10.validationSucceeded.1", agentID: "agent_10", event: .validationSucceeded, text: "확인됐어요. 이제 안심하고 이어갈 수 있어요.", priority: 20, isLeaderPreferred: false),

        .init(id: "agent_11.startup.1", agentID: "agent_11", event: .startup, text: "오늘 품질 기준부터 단단히 잡겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_11.wake.1", agentID: "agent_11", event: .wake, text: "다시 확인하겠습니다. 빠진 부분부터 보죠.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_11.idle.1", agentID: "agent_11", event: .idle, text: "검증이 필요하면 바로 체크하겠습니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_11.sleep.1", agentID: "agent_11", event: .sleep, text: "잠시 대기하겠습니다. 기준은 유지합니다.", priority: 10, isLeaderPreferred: false),
        .init(id: "agent_11.appWillQuit.1", agentID: "agent_11", event: .appWillQuit, text: "오늘 확인한 품질 기준은 남겨두겠습니다.", priority: 30, isLeaderPreferred: true),
        .init(id: "agent_11.taskCompleted.1", agentID: "agent_11", event: .taskCompleted, text: "검증 기준을 통과했습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_11.taskFailedRecoverable.1", agentID: "agent_11", event: .taskFailedRecoverable, text: "재확인이 필요합니다. 실패 원인부터 좁히겠습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_11.connectionNeeded.1", agentID: "agent_11", event: .connectionNeeded, text: "연결 확인 후에 검증을 진행할 수 있습니다.", priority: 20, isLeaderPreferred: false),
        .init(id: "agent_11.validationSucceeded.1", agentID: "agent_11", event: .validationSucceeded, text: "검증이 끝났습니다. 다음 단계로 갈 수 있습니다.", priority: 20, isLeaderPreferred: false)
    ]

    static func lines(for agentID: String, event: CharacterDialogueEvent) -> [CharacterDialogueLine] {
        let direct = eventDialogueLines
            .filter { $0.agentID == agentID && $0.event == event }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id < rhs.id
            }
        if !direct.isEmpty { return direct }
        return eventFallbackLines[event] ?? []
    }

    static func randomLine(for agentID: String, event: CharacterDialogueEvent) -> CharacterDialogueLine? {
        lines(for: agentID, event: event).randomElement()
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

    static func allEventDialogueLines(includeFallbacks: Bool = false) -> [CharacterDialogueLine] {
        guard includeFallbacks else { return eventDialogueLines }
        return eventDialogueLines + eventFallbackLines.values.flatMap { $0 }
    }
}
