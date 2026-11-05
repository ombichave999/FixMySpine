<p align="center">
  <img src=".github/assets/app-icon.png" width="112" alt="FixMySpine logo">
</p>

<h1 align="center">FixMySpine</h1>

<p align="center">
  AirPods posture intelligence for macOS.<br>
  100% Free &amp; Open-Source · Runs entirely on your Mac.
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/tag/v5.0.4">Download</a> ·
  <a href="#everything-it-does">Features</a> ·
  <a href="#how-it-works">How It Works</a> ·
  <a href="#private-by-default">Privacy</a> ·
  <a href="#supported-hardware">Hardware</a> ·
  <a href="https://buymeacoffee.com/fixmyspine">Buy Me a Coffee</a>
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/tag/v5.0.4"><img src="https://img.shields.io/badge/version-5.0.4-00D053?style=flat-square" alt="Version 5.0.4"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-FA7343?style=flat-square&logo=swift&logoColor=white" alt="Swift 6"></a>
  <a href="#private-by-default"><img src="https://img.shields.io/badge/privacy-100%25_On--Device-00D053?style=flat-square" alt="100% On-Device"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0071E3?style=flat-square" alt="MIT License"></a>
  <a href="https://buymeacoffee.com/fixmyspine"><img src="https://img.shields.io/badge/Buy_Me_a_Coffee-FFDD00?style=flat-square&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee"></a>
</p>

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/download/v5.0.4/FixMySpine.dmg">
    <img src=".github/assets/btn-download.svg" height="50" alt="Download for macOS">
  </a>
  &nbsp;&nbsp;
  <a href="https://buymeacoffee.com/fixmyspine" target="_blank" rel="noopener">
    <img src=".github/assets/btn-bmac.svg" height="50" alt="Buy Me a Coffee">
  </a>
</p>

<div align="center">
<table>
  <tr>
    <td width="25%" align="center">
      <img src=".github/screenshots/1-airpods-already-know.png" width="100%" alt="1. Your AirPods already know.">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/2-so-i-built-something.png" width="100%" alt="2. So I built something.">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/3-it-knows-difference.png" width="100%" alt="3. It knows the difference.">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/4-and-it-remembers.png" width="100%" alt="4. And it remembers.">
    </td>
  </tr>
</table>
</div>

Real-time 60Hz AirPods motion tracking, subtle in-ear alerts, intelligent slouch hysteresis, Apple Watch haptic taps, daily posture scoring, and native SwiftUI custom accents. The posture intelligence tools Mac users need during deep focus work, behind a featherlight menu bar icon with no camera access, no account, no telemetry, and no subscription.

## The app

Real UI, captured on the developer's Mac. The settings screen shows v4.3.7; appearance may vary by app version.

<table align="center">
  <tr>
    <td width="25%" align="center">
      <img src=".github/screenshots/ui/1-connected-good-posture.png" width="100%" alt="Live tracking: AirPods connected, good posture at 3 degrees">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/ui/2-slouch-alert.png" width="100%" alt="Slouching alert at 39 degrees with recalibrate action">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/ui/3-settings.png" width="100%" alt="Settings and customization (captured on v4.3.7)">
    </td>
    <td width="25%" align="center">
      <img src=".github/screenshots/ui/4-watch-sync.png" width="100%" alt="Apple Watch and smartwatch sync screen">
    </td>
  </tr>
</table>

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
    A[AirPods 60Hz IMU] -->|Bluetooth LE| B[CoreMotion Engine]
    B --> C[Compound Biometric Filter]
    C --> D{10s Slouch Window}
    D -->|Aligned| E[Green Menu Bar Glyph]
    D -->|Slouching| F[Ambient In-Ear Chime]
```

## Install

Grab the disk image from the [releases page](https://github.com/ombichave999/FixMySpine/releases) and drag FixMySpine into Applications:

<p align="center">
  <a href="https://github.com/ombichave999/FixMySpine/releases/download/v5.0.4/FixMySpine.dmg">
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
| :--- | :---: | :--- |
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
    <img src="https://img.shields.io/badge/Buy_Me_a_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/sponsors/ombichave999">
    <img src="https://img.shields.io/badge/Sponsor_on_GitHub-EA4AAA?style=for-the-badge&logo=github-sponsors&logoColor=white" alt="Sponsor on GitHub">
  </a>
</p>

For private feedback or questions, contact [ombichave639@gmail.com](mailto:ombichave639@gmail.com).

## License

Distributed under the [MIT License](LICENSE).



