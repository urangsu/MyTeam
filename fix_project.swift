import Foundation

let projectPath = "/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj/project.pbxproj"
guard let content = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
    print("Failed to read pbxproj at \(projectPath)")
    exit(1)
}

var lines = content.components(separatedBy: "\n")
var newLines: [String] = []
var seenBuildFiles = Set<String>()
var inSourcesBuildPhase = false

let buildFileRegex = try! NSRegularExpression(pattern: "/\\* (.+) in Sources \\*/", options: [])

for line in lines {
    if line.contains("PBXSourcesBuildPhase") {
        inSourcesBuildPhase = true
        newLines.append(line)
        continue
    }
    
    if inSourcesBuildPhase && line.contains(");") {
        inSourcesBuildPhase = false
        newLines.append(line)
        continue
    }
    
    if inSourcesBuildPhase {
        let range = NSRange(location: 0, length: line.utf16.count)
        if let match = buildFileRegex.firstMatch(in: line, options: [], range: range) {
            let fileName = (line as NSString).substring(with: match.range(at: 1))
            if seenBuildFiles.contains(fileName) {
                print("Removing duplicate build file entry for \(fileName)")
                continue // Skip this line
            }
            seenBuildFiles.insert(fileName)
        }
    }
    
    newLines.append(line)
}

try! newLines.joined(separator: "\n").write(toFile: projectPath, atomically: true, encoding: .utf8)
print("Finished cleaning duplicates")
