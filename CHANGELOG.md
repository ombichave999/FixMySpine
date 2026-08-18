# Changelog

All notable changes to **FixMySpine** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.0.0] - 2026-08-18

### Added
- **Auto-Recovering CoreMotion Watchdog**: Continuous health monitoring for AirPods telemetry with instant automatic reconnection after voice calls, meetings, or microphone interruptions.
- **Sparkle 2 Direct In-App Updater**: Cryptographically verified Ed25519 updates with immediate delivery and silent background check support.
- **Repository Optimization & Pre-Push Cleanup**: 100% clean architecture with zero binary repo bloat and production hardened runtime flags.

### Changed
- Streamlined release deployment pipeline with automatic signed DMG generation and immutable GitHub release distribution.
- Enhanced memory footprint and battery efficiency for all-day posture tracking.

---

## [4.4.0] - 2026-08-18

### Added
- **Sparkle 2 Cryptographic Auto-Update Engine**: Integrated dual-check update system with 0-second cache delay and Ed25519 signing.
- **Smartwatch & Wearable BLE Sync**: Bluetooth Low Energy telemetry supporting Apple Watch, Garmin, Polar, and WHOOP with live heart rate, battery monitoring, and haptic feedback.
- **Neural Voice Synthesis Engine**: Natural `.premium`/`.enhanced` macOS voice selector for posture alignment reminders.
- **Persistent Menu Bar Autosave**: Added `autosaveName` and command-drag reordering support to prevent menu bar clipping.
- **Compact Settings Panel**: Collapsible Watch Sync section, side-by-side reminders, and consolidated Help & About card.

### Changed
- Refined tagline to *"Realign. Redefine."* on the primary dashboard.
- Upgraded spine physics to 60 FPS instantaneous spring response (`.spring(response: 0.28, dampingFraction: 0.78)`).
- Standardized terminology to "Forward Lean" and "Backward Lean".
- Optimized memory footprint (~18 MB RAM) and background CPU usage (0.0%).

---

## [2.2-beta] - 2026-07-26

### Added
- **AirPods Head Tracking Telemetry**: Ingests real-time CoreMotion pitch and roll vectors via `CMHeadphoneMotionManager`.
- **Live Spine Gauge**: Biomorphic curved spine gauge with dynamic color-coding (🟢 Green `0°–5°`, 🟠 Amber `6°–12°`, 🔴 Red `>12°`).
- **Weekly Analytics & Score**: 7-day tracking time visualization, day-by-day posture ratio bar chart, streak counter, and score calculation.
- **Privacy Core**: 100% local processing guarantee with zero cloud/network telemetry.
- **Customization Settings**: Reminders, voice synthesization toggles, grace period controls (Instant to 30s), sensitivity thresholds (Relaxed to Expert), and native macOS Color Picker integration.
- **Menu Bar Dynamic Icon**: Live sitting posture vector figure reflecting real-time head inclination.

### Changed
- Refined UI layout with macOS Liquid Glass design system aesthetics (`glassPill` backdrop, subtle borders, and smooth spring animations).
- Fixed mini-card label truncation for `Neck Tilt` and `Side Lean`.

---

## [2.0-beta] - 2026-07-10

### Added
- Initial menu bar application scaffold using `NSStatusItem` and `NSPopover`.
- Basic posture calibration workflow establishing neutral baseline vectors.
