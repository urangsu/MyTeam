# Privacy Nutrition Label Draft

## Data Collection Summary

MyTeam collects minimal data and prioritizes user privacy through local-first processing.

### Data Collected

| Data Type | Purpose | Collection Method |
|-----------|---------|-------------------|
| User Prompts | AI Processing | User Input |
| Selected Files | Document Processing | File Selection Dialog |
| Artifact Metadata | Document Management | Local Storage |
| Action Logs (Redacted) | Usage Analytics | Local Storage |
| Settings | User Preferences | Local Storage |

## Data NOT Collected / NOT Stored

### Explicitly Excluded
- Raw file contents in diagnostics
- API keys in application logs
- Auth codes/tokens in storage
- Email body content
- Calendar event details
- Contact information
- Browser history
- Application data from other apps

### Safety Measures
- API keys stored in Keychain only
- Auth tokens never persisted in UserDefaults
- Redacted action logs (tool name only, no input/output)
- No crash logs containing sensitive data

## Local Storage

### Stored Locally Only (No Cloud Sync)
- Artifact metadata (filename, creation date, type)
- Recent artifact index (file paths, hashes)
- Action logs (redacted summaries)
- Non-sensitive user settings
- First launch state
- Character preferences

### File Locations
- All data: `~/Library/Application Support/MyTeam/`
- TTS cache: `~/Library/Caches/qwen3-speech/` (app-controlled)
- UserDefaults: App sandbox container only

## Network Activity

### Data Sent to External Services

**When AI Feature is Enabled:**
- User prompts (text only)
- Request context (no file paths, no full contents)
- Destination: OpenAI, OpenRouter, or configured LLM provider

**When Calendar Connection is Enabled (Future):**
- Calendar event metadata (title, time, attendees)
- Read-only access only
- No modification of calendar events

**NOT Sent:**
- Local file paths
- File contents
- Artifact hashes
- Email data
- Device identifiers
- User identification data

### Data Transmission Security
- HTTPS only
- No unencrypted HTTP connections
- TLS 1.2+ required
- Certificate pinning where applicable

## Third-Party Services

### Integrated Services
- **LLM Providers** (OpenAI, OpenRouter, etc.): AI processing only when enabled
- **Google Calendar** (Future): Read-only event metadata
- **Google Gmail** (Not Yet Implemented): Planned for future, read-only metadata only

### Service Policies
- No data retention by MyTeam backend
- User data subject to provider's privacy policy
- Users can disconnect at any time
- No tracking or profiling

## User Controls

### Data Management
- Export local artifacts as files
- Clear all data option in Settings
- Delete individual artifacts
- Disable AI features
- Disconnect external connectors

### Transparency
- Runtime diagnostics show what data is processed
- No hidden background syncs
- Clear messaging when external services are used
- Opt-in for advanced features

## Data Retention

### Automatic Cleanup
- Redacted action logs: Retained for 30 days
- Temporary cache files: Auto-cleared on app exit
- Old artifact versions: Optional cleanup in Settings

### Manual Deletion
- Users can delete artifacts anytime
- Clear all data option available
- Export before deletion if needed

## Compliance

### Frameworks
- GDPR compliant (user data control)
- CCPA compliant (transparency and opt-out)
- macOS sandbox requirements met
- App Store guidelines satisfied

### Audit Trail
- No external logging service
- All logs local and user-accessible
- Redaction applied to sensitive data
- No analytics tracking

## Security Updates

This Privacy Nutrition Label will be updated if:
- New data collection practices are introduced
- Third-party integrations change
- Privacy features are enhanced
- Compliance requirements evolve

Last Updated: 2026-05-14
Version: Draft 1.0
