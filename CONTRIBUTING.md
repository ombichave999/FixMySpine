# Contributing to FixMySpine

Thank you for your interest in contributing to **FixMySpine**! FixMySpine is an open-source, privacy-first macOS utility designed to help desk workers, programmers, and students maintain optimal spinal posture using AirPods gyroscopes.

---

## 🧭 Core Principles

1. **Zero Privacy Leakage**: FixMySpine runs **100% offline**. We will not merge any pull requests introducing camera permissions, cloud telemetry, analytics SDKs, or background network tracking.
2. **Native Performance**: Written natively in **Swift 6 (AppKit + SwiftUI)**. Idle CPU must remain $<0.1\%$ and RAM $<25\text{MB}$.
3. **Single Source of Truth**: The core macOS application logic lives in [`Sources/main.swift`](file:///Users/om/Downloads/Fixmyspine!/Sources/main.swift).

---

## 🛠️ Local Development & Build Workflow

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ toolchain (`swiftc`)

### Commands
```bash
# Build app bundle
bash build.sh 5.0.4 release

# Test run locally
open build/FixMySpine.app

# Package release DMG
bash make_dmg.sh 5.0.4 release
```

---

## 🤖 Agent & Contributor PR Protocol

Before opening a pull request or submitting code for technical review:

1. **Verify Compilation**: Ensure `bash build.sh` compiles cleanly without warnings or errors.
2. **Thread Safety**: Ensure all SwiftUI/AppKit UI state changes happen on `@MainActor` or `DispatchQueue.main`.
3. **Commit Attribution**: If using AI assistance, commits must include:
   ```text
   Co-Authored-By: Antigravity <noreply@google.com>
   ```
4. **Use PR Template**: Complete the checklist in `.github/PULL_REQUEST_TEMPLATE.md`.

---

## ☕ Support the Project

If you love FixMySpine, consider starring the repository ⭐️ or supporting ongoing development:
- **Buy Me a Coffee**: [buymeacoffee.com/fixmyspine](https://buymeacoffee.com/fixmyspine)
- **GitHub Sponsors**: [github.com/sponsors/ombichave999](https://github.com/sponsors/ombichave999)
