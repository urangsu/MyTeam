import Foundation

enum StarterActionPolicy: Sendable {
    static let allowedStarterActionIDs: Set<String> = [
        "starter_meeting_minutes",
        "starter_checklist",
        "starter_file_intake",
        "starter_schedule",
        "first_result_summary",
        "first_result_table",
        "first_result_checklist",
        "first_result_open_finder"
    ]

    static let blockedStarterActionIDs: Set<String> = [
        "starter_mail_send",
        "starter_calendar_write",
        "starter_file_delete",
        "starter_external_upload",
        "mailSend",
        "calendarWrite",
        "fileDelete",
        "externalUpload"
    ]

    static func isAllowedStarterActionID(_ id: String) -> Bool {
        return allowedStarterActionIDs.contains(id)
    }

    static func isBlockedStarterActionID(_ id: String) -> Bool {
        return blockedStarterActionIDs.contains(id)
    }

    static func isAllowed(_ actionID: String) -> Bool {
        return isAllowedStarterActionID(actionID) && !isBlockedStarterActionID(actionID)
    }

    static func isBlocked(_ actionID: String) -> Bool {
        return isBlockedStarterActionID(actionID)
    }
}
