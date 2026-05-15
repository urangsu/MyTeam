# Connector Policy Audit

⚠️ **FOUND**: External write tools detected
```
MyTeam/RouterBurnInSuite.swift:576:            notes: "mailSend blocked"
MyTeam/RouterBurnInSuite.swift:1473:            expectedGoalType: "externalUpload",
MyTeam/RouterBurnInSuite.swift:1483:            expectedGoalType: "calendarWrite",
MyTeam/RouterBurnInSuite.swift:1493:            expectedGoalType: "mailSend",
MyTeam/StarterActionPolicy.swift:20:        "mailSend",
MyTeam/StarterActionPolicy.swift:21:        "calendarWrite",
MyTeam/StarterActionPolicy.swift:23:        "externalUpload"
MyTeam/ConnectorCapabilityPolicy.swift:39:        case .mailSend, .calendarCreate, .calendarModify, .destructiveFileAction, .automaticLogin:
MyTeam/ConnectorCapabilityPolicy.swift:74:        case .sendEmail: return .mailSend
MyTeam/AssistantCapability.swift:14:    case mailSend
MyTeam/AssistantCapability.swift:40:        case .mailSend: return "메일 발송"
MyTeam/AssistantCapability.swift:57:        case .mailSend, .calendarCreate, .calendarModify, .destructiveFileAction, .automaticLogin:
MyTeam/ConnectorSurfacePolicy.swift:7:    case externalUpload = "externalUpload"
MyTeam/ConnectorSurfacePolicy.swift:12:    static let blockedCapabilitiesInRelease: Set<ConnectorCapability> = [.calendar, .mail, .externalUpload, .fileDelete]
MyTeam/ConnectorSurfacePolicy.swift:20:        case .calendar, .mail, .externalUpload, .fileDelete:
MyTeam/GoalInterpreter.swift:77:        if containsAny(lower, keywords: mailSendKeywords) {
MyTeam/GoalInterpreter.swift:83:                capabilities: [.mailDraft, .mailSend],
MyTeam/GoalInterpreter.swift:247:    private static let mailSendKeywords = [
```
