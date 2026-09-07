<p align="center">
  <img src="website/frontend/assets/img/icon-512.png" width="120" alt="FixMySpine logo">
</p>

<h1 align="center">FixMySpine</h1>

<p align="center">
  AirPods posture intelligence for macOS.<br>
  Free, open source, and everything runs 100% locally on your Mac.
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine">GitHub</a> ·
  <a href="#install">Install</a> ·
  <a href="#everything-it-does">Features</a> ·
  <a href="#how-it-works">How It Works</a> ·
  <a href="#private-by-default">Privacy</a> ·
  <a href="#supported-hardware">Hardware</a> ·
  <a href="https://buymeacoffee.com/fixmyspine">Buy Me a Coffee</a>
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/latest"><img src="https://img.shields.io/github/v/release/ombichave999/FixMySpine?label=release&color=00D053" alt="Latest release"></a>
  <a href="https://github.com/ombichave999/FixMySpine/releases"><img src="https://img.shields.io/badge/downloads-100%25%20FOSS-00D053" alt="Downloads"></a>
  <a href="https://github.com/ombichave999/FixMySpine/actions/workflows/ci.yml"><img src="https://github.com/ombichave999/FixMySpine/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI status"></a>
  <a href="#what-you-need"><img src="https://img.shields.io/badge/macOS-14%2B%20Sonoma%20%26%20Sequoia-black?logo=apple" alt="macOS 14 and newer"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License MIT"></a>
  <a href="https://buymeacoffee.com/fixmyspine"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee"></a>
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/latest/download/FixMySpine.dmg">
    <img src="https://img.shields.io/badge/Download_FixMySpine_v5.0.4-.DMG-00D053?style=for-the-badge&logo=apple&logoColor=white" alt="Download .DMG" height="38">
  </a>
  &nbsp;
  <a href="https://buymeacoffee.com/fixmyspine">
    <img src="https://img.shields.io/badge/Buy_Me_a_Coffee-Support_FOSS-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee" height="38">
  </a>
</p>

<p align="center">
  <img src=".github/screenshots/1-airpods-already-know.png" width="190" alt="Your AirPods already know">
  <img src=".github/screenshots/2-so-i-built-something.png" width="190" alt="So I built something">
  <img src=".github/screenshots/3-it-knows-difference.png" width="190" alt="It knows the difference">
  <img src=".github/screenshots/4-and-it-remembers.png" width="190" alt="And it remembers">
</p>

Real-time 60Hz AirPods motion tracking, subtle in-ear alerts, intelligent slouch hysteresis, Apple Watch haptic taps, daily posture scoring, and native SwiftUI custom accents. The posture intelligence tools Mac users need during deep focus work, behind a featherlight menu bar icon with no camera access, no account, no telemetry, and no subscription.

## Everything it does

### Posture Intelligence & Kinematics

- **AirPods 60Hz motion stream.** Directly reads 3-axis angular velocity and head tilt via Apple's `CMHeadphoneMotionManager` API over Bluetooth Low Energy.
- **Intelligent slouch hysteresis.** Uses compound vector mathematics ($\sqrt{\text{pitch}^2 + 0.49 \times \text{roll}^2}$) to accurately isolate cervical slouching without false alarms when sipping water, stretching, or turning your head.
- **One-tap neutral baseline.** Calibrate your unique natural working posture — desk height, screen angle, and body anatomy. Every measurement is relative to you.
- **Sensitivity presets.** Choose between Relaxed (18°), Balanced (12°), Strict (8°), and Expert (5°) depending on your ergonomics goals.

### Alerts & Ambient Feedback

- **Discreet spoken cues.** Soft, calm audio cues like *"Time to reset your posture"* or *"Lift your chin slightly"* reset your shoulders without breaking focus.
- **Ambient in-ear chimes.** Gentle spatial audio tones sound only when slouching persists past your grace window.
- **Customizable grace window.** Adjust how long slouching must persist before you are nudged (Instant 3s, 10s, 30s). Glancing down or reaching for a notepad never rings the bell.

### Hardware & Telemetry

