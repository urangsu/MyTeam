import Foundation

// MARK: - CreatePresentationPlanTool
// PPT 슬라이드 초안을 JSON 파일로 저장한다.
// slides_json 형식: [{"title":"슬라이드1","content":"내용","notes":"발표자 노트"}]
// 출력: {"format":"pptx-plan-v1","title":"...","slides":[{...}]} — PPTXWriter가 바로 읽는 구조

struct CreatePresentationPlanTool: WorkflowTool {
    let name = "create_presentation_plan"
    let description = "PPT 슬라이드 초안을 JSON 파일로 저장한다 (PPTXWriter 호환 구조)"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
    let inputSchema: [String: String] = [
        "filename":    "저장할 파일명 (예: deck_plan.json)",
        "title":       "프레젠테이션 제목",
        "slides_json": "슬라이드 배열 JSON 문자열 (title/content/notes 필드)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename   = input["filename"],
              let title      = input["title"],
              let slidesJSON = input["slides_json"] else {
            throw ToolError.invalidInput("filename, title, slides_json 필수")
        }

        // slides_json 파싱 — JSON string이 아니라 실제 객체로 저장
        guard let slidesData = slidesJSON.data(using: .utf8),
              let slidesArray = try? JSONSerialization.jsonObject(with: slidesData) as? [[String: Any]] else {
            throw ToolError.invalidInput("slides_json이 유효한 JSON 배열이 아닙니다 (예: [{\"title\":\"...\",\"content\":\"...\"}])")
        }

        let wrapper: [String: Any] = [
            "format": "pptx-plan-v1",
            "title": title,
            "slideCount": slidesArray.count,
            "slides": slidesArray
        ]
        let outputJSON = try JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
        let url = try safeWorkspaceURL(filename: filename, context: context)
        try outputJSON.write(to: url)

        let preview = "PPT 초안 '\(title)' — \(slidesArray.count)슬라이드 생성 완료"
        return ToolResult(success: true, output: preview, artifactPath: filename, error: nil)
    }
}
