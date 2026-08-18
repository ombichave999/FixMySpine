# Agent Instructions

## Package & Toolchain
- **Compiler**: Swift 6.0 (`swiftc`) with macOS 14.0+ target SDK
- **Frameworks**: SwiftUI, AppKit, CoreMotion, AVFoundation, UserNotifications, CoreBluetooth, Sparkle 2

## Build & Release Commands
| Task | Command |
|------|---------|
| Compile App (Debug/Test) | `bash build.sh [version] [channel]` |
| Package DMG | `bash make_dmg.sh [version] [channel]` |
| Production Release & Sparkle Sign | `bash build_main.sh [version] "[release notes]"` |
| Beta Release & Sparkle Sign | `bash build_beta.sh [version] "[release notes]"` |
| Verify DMG Ed25519 Signature | `./Sparkle-Tools/bin/sign_update -p FixMySpine.dmg` |

## Key Conventions
- **Single Source of Truth**: Main entrypoint is [`Sources/main.swift`](file:///Users/om/Downloads/Fixmyspine!/Sources/main.swift).
- **Zero Privacy Leakage**: 100% offline local processing. No network analytics, no camera access.
- **Sparkle Auto-Updates**: Ed25519 public key in [`Info.plist`](file:///Users/om/Downloads/Fixmyspine!/Info.plist) must match feed signatures in [`appcast.xml`](file:///Users/om/Downloads/Fixmyspine!/appcast.xml).
- **Thread Safety**: UI mutations must remain on `@MainActor` or `DispatchQueue.main`.

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: Antigravity <noreply@google.com>
```
