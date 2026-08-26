# FixMySpine Implementation Plan

> Generated: August 2026  
> Current Version: v4.4.0

---

## Overview

This document outlines planned feature enhancements for FixMySpine, a macOS menu bar app that uses AirPods motion sensors for real-time posture tracking. The plan prioritizes high-value, achievable additions that align with the app's privacy-first, local-processing philosophy.

---

## Prioritized Feature List

### Tier 1: Quick Wins (Low Effort, High Impact)

| # | Feature | Description | Files to Modify |
|---|---------|-------------|-----------------|
| 1 | **Session Pause / Resume** | Add pause functionality so users can step away without stopping tracking or losing streaks | `main.swift` |
| 2 | **Focus Mode Integration** | Auto-suppress reminders when macOS Focus/DND is active | `main.swift` |
| 3 | **Audio Device Display** | Show which AirPods model is connected (Pro, Max, 3rd Gen, etc.) | `main.swift` |
| 4 | **Configurable Streak Thresholds** | Make 30s "great posture" streak adjustable in Settings | `main.swift` |

### Tier 2: Analytics & Data (Medium Effort, Medium Impact)

| # | Feature | Description | Files to Modify |
|---|---------|-------------|-----------------|
| 5 | **Hourly Posture Heatmap** | Break down slouch data by hour of day for actionable insights | `main.swift` |
| 6 | **CSV/JSON Export** | One-click export of posture history for sharing with physio or analysis | `main.swift` |

### Tier 3: Wellness Features (Medium Effort, Different Value)

| # | Feature | Description | Files to Modify |
|---|---------|-------------|-----------------|
| 7 | **Break Reminders** | Stand-up-and-move reminders independent of posture alerts | `main.swift` |
| 8 | **Onboarding Flow** | First-launch tutorial explaining audio requirement for CoreMotion | `main.swift` |

---

## Detailed Specifications

### Feature 1: Session Pause / Resume

**Objective:**
Allow users to temporarily pause posture tracking without stopping the app or losing current session statistics.

**Implementation:**
- Add `isPaused` boolean flag to `PostureMonitor`
- Add Pause/Resume button to the menu bar popover UI
- When paused: stop voice notifications, haptic alerts, and history recording
- Preserve current streak timers during pause
- Show "PAUSED" indicator in the gauge view

**UI Changes:**
- Add pause icon (pause.fill / play.fill) in the status bar
- Show "Pause Tracking" / "Resume Tracking" menu item

**Demo:**
User clicks pause icon → gauge shows "PAUSED" overlay → all alerts suppressed → clicking resume restores full tracking without recalibration

---

### Feature 2: Focus Mode Integration

**Objective:**
Automatically suppress all reminders (voice + notifications) when macOS Focus/DND is active.

**Implementation:**
- Use `NSWorkspace.didChangeNotification` to observe Focus state
- Or poll `NSDistributedNotificationCenter` for Focus changes
- Check `UNUserNotificationCenter.current().getNotificationSettings()` for DND state
- Add `focusModeActive` computed property to `PostureMonitor`
- Gate voice reminders and notifications behind: `!focusModeActive`

**Edge Cases:**
- Handle rapid focus toggling
- Persist user override: "Always notify regardless of Focus"

**Demo:**
User enables macOS "Do Not Disturb" → FixMySpine detects it → all voice/haptic alerts suppressed until Focus disabled

---

### Feature 3: Audio Device Display

**Objective:**
Show which AirPods model is currently providing motion data.

**Implementation:**
- `CMHeadphoneMotionManager` does NOT expose device name directly
- Use `AVAudioSession.sharedInstance().currentRoute` to get connected audio device
- Parse device name: "AirPods Pro", "AirPods Max", "AirPods (3rd generation)", "Beats Fit Pro"
- Display in Settings > "Connected Device" section

**UI Changes:**
- Add "Connected: AirPods Pro" indicator in the status bar icon tooltip
- Show device name in Settings panel

**Demo:**
User connects AirPods Max → menu bar shows "🎧 Max" or tooltip shows "AirPods Max connected"

---

### Feature 4: Configurable Streak Thresholds

**Objective:**
Allow users to customize what counts as a "Great Posture" streak.

**Implementation:**
- Add `greatPostureStreakSeconds` to `UserDefaults` (default: 30)
- Add slider in Settings: "Great Posture Streak: X seconds"
- Add milestone celebrations at 1min, 5min, 15min, etc.
- Store milestones reached in current session to avoid repeat celebrations

**UI Changes:**
- New Settings row: "🎉 Streak Milestone" with Stepper (30s, 60s, 120s, 300s, 600s)

**Demo:**
User sets streak to 5 minutes → maintains good posture for 5min → sees special "5-Minute Streak! 🎉" banner

---

### Feature 5: Hourly Posture Heatmap

**Objective:**
Show users *when* during the day they slouch most, enabling behavioral changes.

