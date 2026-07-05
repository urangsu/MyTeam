#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    target = ROOT / path
    if not target.exists():
        raise SystemExit(f"FAIL: missing expected file: {path}")
    return target.read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_composer_contract() -> None:
    source = read("MyTeam/NaturalWorkRouting.swift")
    state_source = read("MyTeam/ToolExecutionState.swift")
    formatter_source = read("MyTeam/ToolResultFormatters.swift")
    required = [
        "## 한 줄 요약",
        "## 확인한 내용",
        "## 근거와 출처",
        "## 확인하지 못한 항목",
        "## 다음 행동",
        "## 고지",
    ]
    missing = [heading for heading in required if heading not in source]
    if missing:
        fail("NaturalResultComposer missing required headings: " + ", ".join(missing))
    if "sourceSummaryLines" not in source:
        fail("NaturalResultComposer must aggregate sources separately")
    if "nextActions" not in source:
        fail("NaturalResultComposer must promote missing-section actions into next actions")
    if "if !sourceLines.isEmpty" not in source:
        fail("NaturalResultComposer must render source section only when sources exist")
    if "if !nextActions.isEmpty" not in source:
        fail("NaturalResultComposer must render next-action section only when actions exist")
    if "case checkedEmpty" not in state_source:
        fail("ToolExecutionState must include checkedEmpty for successful requests with no results")
    if "case .checkedEmpty" not in source:
        fail("NaturalResultComposer must route checkedEmpty into missing/empty-result handling")
    no_results_index = formatter_source.find("nonisolated static func noResultsState")
    if no_results_index == -1:
        fail("ToolResultFormatters must define noResultsState")
    no_results_window = formatter_source[no_results_index:no_results_index + 800]
    if ".succeeded(" in no_results_window:
        fail("noResultsState must not return .succeeded")
    if ".checkedEmpty(" not in no_results_window:
        fail("noResultsState must return .checkedEmpty")


def validate_finance_language() -> None:
    source = read("MyTeam/ToolResultFormatters.swift")
    finance = source[source.find("enum FinanceResultFormatter"):]
    finance = finance[: finance.find("enum LawResultFormatter")]

    forbidden_patterns = [
        r"실시간\s*현재가",
        r"현재가",
        r"매수\s*추천",
        r"매도\s*추천",
        r"투자\s*추천",
        r"재무\s*판단\s*완료",
    ]
    for pattern in forbidden_patterns:
        if re.search(pattern, finance):
            fail(f"Finance formatter contains forbidden wording: {pattern}")
    for required in [
        "기준일 공공데이터",
        "실시간 시세가 아닙니다",
        "투자 조언이 아닙니다",
        "사업연도",
        "당기금액",
    ]:
        if required not in finance:
            fail(f"Finance formatter missing required wording: {required}")


def validate_news_language() -> None:
    source = read("MyTeam/ToolResultFormatters.swift")
    news = source[source.find("enum NewsResultFormatter"):]
    news = news[: news.find("enum WeatherResultFormatter")]
    for forbidden in ["기사 전문 요약", "기사 전문을 요약", "원문을 읽고 요약"]:
        if forbidden in news:
            fail(f"News formatter contains forbidden wording: {forbidden}")
    for required in ["제목과 설명", "원문 링크", "공통 이슈 후보", "확인할 점"]:
        if required not in news:
            fail(f"News formatter missing required wording: {required}")


def validate_law_language() -> None:
    source = read("MyTeam/ToolResultFormatters.swift")
    law = source[source.find("enum LawResultFormatter"):]
    forbidden_patterns = [
        r"(?<!아닌\s)법률 자문입니다",
        r"법적 결론",
        r"위법입니다",
        r"합법입니다",
    ]
    for pattern in forbidden_patterns:
        if re.search(pattern, law):
            fail(f"Law formatter contains forbidden wording: {pattern}")
    for required in ["공식 출처", "시행일", "검증 상태", "전문가 검토"]:
        if required not in law:
            fail(f"Law formatter missing required wording: {required}")


def validate_google_sheets_language() -> None:
    source = read("MyTeam/ToolResultFormatters.swift") + read("MyTeam/ToolRunners/GoogleSheetsToolRunner.swift")
    for forbidden in ["수정했습니다", "입력했습니다", "검산 완료", "파일 수정 완료"]:
        if forbidden in source:
            fail(f"Google Sheets/result formatter contains forbidden write wording: {forbidden}")
    for required in ["읽기 전용", "범위", "행", "열", "미리보기"]:
        if required not in source:
            fail(f"Google Sheets formatter missing required wording: {required}")

    runtime_source = "\n".join([
        read("MyTeam/GoogleSheetsClient.swift"),
        read("MyTeam/ToolRunners/GoogleSheetsToolRunner.swift"),
        read("MyTeam/ToolRunners/GoogleRunnerSupport.swift"),
        read("MyTeam/ToolExecutionRouter.swift"),
    ])
    forbidden_runtime_patterns = [
        r"batchUpdate",
        r"values\.update",
        r"values\.append",
        r"values\.clear",
        r"values:append",
        r"values:update",
        r"values:clear",
        r"httpMethod\s*=\s*\"POST\"",
        r"httpMethod\s*=\s*\"PUT\"",
        r"httpMethod\s*=\s*\"PATCH\"",
        r"httpMethod\s*=\s*\"DELETE\"",
    ]
    for pattern in forbidden_runtime_patterns:
        if re.search(pattern, runtime_source):
            fail(f"Google Sheets runtime contains non-read-only capability: {pattern}")


def validate_weather_language() -> None:
    source = read("MyTeam/ToolResultFormatters.swift")
    weather = source[source.find("enum WeatherResultFormatter"):]
    weather = weather[: weather.find("enum FinanceResultFormatter")]
    for required in ["기상청 격자", "발표 기준", "확인된 기상 정보", "업무 영향 추정", "위치 좌표 기준"]:
        if required not in weather:
            fail(f"Weather formatter missing required wording: {required}")
    for forbidden in ["영향 있음", "일정 조정 필요"]:
        if forbidden in weather:
            fail(f"Weather formatter contains over-certain impact wording: {forbidden}")


def validate_action_ids() -> None:
    card = read("MyTeam/ToolResultCardView.swift")
    formatter = read("MyTeam/ToolResultFormatters.swift")
    produced = set(re.findall(r'MyTeamNextAction\s*\(\s*id:\s*"([^"]+)"', formatter))
    enabled = set(re.findall(r'"([^"]+)"', card))
    missing = sorted(produced - enabled)
    if missing:
        fail("ToolResultCardView does not enable formatter action ids: " + ", ".join(missing))


def main() -> None:
    validate_composer_contract()
    validate_finance_language()
    validate_news_language()
    validate_law_language()
    validate_google_sheets_language()
    validate_weather_language()
    validate_action_ids()
    print("PASS: result presentation validation")


if __name__ == "__main__":
    main()
