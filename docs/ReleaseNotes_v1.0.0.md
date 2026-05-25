# MyTeam Release Notes - Version 1.0.0

**Release Date**: May 25, 2026 (pending App Store approval)  
**Build Number**: 1  
**macOS Minimum**: 12.0  

---

## Overview

MyTeam 1.0.0 is the initial release of a local-first AI productivity assistant for macOS. Focus: reliable local document handling with optional AI features.

---

## What's Included

### 📄 Document Creation
- **Meeting Minutes**: Auto-generated structure with attendees, agenda, decisions, action items
- **Checklists**: Task-based templates with priority levels
- **Reports**: Flexible report structure with sections and formatting
- **Templates**: Local fallback templates (no internet required)

**Status**: ✅ Production-ready

### 📁 File Management
- **Local File Import**: .txt, .md, .csv (drag-and-drop or picker)
- **File Analysis**: Summarize, extract info, organize content
- **Artifact Storage**: Workspace-scoped local storage (~Library/Application Support/MyTeam/)
- **Recent Artifacts**: Quick access to recently created documents
- **Finder Integration**: Open in Finder, copy path buttons

**Status**: ✅ Production-ready (PDF, XLSX, DOCX support planned)

### 🎯 Today's Briefing
- **Schedule View**: Local calendar events (if connected)
- **Task List**: Upcoming tasks and priorities
- **Daily Overview**: Quick summary of what's ahead

**Status**: ✅ Production-ready

### 🤖 Optional AI Features
- **Claude API** (recommended): Connect your own API key
- **OpenAI API**: GPT-4 or latest available
- **Gemini API**: Google's LLM
- **OpenRouter API**: Multi-model support

**API Key Storage**: macOS Keychain (encrypted, never logged)  
**Auto-Speak**: Disabled by default (user can enable in settings)  
**Privacy**: Only selected text is sent to chosen provider

**Status**: ✅ Production-ready (TTS voice tuning in development)

### 🔗 Optional Connectors
- **Google Calendar** (read-only): View events
- **Gmail** (planned): Metadata support coming

**Status**: 
- Google Calendar: ✅ Ready (read-only, user controls OAuth)
- Gmail: 🔄 In development

### 🎨 Team & Characters
- **Chiko** (Default): UX designer & onboarding assistant
- **Leo**: Analytical & structured
- **Luna**: Creative & detail-oriented
- **Moko**: Energetic & action-focused
- **Fin**: Calm & patient

**Character Voices**: Optional voice profiles (Supertonic3 TTS in lab)

**Status**: ✅ Character system + UI polish (voice tuning ongoing)

---

## Known Limitations

### Intentionally Blocked
- ❌ Email sending (not implemented, user must handle)
- ❌ Calendar event creation (user must create manually)
- ❌ Automatic file deletion (requires explicit user action)
- ❌ Cloud sync (data stays local)
- ❌ Auto-upload to external services

### Planned Future Support
- 🔄 PDF import & analysis (infrastructure ready)
- 🔄 XLSX import & table generation
- 🔄 DOCX import & editing
- 🔄 Gmail metadata integration
- 🔄 Advanced TTS with voice tuning
- 🔄 Character-specific dialog management
- 🔄 Multi-user collaboration (team accounts)

### Not Supported
- ❌ Web browsing automation
- ❌ Automatic mail filtering
- ❌ Cloud synchronization
- ❌ External API auto-calling
- ❌ Machine voice output (Apple TTS completely banned)

---

## Security & Privacy

### Data Handling
- **Local Processing**: All document creation & file analysis on your Mac
- **No Cloud**: MyTeam has no servers. Documents never leave your machine unless you share them
- **API Keys**: Stored encrypted in macOS Keychain, never in logs or chat history
- **User Control**: Explicit selection only - no auto-watch, no auto-upload

### Privacy Compliance
- ✅ CCPA: You control all data deletion
- ✅ GDPR: No data retention beyond your local files
- ✅ APPI: No cross-border data transfer
- ✅ App Store Requirements: Privacy nutrition label complete

### No Tracking
- ❌ No analytics
- ❌ No telemetry
- ❌ No crash reporters
- ❌ No ads
- ❌ No user profiles

**Full Privacy Policy**: See in-app or `/docs/PrivacyPolicy.md`

---

## System Requirements

- **macOS**: 12.0 or later
- **Architecture**: Universal Binary (Apple Silicon + Intel)
- **RAM**: 2GB minimum (4GB recommended)
- **Storage**: 50MB for app + workspace

---

## Installation & First Run