- **Apple Watch & BLE haptics.** Pair any Bluetooth LE smartwatch (Apple Watch, Garmin, Wear OS) for silent wrist taps during meetings or open-office focus sessions.
- **Weekly posture analytics.** Track daily posture scores, average tilt, daily slouch time, and discipline streaks — stored 100% locally in `UserDefaults`.
- **Liquid glass appearance.** Dressed to match macOS with dark glassmorphism styling and custom accent colors (Apple Green, Electric Blue, Purple, Orange, Pink).
- **Sparkle 2 auto-updates.** Native in-app updates verified against cryptographic Ed25519 signatures.

## How it works

Every head-tracking AirPod carries an Inertial Measurement Unit (IMU) built for spatial audio. FixMySpine streams that signal at 60Hz through Apple's CoreMotion framework:

```mermaid
flowchart LR
    A["AirPods 60Hz IMU<br/>(Gyroscope / Accel)"] -->|Bluetooth LE| B["CMHeadphoneMotionManager<br/>(Sources/main.swift)"]
    B --> C["Compound Vector Filter<br/>sqrt(nod² + 0.49·side²)"]
    C --> D{"10s Slouch Filter"}
    D -->|Aligned (0°-5°)| E["● Green Menu Bar Glyph"]
    D -->|Slouching (>8° for 10s)| F["Ambient In-Ear Chime / Voice Reset"]
```

## Install

Grab the disk image from the [releases page](https://github.com/ombichave999/FixMySpine/releases) and drag FixMySpine into Applications:

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/latest/download/FixMySpine.dmg">
    <img src="https://img.shields.io/badge/Download_FixMySpine_v5.0.4-.DMG-00D053?style=for-the-badge&logo=apple&logoColor=white" alt="Download .DMG" height="42">
  </a>
</p>

Builds are signed and hardened for macOS Sonoma and Sequoia compatibility.

## Private by default

FixMySpine is built with privacy as an absolute foundational constraint:

<p align="center">
  <img src="website/bmac_cover.png" width="720" alt="FixMySpine Privacy & Architecture">
</p>

| Permission / Sensor | Status | Why |
| :--- | :---: | :--- |
| **Camera** | ❌ Never Used | 0% camera access. We never touch or request your webcam. |
| **Microphone** | ❌ Never Used | CoreMotion reads spatial motion sensors only, never audio. |
| **Network & Cloud** | ❌ Zero Calls | No accounts, no servers, no analytics. All math runs in local CPU memory. |
| **Bluetooth LE** | ✅ Local Only | Reads standard Apple AirPods motion telemetry. |
| **Notifications** | ⚡ Optional | Delivers posture alerts if voice cues are muted. |

## Supported hardware

FixMySpine works with any Apple audio device equipped with head-tracking IMUs running on macOS 14.0+:

| Device | Head-Tracking IMU | Status |
| :--- | :---: | :---: |
| **AirPods Pro (2nd Generation)** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |
| **AirPods Pro (1st Generation)** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |
| **AirPods Max** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |
| **AirPods (3rd & 4th Generation)** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |
| **Beats Fit Pro** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |
| **Beats Solo 4** | 60Hz 3-Axis Gyroscope | ✅ Fully Supported |

*Note: AirPods must be connected and actively worn (playing audio or in ANC/transparency mode) for macOS CoreMotion headphone telemetry to stream.*

## What you need

- A Mac (Apple Silicon or Intel)
- macOS 14.0 Sonoma or newer

### Build it yourself

```bash
# Clone the repository
git clone https://github.com/ombichave999/FixMySpine.git
cd FixMySpine

# Compile native macOS application bundle (Swift 6)
bash build.sh 5.0.4 release

# Launch FixMySpine
open build/FixMySpine.app

# Package standalone release DMG
bash make_dmg.sh 5.0.4 release
```

## Community & Support

FixMySpine is **100% Free and Open-Source**. If it helps protect your neck and posture during long coding sessions, consider supporting development:

<p align="center">
  <a href="https://buymeacoffee.com/fixmyspine">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=fixmyspine&button_colour=00D053&font_colour=ffffff&font_family=Inter&outline_colour=000000&coffee_colour=FFDD00" alt="Buy Me A Coffee">
  </a>
</p>

<p align="center">
  <a href="https://github.com/sponsors/ombichave999">
    <img src="https://img.shields.io/badge/Sponsor%20on%20GitHub-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="GitHub Sponsors">
  </a>
</p>

For private feedback or questions, contact [ombichave639@gmail.com](mailto:ombichave639@gmail.com).

## License

Distributed under the [MIT License](LICENSE).

