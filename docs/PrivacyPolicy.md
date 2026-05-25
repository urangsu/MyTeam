# MyTeam Privacy Policy

**Effective Date:** May 25, 2026  
**Last Updated:** May 25, 2026

## Overview

MyTeam is a macOS productivity app designed to help users create documents, organize files, and manage tasks. This Privacy Policy explains how we handle your data.

**Key Principle:** MyTeam respects your privacy. We store nothing on our servers and use only local processing where possible.

---

## 1. What Data We Collect

### Local Features (No Data Collection)
The following features process data entirely on your Mac and do not require an internet connection:

- **Document Creation**: Meeting minutes, checklists, reports → stored locally in ~/Library/Application Support/MyTeam/
- **File Organization**: Reading and analyzing files you select → processed locally, not uploaded
- **Today's Briefing**: Local task lists and calendar view → processed locally
- **Artifact Management**: Document storage, file operations → local workspace only

**What we do NOT collect for local features:**
- No usage analytics
- No document content
- No file metadata
- No diagnostic logs containing your text

### Optional AI Features (Data Sent to Your Chosen Provider)
If you enable AI features by adding an API key, selected text or files are sent to the provider you choose:

- **Claude API** (Anthropic) — Use your own API key
- **OpenAI API** (OpenAI) — Use your own API key  
- **Gemini API** (Google) — Use your own API key
- **OpenRouter API** (OpenRouter) — Use your own API key

**What we send:**
- Only the text/content you explicitly request analysis for
- NOT your full document library
- NOT metadata about your files
- NOT your API key (stays in Keychain)

**What we do NOT send:**
- Your browsing history
- Your file system structure
- Your personal information
- Your settings or preferences

### Optional Connectors (Minimal Data)
If you connect external services:

- **Google Calendar** (read-only)
  - Scope: `calendar.readonly` (view calendar events only)
  - We retrieve: Event titles, times, attendees
  - We do NOT: Modify events, create events, delete events
  - Storage: Not stored on our servers (shown in app, then forgotten)

- **Gmail** (planned, not yet available)
  - When released: metadata only (sender, subject, date)
  - Never: Full email content, attachments

---

## 2. How We Store Your Data

### On Your Mac
- **API Keys**: Stored in macOS Keychain (encrypted)
- **Documents**: ~/Library/Application Support/MyTeam/ (you control)
- **Settings**: macOS UserDefaults (local, not synced)

**You can delete everything:**
```bash
rm -rf ~/Library/Application\ Support/MyTeam/
rm -rf ~/Library/Preferences/com.google.antigravity.MyTeam.plist
```

### NOT On Our Servers
- We do NOT store documents
- We do NOT store file contents
- We do NOT store API keys
- We do NOT have a cloud backup
- We do NOT have accounts/login system

---

## 3. Who Can Access Your Data

### You Control Access
- Documents stored locally → only you can read
- API keys in Keychain → only your user account can access
- External APIs → only when you explicitly request

### Third Parties
- **AI Provider** (Claude/OpenAI/Gemini): Sees only the text you send for analysis
- **Google**: Sees only calendar events (read-only)
- **MyTeam Team**: No access to your documents or data

---

## 4. Data Security

### Encryption
- **API Keys**: Stored encrypted in macOS Keychain
- **Passwords**: Never stored (users provide credentials via OAuth)
- **Network**: All external API calls use HTTPS

### No Tracking
- No advertisement pixels
- No analytics libraries
- No telemetry
- No crash reporters
- No session tracking

### Sandbox Protection
- App runs in macOS App Sandbox
- Limited file access (workspace directory only)
- Limited network access (Claude/OpenAI/Gemini APIs only)
- No system-wide file access

---

## 5. Data Retention & Deletion

### How Long We Keep Data
- **Local documents**: As long as you keep them
- **Settings/preferences**: Until you delete the app
- **API keys**: Until you remove them from Keychain
- **Temporary cache**: Cleared on app exit (no persistence)

### How to Delete Your Data
1. **Delete Documents**: Finder → ~/Library/Application Support/MyTeam/ → delete files
2. **Delete API Keys**: Settings → "Clear Keychain" button (if available)
3. **Full Reset**: Delete entire MyTeam folder + app preferences

---

## 6. What We DON'T Do

✅ **Explicitly Blocked:**
- No automatic email sending
- No automatic calendar event creation
- No automatic file deletion
- No automatic external uploads
- No auto-sync to cloud services

✅ **We Never:**
- Sell your data
- Share your documents with third parties
- Run analytics on your content
- Store your API keys on our servers
- Create user accounts or profiles
- Require login or authentication

---

## 7. Children's Privacy

MyTeam is not directed to users under 13. We do not knowingly collect personal information from children. If we become aware of such collection, we will delete it immediately.

---

## 8. Changes to This Policy

We may update this policy to reflect changes in our practices or legal requirements. We will notify you of material changes by posting the updated policy with a new effective date.

---

## 9. Contact & Questions

For privacy questions, contact: **gustn3031@gmail.com**

---

## 10. CCPA & International Compliance

### California (CCPA)
- You have the right to know what data we collect (we collect none)
- You have the right to delete your data (delete locally on your Mac)
- You have the right to opt out of "selling" data (we don't sell)
- We provide no data retention beyond local files

### GDPR (EU)
- Your data is stored locally (you are the controller)
- We do not transfer data internationally
- You have the right to access, correct, delete (all local)
- We have no legal basis to retain your data

### Japan (APPI)
- Personal information handled only when you explicitly share it
- No cross-border data transfer (data stays on your Mac)
- Retention period: Only while you keep the app

---

## Summary Table

| Feature | Data Stored | Where | Encrypted | Can Delete |
|---------|-------------|-------|-----------|-----------|
| Documents | Local files | Your Mac | File system | ✅ Yes |
| API Keys | Keychain | Your Mac | ✅ Yes | ✅ Yes |
| Settings | UserDefaults | Your Mac | No | ✅ Yes |
| AI Requests | Sent to provider | Provider's servers | ✅ Yes | Provider policy |
| Calendar (optional) | Not stored | Live query | ✅ Yes (HTTPS) | N/A (read-only) |
| Crash reports | None | — | — | — |
| Analytics | None | — | — | — |
| User accounts | None | — | — | — |

---

**Last reviewed:** 2026-05-25  
**Status:** Ready for App Store submission
