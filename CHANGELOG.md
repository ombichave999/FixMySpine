# Changelog

All notable changes to **FixMySpine** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
