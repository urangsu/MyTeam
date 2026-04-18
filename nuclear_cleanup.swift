import Foundation

let projectPath = "/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj/project.pbxproj"
guard let content = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
    print("Failed to read pbxproj")
    exit(1)
}

var lines = content.components(separatedBy: "\n")
var filteredLines: [String] = []

// Contents.json을 포함하고 리소스 빌드 단계에 있는 줄을 모두 필터링하여 삭제
for line in lines {
    if line.contains("Contents.json") && line.contains("in Resources") {
        print("Removing duplicate line: \(line.trimmingCharacters(in: .whitespaces))")
        continue
    }
    filteredLines.append(line)
}

let result = filteredLines.joined(separator: "\n")
try! result.write(toFile: projectPath, atomically: true, encoding: .utf8)

print("Nuclear cleanup of Contents.json references complete.")