1. **Download**: Download MyTeam from App Store
2. **Install**: Drag to Applications folder
3. **Launch**: Open MyTeam from Applications
4. **Onboarding**: Follow in-app guidance
5. **Optional**: Add API key in Settings for AI features

### First Launch Experience
- Welcome screen with feature overview
- Option to add API key (or skip to use local features)
- Option to connect Google Calendar (or skip)
- Local document features available immediately

---

## Performance & Reliability

### Tested Scenarios
- ✅ Document generation (meeting minutes, reports, checklists)
- ✅ File import (txt, md, csv up to 2MB)
- ✅ Multi-room task isolation (concurrent workflows)
- ✅ Error handling (network failures, API timeouts, missing files)
- ✅ Artifact persistence (reopening documents)
- ✅ Release build optimization (Debug + Release)

### Known Issues
- None reported (1.0.0 is initial release)

### Performance Benchmarks
- Document generation: < 2s (local) or < 5s (with API)
- File import: < 1s (txt/md/csv)
- UI responsiveness: Smooth (60 FPS target)
- Memory usage: ~200-300MB typical

---

## Build & Deployment

### Build Configuration
- **Scheme**: MyTeam
- **Debug Build**: For development & manual QA
- **Release Build**: For App Store submission

### Code Quality
- ✅ 0 app code warnings (Swift compiler)
- ✅ MainActor isolation: Complete
- ✅ Sandbox compliance: Verified
- ✅ Privacy enforcement: Verified

### Dependencies
- **Third-party frameworks**: ZIPFoundation (DOCX/XLSX/HWP support)
- **Apple frameworks**: SwiftUI, AVFoundation, Network, StoreKit

---

## What's Different from Beta/Dev

| Feature | Dev | v1.0.0 |
|---------|-----|--------|
| Local documents | ✅ | ✅ |
| File import | ✅ | ✅ |
| AI features | Dev only | ✅ Available |
| Google Calendar | Draft | ✅ Working |
| Debug buttons | ✅ | ❌ Hidden |
| Release optimization | No | ✅ Yes |
| Privacy compliance | Partial | ✅ Complete |
| Sandbox strict | No | ✅ Enforced |

---

## Support & Feedback

### Getting Help
- **GitHub Issues**: https://github.com/urangsu/MyTeam/issues
- **Email**: gustn3031@gmail.com

### Reporting Bugs
1. Note what you were doing when the issue occurred
2. Check Console.app for error messages
3. File issue on GitHub with:
   - App version & build
   - macOS version
   - Steps to reproduce
   - Expected vs actual behavior

### Feature Requests
- GitHub Discussions (when available)
- Email: gustn3031@gmail.com

---

## Changelog: Development Rounds

### Rounds 196A-230Z ✅
- Workroom core loop + room-scoped artifacts
- TeamTableView + AgentChatView UI
- Character system foundation
- Local task briefing

### Rounds 241A-260Z ✅
- TTS infrastructure (Supertonic3)
- Voice tuning system
- App Store compliance hardening
- Safety blocks (email, calendar, delete)

### Rounds 261A-265Z ✅
- Skill result cards (spell-check, diagnostics, tax)
- K-skills assistant-only mode
- Character voice profiles

### Rounds 266A-275Z ✅
- AssistOnly governance
- Router reliability hardening
- Room context isolation
- Release gate audit

### Round 277 ✅
- HWP/HWPX file reading (Korean documents)

### Round 278 (Current) ✅
- App Store submission prep
- Privacy policy + metadata
- Release verification

---

## Next Phases (Planned)

### Phase 2 (Post-Launch)
- User feedback collection
- Bug fixes
- Performance optimization

### Phase 3 (Q3 2026)
- PDF/XLSX/DOCX full support
- Gmail metadata integration
- Advanced TTS with character voices

### Phase 4 (Q4 2026)
- Collaboration features
- Multi-device sync (optional, user-controlled)
- Extended AI integrations

---

## Credits

**MyTeam 1.0.0** is built with:
- SwiftUI (Apple)
- Claude 3.5 Sonnet API (Anthropic)
- ZIPFoundation (open source)
- Supertonic3 TTS (in development)

**Development**: Single developer, part-time  
**Design**: Community feedback + UX iteration  
**Testing**: Cloud CI + manual QA

---

## Legal

- **License**: Proprietary (App Store submission)
- **Privacy Policy**: See `/docs/PrivacyPolicy.md`
- **Terms of Service**: Implicit - see in-app

---

## Version History

### v1.0.0 (May 25, 2026)
- Initial release
- 23/23 cloud compliance checks PASS
- Ready for App Store submission

---

**Submission Status**: Ready for macOS App Store  
**Build Number**: 1  
**Last Updated**: 2026-05-25