**Implementation:**
- Expand `DaySummary` to store hourly buckets: `hourlyGoodSeconds: [Double]` (24 elements)
- In `ingest()`, also record which hour (0-23) the sample belongs to
- In Analytics view: render a 24-column heatmap grid (rows = days, columns = hours)
- Color intensity = slouch ratio for that hour

**UI Changes:**
- New "Heatmap" tab in Analytics view
- 7-row × 24-column grid, color-coded by slouch percentage

**Demo:**
User sees red columns at 3-4pm → realizes afternoon slump causes slouch → schedules walks at that time

---

### Feature 6: CSV/JSON Export

**Objective:**
Allow users to export their posture history for external analysis.

**Implementation:**
- Add "Export History" button in Analytics view
- Supported formats: CSV (spreadsheet-friendly), JSON (developer-friendly)
- Include all fields: date, goodSeconds, slouchSeconds, avgTilt, sampleCount
- Save to user-selected location via NSSavePanel

**UI Changes:**
- "Export…" button in Analytics header
- Format picker: CSV / JSON

**Demo:**
User clicks Export → selects CSV → saves to Desktop → opens in Numbers/Excel

---

### Feature 7: Break Reminders

**Objective:**
Encourage users to stand up and move independently of posture alerts.

**Implementation:**
- Add `breakReminderEnabled: Bool` and `breakIntervalMinutes: Int` to UserDefaults
- New Timer: `breakReminderTimer` fires every N minutes
- When fired: speak "Time to take a break! Stand up and stretch." (or custom message)
- Respect Focus mode (like posture alerts)
- Add to Settings: "Break Reminders" toggle + interval picker (15/30/45/60 min)

**UI Changes:**
- New Settings row: "☕ Break Reminders" with interval stepper

**Demo:**
User enables 30-min break reminders → every 30min while tracking → gets voice reminder to stand

---

### Feature 8: Onboarding Flow

**Objective:**
Explain to first-time users how to activate motion tracking (they must play audio).

**Implementation:**
- Check `UserDefaults` for `hasCompletedOnboarding` flag
- If false, show modal on first launch:
  1. "Welcome to FixMySpine" with icon
  2. "Your AirPods contain motion sensors"
  3. "To activate tracking, play any audio through your AirPods"
  4. "Tip: Keep audio playing in the background while you work"
  5. "Calibrate: Sit up straight and click the calibration button"
- Dismiss sets `hasCompletedOnboarding = true`

**UI Changes:**
- First-launch modal overlay (full-screen darkening)
- "Got it, let's go!" dismiss button

**Demo:**
First launch → onboarding modal appears → user reads → clicks "Got it!" → main UI appears

---

## Technical Notes

### Thread Safety
All UI updates must remain on `@MainActor` or `DispatchQueue.main` — already followed in existing code.

### Persistence
All new settings use `UserDefaults` with sensible defaults, matching existing patterns.

### Sparkle Updates
New features do not affect appcast.xml or signing. Version bumps will follow existing `build_main.sh` workflow.

### Privacy
All features remain 100% local. No new network calls. No analytics. No cloud sync.

---

## Task Breakdown

```
Task 1:  Session Pause/Resume
         - Add isPaused flag + UI toggle
         - Gate alerts behind pause state

Task 2:  Focus Mode Integration  
         - Observe Focus state changes
         - Suppress alerts when DND active

Task 3:  Audio Device Display
         - Query AVAudioSession for device name
         - Display in status bar tooltip + Settings

Task 4:  Configurable Streak Thresholds
         - Add UserDefaults key + Settings UI
         - Add milestone celebrations

Task 5:  Hourly Posture Heatmap
         - Expand data model for hourly buckets
         - Render heatmap visualization

Task 6:  CSV/JSON Export
         - Add export button + format picker
         - Implement save panel logic

Task 7:  Break Reminders
         - Add timer + settings UI
         - Respect Focus mode

Task 8:  Onboarding Flow
         - Check first-launch flag
         - Show tutorial modal
```

---

## Timeline Estimate

| Tier | Features | Effort | Recommended Batch |
|------|----------|--------|-------------------|
| Tier 1 | 1-4 | ~2-3 hours each | Sprint 1 |
| Tier 2 | 5-6 | ~3-4 hours each | Sprint 2 |
| Tier 3 | 7-8 | ~2-3 hours each | Sprint 3 |

Total: ~20-26 hours of implementation time.

---

## Open Questions

1. **Break Reminders**: Should these continue when posture tracking is paused?
   - Likely: Yes, independent of posture state

2. **Heatmap Storage**: Current data won't have hourly breakdown. Should we backfill with assumptions or start fresh?
   - Recommendation: Start fresh, show "Data collection in progress" placeholder

3. **Onboarding**: Should we re-show onboarding after app updates (e.g., v5.0)?
   - Recommendation: No, only on first install ever

---

*End of Plan*
