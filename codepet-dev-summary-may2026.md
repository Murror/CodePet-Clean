# Codepet — Development Summary

**Period:** April 1 – May 27, 2026
**Contributors:** dominich (97 commits), Mona (3 commits)
**Total commits:** ~100 across `main` and `feat/refactor-core`

---

## Reflection System — The Big One

The entire Reflection feature was designed, built, and shipped from scratch this month. It's the system that watches what users build in Claude Code and tells them what they just did in plain language — like a coding journal that writes itself.

### Core Pipeline (May 5)

- **Event capture:** Claude Code hooks log every tool use (edits, bash commands, file writes) into `events.jsonl` on disk
- **TurnAssembler:** Groups raw events into logical "turns" — one turn = one prompt + whatever Claude did in response. Uses 30-minute idle boundaries and Stop signals to know when a turn ends
- **NarrativeStore:** Polls `narratives.jsonl` and exposes a `[turnId: Narrative]` dictionary the UI can bind to
- **NarrativeEnricher:** Serial queue that sends turns to Claude Haiku for summarization. Handles retry on network errors, skips on quota/auth failures
- **ReflectionAPIClient:** Authenticated HTTP client using Firebase ID tokens to call the Cloud Functions

### Cloud Functions Backend (May 5)

- **summarizeTurn:** Firebase-authed endpoint that takes a turn's events and returns a narrative summary via Claude Haiku tool-use
- **Auth middleware:** Validates Firebase ID tokens
- **Rate limiter:** 50 turns/day/user via Firestore counter
- **Idempotency cache:** Keyed by `uid+turnId`, 7-day TTL — avoids re-summarizing the same turn
- **Anthropic integration:** System prompt + tool-use schema that forces structured output (title, whatYouWanted, whatHappened, lesson, nextSteps, mood)

### Narrative UI (May 5)

- **ReflectionTab:** Full-featured sidebar + detail view. Sidebar groups sessions by day, detail shows chat-style narrative with pet avatar
- **NarrativeBodyView:** 3-section layout rendering whatYouWanted, whatHappened, and lesson fields
- **TurnLoadingStates:** Visual states for pending, summarizing, failed, and orphan turns
- **TechnicalDetailsView:** Collapsible raw prompt + event list for power users
- **Chat-style layout:** Switched from card-based to conversation-style with pet avatars speaking to the user
- **Pet persona voice:** Each pet (Byte, Luna, Nova, etc.) speaks in their own voice — persona data passed to Claude Haiku

### Streaming (completed tasks #31–#36)

- Added SSE streaming to both `summarizeTurn` and `summarizeSession` Cloud Functions
- Built `summarizeTurnStream` and `summarizeSessionStream` on the Swift client
- Updated NarrativeEnricher and SessionSummaryEnricher to consume streams
- UI shows real-time narrative generation as it streams in

### Session Summaries & Project Intelligence

- **SessionSummaryEnricher:** Auto-summarizes sessions when they end or go idle for 30+ minutes
- **Project detection:** `ProjectStore` groups sessions by project root (resolves symlinks, detects git roots)
- **Project brief with auto-update:** Each project gets a brief card with:
  - A description that auto-updates on session end (`project_overview` field)
  - An activity log that appends changelog entries (`brief_update` field)
- **Inline edit:** Users can manually edit the project brief too
- **Sidebar grouped by project:** Sessions organized under their project in the sidebar

### Prompt Quality Iterations

- Rewrote narrative prompt for 12-year-old reading level — every technical term gets an inline explanation
- Added teaching emphasis: lesson field teaches a real coding concept, not just a compliment
- Added `next_steps` field with actionable advice
- Added `mood` field so the pet avatar reacts with matching animations
- Made `project_overview` tone casual and conversational ("You're building..." instead of dry noun phrases)

### Smart Filtering (May 26)

- Skip narrative generation for empty turns (no tool events at all)
- Skip narrative generation for read-only turns (only `git status`, `ls`, `git log` — no actual edits)
- `hasMeaningfulWork` property on Session/Turn to gate summarization
- Fixed pending turns showing as blank text instead of "Working..." loading card

