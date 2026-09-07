<div align="center">

# FixMySpine 🧘‍♂️
### 100% Free & Open-Source AirPods Posture Intelligence for macOS

[![Version](https://img.shields.io/badge/version-5.0.4-00D053.svg)](https://github.com/ombichave999/FixMySpine/releases)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black.svg?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Privacy](https://img.shields.io/badge/privacy-100%25%20Offline-00D053.svg)](#-privacy--zero-data-leakage)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support%20Project-FFDD00.svg?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/fixmyspine)

<br/>

<img src="website/bmac_cover.png" width="100%" alt="FixMySpine Banner" />

<br/>

*FixMySpine turns the 60Hz CoreMotion gyroscopes inside your AirPods into a silent, real-time posture coach for macOS. Zero cameras, zero cloud calls, zero battery drain.*

[Download Latest .DMG](https://github.com/ombichave999/FixMySpine/releases) •
[Features](#-features) •
[Supported Hardware](#-supported-hardware) •
[How It Works](#-how-it-works) •
[Building Locally](#-building-locally) •
[Sponsor](#-support--sponsor)

</div>

---

## ✨ Features

- 🎧 **AirPods 60Hz Motion Stream**: Directly reads 3-axis angular velocity and head tilt via Apple's `CMHeadphoneMotionManager` API over Bluetooth Low Energy.
- 📐 **Compound Biometric Angle Vector**: Uses verified compound tilt mathematics ($\sqrt{\text{pitch}^2 + 0.49 \times \text{roll}^2}$) to accurately isolate cervical slouching without false alarms when sipping water or turning your head.
- 🎯 **One-Click Instant Calibration**: Zero your neutral baseline with a single click.
- 🗣️ **Discreet Ambient Audio Reminders**: Spoken reminders and gentle chimes only when continuous slouching exceeds your customizable grace window (default: 10s).
- 🔒 **100% Local Processing & Total Privacy**: 0% Camera access, 0% cloud telemetry, 0% analytics. Operates completely in an on-device AppKit/SwiftUI sandbox.
- ⚡ **Near-Zero Resource Draw**: Native Swift 6 Universal Binary consumes $<0.1\%$ CPU and $<25\text{MB}$ RAM.
- 🔄 **Sparkle 2 Auto-Updates**: Native in-app updates secured with Ed25519 cryptographic signatures.

---

## 🎧 Supported Hardware

FixMySpine works seamlessly with all Apple audio hardware supporting spatial head-tracking on macOS 14.0+ (Sonoma & Sequoia):

| Device | CoreMotion Head-Tracking | Status |
| :--- | :---: | :---: |
| **AirPods Pro (2nd Generation)** | 60Hz 3-Axis IMU | ✅ Fully Supported |
| **AirPods Pro (1st Generation)** | 60Hz 3-Axis IMU | ✅ Fully Supported |
| **AirPods Max** | 60Hz 3-Axis IMU | ✅ Fully Supported |
| **AirPods (3rd Generation)** | 60Hz 3-Axis IMU | ✅ Fully Supported |
| **Beats Fit Pro** | 60Hz 3-Axis IMU | ✅ Fully Supported |
| **Beats Solo 4** | 60Hz 3-Axis IMU | ✅ Fully Supported |

---

## 🔬 How It Works

```mermaid
flowchart LR
    A["AirPods 60Hz IMU<br/>(Gyroscope / Accel)"] -->|Bluetooth LE| B["CMHeadphoneMotionManager<br/>(Sources/main.swift)"]
    B --> C["Compound Vector Filter<br/>sqrt(nod² + 0.49·side²)"]
    C --> D{"10s Slouch Filter"}
    D -->|Aligned (0°-5°)| E["● Green Menu Bar Glyph"]
    D -->|Slouching (>8° for 10s)| F["Ambient In-Ear Chime / Voice Reset"]
```

---

## 🏗️ Building Locally

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Swift 6.0 toolchain (`swiftc`)

### Build & Run Commands

```bash
# 1. Clone the repository
git clone https://github.com/ombichave999/FixMySpine.git
cd FixMySpine

# 2. Compile the native macOS application bundle
bash build.sh 5.0.4 release

# 3. Launch FixMySpine
open build/FixMySpine.app

# 4. Package standalone release DMG
bash make_dmg.sh 5.0.4 release
```

---

## 🔒 Privacy & Zero Data Leakage

FixMySpine is built on the principle of **Zero Privacy Leakage**:
- **No Camera Permissions**: We never request or access your Mac's webcam.
- **No Cloud Servers**: There is no login, no database, and no cloud analytics.
- **Offline Processing**: All angle calculations execute locally on your Mac's CPU/Apple Silicon Neural Engine.

---

## ☕ Support & Sponsor

FixMySpine is **100% Free and Open-Source**. If this app helps protect your spine and posture during long work sessions, consider supporting development:

<div align="center">

<a href="https://buymeacoffee.com/fixmyspine">
  <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=fixmyspine&button_colour=00D053&font_colour=ffffff&font_family=Inter&outline_colour=000000&coffee_colour=FFDD00" alt="Buy Me A Coffee" />
</a>

<br/><br/>

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor%20on%20GitHub-EA4AAA?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/ombichave999)

</div>

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
