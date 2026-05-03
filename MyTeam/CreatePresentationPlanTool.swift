import Foundation

// MARK: - CreatePresentationPlanTool
// PPT 슬라이드 초안을 JSON 파일로 저장한다.
// slides_json 형식: [{"title":"슬라이드1","content":"내용","notes":"발표자 노트"}]

struct CreatePresentationPlanTool: WorkflowTool {
    let name = "create_presentation_plan"
    let description = "PPT 슬라이드 초안을 JSON 파일로 저장한다"
    let riskLevel: ToolRiskLevel = .moderate
    let inputSchema: [String: String] = [
        "filename":    "저장할 파일명 (예: deck_plan.json)",
        "title":       "프레젠테이션 제목",
        "slides_json": "슬라이드 배열 JSON 문자열 (title/content/notes 필드)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename    = input["filename"],
              let title       = input["title"],
              let slidesJSON  = input["slides_json"] else {
            throw ToolError.invalidInput("filename, title, slides_json 필수")
        }

        // slides_json 유효성 검증
        guard let slidesData = slidesJSON.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: slidesData) else {
            throw ToolError.invalidInput("slides_json이 유효한 JSON이 아닙니다")
        }

        let wrapper: [String: Any] = ["title": title, "slides": slidesJSON]
        let outputJSON = try JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted)
        let url = try safeWorkspaceURL(filename: filename, context: context)
        try outputJSON.write(to: url)

        let summary = "PPT 초안 '\(title)' 생성 완료 → \(filename)"
        return ToolResult(success: true, output: summary, artifactPath: filename, error: nil)
    }
}