---

## Session Chat (May 7–8)

Built a full chat feature where users can talk to their pet about the coding session they just had.

- **ChatMessage + SessionChatThread models** with disk persistence per session
- **SessionChatStore:** Disk-backed, per-session isolation, safe for off-main-actor writes
- **chatSession Cloud Function:** SSE streaming endpoint with system prompt that knows the session context
- **SSE parser:** Custom byte-level parser (replaced `bytes.lines` which broke on partial chunks)
- **SessionChatController:** Manages send, stream, and cancel state
- **SessionChatBubble:** Floating pet avatar button that opens the chat panel
- **SessionChatPanel:** Full chat UI with streaming message bubbles, input field, auto-scroll
- **Pixel-chrome styling:** Chat bubble and panel styled to match code-pet.com aesthetic

---

## Demo Mode — "Sprout × Byte" (May 12–14)

A hardcoded demo that simulates a full Codepet session for presentations and investor pitches.

- **DemoScriptController:** State machine that walks through 5 milestones of a fictional "Sprout" coding project
- **DemoHotkeyMonitor:** ⌥1 through ⌥5 advance milestones, ⌥0 panic-skips to end
- **DemoReflectionView:** Custom view with sidebar milestones and typewriter text animation
- **DemoMilestoneCard + DemoTypewriterText:** Reusable demo components
- Reuses production Reflection UI instead of a separate view (switched mid-sprint)
- Byte's voice rewritten with concrete technical insight per milestone — not generic hype
- Content rewritten for 12-year-old audience
- Localized to both Vietnamese and English with language toggle in Profile
- Health-nudge modals added for demo polish
- Debug section in Profile to toggle demo mode on/off

---

## App Architecture Changes

### Character Update (May 11)
- Removed "Zero" character — app now has 7 pets: Byte, Nova, Crash, Luna, Sage, Glitch, Null
- Added Dictionary tab to main navigation
- Switched to Inter font for body text

### Auth & Onboarding (May 8)
- Removed the full onboarding flow — users go straight from sign-in to MainTabView
- Wired `onOpenURL` for Google Sign-In OAuth callback
- Added Account section in Profile showing sign-in status

### Pixel Font System (May 8)
- Bundled Minecraft pixel font
- Auto-registers on first `Font.pixel` call
- Global pixel-font flag routes all `.font(.system(size:))` calls through it
- Applied to Reflection sidebar, chat header, and pet names

### Performance Fixes (completed tasks #23–#26)
- Fixed `ReflectionEventStore` publishing on every poll even when nothing changed
- Cached `allTurns`, `allSessions`, `groupedByProject` in ReflectionTab
- Fixed `NarrativeStore` unnecessary publishing
- Result: dramatically reduced SwiftUI re-renders

---

## Earlier Work (April)

### Initial App (Apr 1–6)
- Initial commit with full SwiftUI app structure
- Sessions platformer redesign with zigzag layout and character animations
- Bundle ID set to `app.murror.codepet`

### Insights Tab (Apr 7)
- 6-card dashboard: XP Progress, Streak, Skills Mastered, Weekly Activity, Recent Performance, Tier Progress
- Each card has Fun mode and Detail mode toggle
- DailySnapshot model persisted via UserDefaults

### Systems Thinking (Apr 8)
- Feedback loops, resilience, and active traps insight cards
- Systems thinking extension on AppState

### VS Code Extension + MCP Server (Apr 11)
- Codepet VS Code extension for event capture
- MCP server for Claude Code integration
- Install guides for both

### Lesson Feed (Apr 13)
- Post-session knowledge capture with pet narration

---

## What's Next

- Deploy the updated `summarizeSession` Cloud Function with `project_overview` field
- Push latest Swift changes (git HEAD.lock needs clearing)
- End-to-end test of project overview auto-update
- Continue refining narrative quality and pet voice
