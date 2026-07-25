<div align="center">

# FixMySpine 🧘‍♂️
### AirPods Posture Intelligence for macOS

[![Version](https://img.shields.io/badge/version-2.2--beta-blue.svg)](https://github.com/ombichave999/FixMySpine/releases)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black.svg?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Privacy](https://img.shields.io/badge/privacy-100%25%20Local-emerald.svg)](https://github.com/ombichave999/FixMySpine#privacy--security)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

*FixMySpine uses the motion sensors inside your AirPods to detect forward head tilt and side lean in real-time, alerting you before neck strain develops.*

[Key Features](#key-features) •
[Supported Hardware](#supported-hardware) •
[Building & Running](#building--running) •
[Privacy](#privacy--security) •
[Roadmap](#roadmap)

</div>

---

> [!NOTE]
> **Beta Release Status (v2.2-beta)**  
> FixMySpine is currently in **active public beta**. Core tracking, calibration, voice reminders, sensitivity adjustments, and weekly analytics are functional. Updates are actively being pushed to refine tracking precision and feature depth.

---

## ✨ Key Features

- 🎧 **AirPods Spatial Tracking**: Real-time motion telemetry via `CMHeadphoneMotionManager` detecting pitch and roll angles.
- 📐 **Live Biomorphic Spine Gauge**: Interactive visual gauge displaying real-time neck inclination and side lean with dynamic color-coding (🟢 Good `0°–5°`, 🟠 Moderate `6°–12°`, 🔴 Alert `>12°`).
- 🎯 **One-Tap Calibration**: Set your neutral ergonomic baseline in seconds.
- 🗣️ **Voice & System Reminders**: Subtle spoken cues and optional notifications when slouching persists past your chosen grace period.
- 📊 **Weekly Analytics & History**: Track posture score trends, total session time, best streaks, and daily performance bar charts stored locally.
- 🔒 **100% Local Processing**: Zero cloud uploads, zero telemetry, zero analytics tracking. Everything stays on your Mac.
- 🎨 **Liquid Glass Aesthetic**: Native macOS menu bar utility built with SwiftUI, dark glassmorphism styling, and custom accent color controls.

---

## 🎧 Supported Hardware

FixMySpine works with any Apple audio device equipped with head-tracking IMUs running on macOS 14.0+:

| Device | Head-Tracking Motion Support |
| :--- | :---: |
| **AirPods Pro (1st & 2nd Gen)** | ✅ Supported |
| **AirPods Max** | ✅ Supported |
| **AirPods (3rd Gen)** | ✅ Supported |
| **Beats Fit Pro** | ✅ Supported |

*Note: Device must be connected and actively active (playing audio or in transparent/ANC mode) for macOS CoreMotion headphone telemetry to start.*

---

## 🏗️ Building & Running

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ toolchain (Command Line Tools or Xcode 15+)

### Quick Build (No Xcode Required)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ombichave999/FixMySpine.git
   cd FixMySpine
   ```

2. **Build the macOS application bundle**:
   ```bash
   bash build.sh
   ```

3. **Launch FixMySpine**:
   ```bash
   open build/FixMySpine.app
   ```

### Packaging a Standalone `.dmg`

To package a standalone shareable disk image:
```bash
bash make_dmg.sh
```
This generates `FixMySpine.dmg` in the repository root.

---

## 🔒 Privacy & Security

FixMySpine is built with privacy as a foundational constraint:
- **Zero Network Calls**: The application makes no outgoing network connections.
- **Local Analytics Only**: Posture logs and weekly history are stored securely in your local `UserDefaults`.
- **No Background Audio Recording**: CoreMotion reads only spatial gravity/acceleration vectors (`CMAcceleration`), not microphone audio.

---

## ⚠️ Known Limitations (Beta)

- **AirPods Inactivity Sleeping**: CoreMotion headphone updates pause if AirPods disconnect or enter low-power sleep mode. Reconnecting audio automatically resumes tracking.
- **Calibrated Drift**: Yaw/rotational drift can occur during extended sessions; tap **Recalibrate Posture** to reset baseline.

---

## 🗺️ Roadmap

- [x] Initial CoreMotion pitch/roll ingest & posture hysteresis engine
- [x] Weekly posture analytics & score tracking
- [x] Custom accent themes & native macOS color picker integration
- [ ] **v2.3**: Multi-monitor / status bar widget customization
- [ ] **v2.4**: Stand reminders & wrist motion correlation via Apple Watch integration
- [ ] **v3.0**: MenuBarExtra native popover refactoring & menubar graph sparklines

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.

---

<div align="center">
  <sub>Built with Swift & SwiftUI by <a href="https://github.com/ombichave999">Om Bichave</a></sub>
</div>
