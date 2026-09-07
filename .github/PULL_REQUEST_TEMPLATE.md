## 📌 Summary of Changes
<!-- Provide a clear, high-level overview of what this pull request changes and why. -->

## 🛠️ Components Modified
- [ ] Native macOS App (`Sources/main.swift`)
- [ ] Build & Toolchain Scripts (`build.sh`, `make_dmg.sh`, `build_main.sh`)
- [ ] Sparkle Updates & Appcast (`appcast.xml`, `Info.plist`)
- [ ] Fullstack Website & Documentation (`website/`, `README.md`)

## 📋 Verification & Testing Checklist
<!-- Check all items that have been verified locally before requesting review -->
- [ ] **Compilation**: App compiles without errors using `bash build.sh` (Swift 6 / macOS 14.0+ SDK).
- [ ] **Zero Privacy Leakage**: Verified 100% offline local processing (zero camera permissions, zero cloud telemetry).
- [ ] **Thread Safety**: All UI mutations and `@Published` property updates execute on `@MainActor` or `DispatchQueue.main`.
- [ ] **Hardware Compatibility**: Verified with AirPods Pro / AirPods Max / AirPods 3rd Gen CoreMotion telemetry.
- [ ] **DMG Packaging**: Tested DMG creation via `bash make_dmg.sh` and verified signature.
- [ ] **Commit Attribution**: AI / Agent commits include `Co-Authored-By: Antigravity <noreply@google.com>`.

## 📸 Screenshots / Recordings (if applicable)
<!-- Attach before/after screenshots or terminal logs -->

## 🔗 Related Issues / Milestones
Fixes #
