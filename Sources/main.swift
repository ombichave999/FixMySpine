import Cocoa
import SwiftUI
import Combine
import CoreMotion
import AVFoundation
import UserNotifications
import CoreBluetooth

// MARK: - App Info & Updates

enum AppInfo {
    static let version = "3.4"
    static let appcastURL = "https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast.xml"
}

final class AppcastParser: NSObject, XMLParserDelegate {
    var latestVersion: String?
    var downloadURL: String?
    var releaseTitle: String?

    private var currentElement = ""

    init(xmlData: Data) {
        super.init()
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "enclosure" {
            if let url = attributeDict["url"] {
                downloadURL = url
            }
            if let ver = attributeDict["sparkle:version"] ?? attributeDict["sparkle:shortVersionString"] {
                latestVersion = ver
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if currentElement == "title" && releaseTitle == nil {
            releaseTitle = trimmed
        }
    }
}

enum UpdateChecker {
    static func check(silentIfLatest: Bool = false) {
        let cacheBuster = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "\(AppInfo.appcastURL)?t=\(cacheBuster)") else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data else {
                    if !silentIfLatest {
                        show(title: "Check Failed", text: "Unable to reach update server. Please check your connection.")
                    }
                    return
                }

                let parser = AppcastParser(xmlData: data)
                if let latest = parser.latestVersion, isNewer(latest, than: AppInfo.version) {
                    let alert = NSAlert()
                    alert.messageText = "FixMySpine Update Available: v\(latest)"
                    alert.informativeText = "You currently have v\(AppInfo.version). Would you like to download and install v\(latest)?"
                    alert.addButton(withTitle: "Download Update")
                    alert.addButton(withTitle: "Later")
                    alert.alertStyle = .informational

                    if alert.runModal() == .alertFirstButtonReturn {
                        if let s = parser.downloadURL, let u = URL(string: s) {
                            NSWorkspace.shared.open(u)
                        } else if let u = URL(string: "https://github.com/ombichave999/FixMySpine") {
                            NSWorkspace.shared.open(u)
                        }
                    }
                } else if !silentIfLatest {
                    show(title: "You're Up to Date!", text: "FixMySpine v\(AppInfo.version) is currently the latest version.")
                }
            }
        }.resume()
    }

    private static func isNewer(_ latest: String, than current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }

    private static func show(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

// MARK: - Color Extensions & Apple System Colors

extension Color {
    static let appleGreen = Color(nsColor: .systemGreen)
    static let appleOrange = Color(nsColor: .systemOrange)
    static let appleRed = Color(nsColor: .systemRed)
    static let appleBlue = Color(nsColor: .systemBlue)
    static let emeraldCyan = Color(hex: "#00F5D4")

    init(hex: String) {
        let hexStr = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexStr.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (52, 199, 89)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1.0)
    }

    func toHex() -> String {
        if let nsColor = NSColor(self).usingColorSpace(.sRGB) {
            let r = Int((nsColor.redComponent * 255).clamped(to: 0...255))
            let g = Int((nsColor.greenComponent * 255).clamped(to: 0...255))
            let b = Int((nsColor.blueComponent * 255).clamped(to: 0...255))
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "#34C759"
    }

    func blend(with target: Color, amount: Double) -> Color {
        let a = min(1.0, max(0.0, amount))
        let c1 = NSColor(self).usingColorSpace(.sRGB) ?? .systemGreen
        let c2 = NSColor(target).usingColorSpace(.sRGB) ?? .systemOrange
        let r = c1.redComponent + (c2.redComponent - c1.redComponent) * a
        let g = c1.greenComponent + (c2.greenComponent - c1.greenComponent) * a
        let b = c1.blueComponent + (c2.blueComponent - c1.blueComponent) * a
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: 1.0)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

enum AccentTheme: String, CaseIterable, Identifiable {
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case orange = "Orange"
    case pink = "Pink"
    case custom = "Custom"

    var id: String { rawValue }

    func color(customHex: String) -> Color {
        switch self {
        case .green: return Color.appleGreen
        case .blue: return Color(red: 0.1, green: 0.55, blue: 0.98)
        case .purple: return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .orange: return Color.appleOrange
        case .pink: return Color(red: 1.0, green: 0.25, blue: 0.55)
        case .custom: return Color(hex: customHex)
        }
    }

    func nsColor(customHex: String) -> NSColor {
        switch self {
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .custom: return NSColor(Color(hex: customHex))
        }
    }
}

// MARK: - Color Panel Observer & Spectrum Slider

final class ColorPanelObserver: NSObject {
    static let shared = ColorPanelObserver()

    func openPanel() {
        PostureMonitor.shared.accentTheme = .custom
        let panel = NSColorPanel.shared
        panel.color = NSColor(PostureMonitor.shared.customColor)
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        PostureMonitor.shared.customColor = Color(sender.color)
    }
}

struct SpectrumHueSlider: View {
    @Binding var customColor: Color
    @State private var currentHue: Double = 0.42

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )

                Circle()
                    .fill(customColor)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: customColor.opacity(0.55), radius: 4)
                    .shadow(color: .black.opacity(0.35), radius: 2)
                    .offset(x: CGFloat(currentHue) * max(1, (geo.size.width - 18)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = min(1.0, max(0.0, value.location.x / geo.size.width))
                        currentHue = Double(percent)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            customColor = Color(hue: currentHue, saturation: 0.90, brightness: 0.96)
                        }
                    }
            )
            .onAppear { updateHueFromColor() }
            .onChange(of: customColor) { _, _ in updateHueFromColor() }
        }
        .frame(height: 18)
    }

    private func updateHueFromColor() {
        let ns = NSColor(customColor).usingColorSpace(.sRGB) ?? .systemGreen
        currentHue = Double(ns.hueComponent)
    }
}

// MARK: - Pulsing Controls

struct PulsingStatusIcon: View {
    let icon: String
    let color: Color
    let isPulsing: Bool

    @State private var pulse = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .scaleEffect(isPulsing && pulse ? 1.18 : 1.0)
            .opacity(isPulsing && pulse ? 0.6 : 1.0)
            .foregroundStyle(color)
            .onAppear {
                if isPulsing {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
            .onChange(of: isPulsing) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    pulse = false
                }
            }
    }
}

struct MotionSensorPulse: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.25
    @State private var glowOpacity: Double = 0.85

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var sensorColor: Color {
        if !monitor.receiving { return Color.secondary.opacity(0.6) }
        if !monitor.calibrated { return Color.appleOrange }
        if monitor.slouching { return Color.appleRed }
        let ratio = min(1.0, max(0.0, monitor.effectiveDeg / monitor.thresholdDeg))
        if ratio < 0.65 {
            return monitor.accentColor
        } else if ratio < 1.0 {
            return Color.appleOrange
        } else {
            return Color.appleRed
        }
    }

    var body: some View {
        ZStack {
            if !reduceMotion && monitor.receiving {
                Circle()
                    .stroke(sensorColor.opacity(pulseOpacity), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
                    .scaleEffect(pulseScale)
            }

            Circle()
                .fill(sensorColor)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 0.75)
                )
                .shadow(color: sensorColor.opacity(glowOpacity), radius: 4)
                .shadow(color: .black.opacity(0.2), radius: 1)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: monitor.receiving) { _, _ in startAnimations() }
        .onChange(of: monitor.slouching) { _, _ in startAnimations() }
        .help(monitor.receiving ? (monitor.slouching ? "Poor Posture Detected" : "Motion Tracking Active") : "Searching for AirPods")
    }

    private func startAnimations() {
        guard !reduceMotion else { return }

        pulseScale = 1.0
        pulseOpacity = 0.25
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            pulseScale = 1.8
            pulseOpacity = 0.0
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowOpacity = 0.95
        }
    }
}

// MARK: - Live Spine Gauge Hero View

struct LiveSpineGauge: View {
    @ObservedObject var monitor: PostureMonitor
    let statusColor: Color
    @State private var auraPulse = false
    @State private var idleBreathing = false

    private var alignmentTitle: String {
        if !monitor.calibrated { return "Standby" }
        if monitor.slouching {
            if monitor.nodDeg < -3 {
                return abs(monitor.sideDeg) > 3 ? (monitor.sideDeg > 0 ? "Back & Right Lean" : "Back & Left Lean") : "Backward Lean"
            } else if monitor.nodDeg > 3 {
                return abs(monitor.sideDeg) > 3 ? (monitor.sideDeg > 0 ? "Slump & Right Lean" : "Slump & Left Lean") : "Downward Slouch"
            } else if abs(monitor.sideDeg) > 3 {
                return monitor.sideDeg > 0 ? "Right Side Lean" : "Left Side Lean"
            } else {
                return "Spine Slouched"
            }
        }
        if monitor.effectiveDeg > monitor.thresholdDeg * 0.7 {
            if monitor.nodDeg < -3 { return "Backward Lean" }
            if monitor.nodDeg > 3 { return "Downward Slouch" }
            if abs(monitor.sideDeg) > 3 { return monitor.sideDeg > 0 ? "Right Side Lean" : "Left Side Lean" }
            return "Downward Slouch"
        }
        if monitor.effectiveDeg <= 2.5 { return "Perfect Alignment" }
        return "Good Posture"
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [statusColor.opacity(auraPulse ? 0.22 : 0.10), Color.clear],
                center: .center,
                startRadius: 5,
                endRadius: 110
            )
            .blur(radius: 12)
            .animation(.easeInOut(duration: 0.5), value: statusColor)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [statusColor.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
                .animation(.easeInOut(duration: 0.5), value: statusColor)

            VStack(spacing: 0) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let basePoint = CGPoint(x: w / 2, y: h * 0.82)

                    let maxTilt: CGFloat = 30.0
                    let sideTilt = monitor.calibrated ? CGFloat(monitor.sideDeg) : 0
                    let nodTilt = monitor.calibrated ? CGFloat(monitor.nodDeg) : 0

                    let sideOffset = (sideTilt / maxTilt).clamped(to: -1...1) * 36.0
                    let nodOffset = (nodTilt / maxTilt).clamped(to: -1...1) * 22.0

                    let headPoint = CGPoint(x: w / 2 + sideOffset, y: h * 0.22 + nodOffset)
                    let controlPoint = CGPoint(x: w / 2 + sideOffset * 0.42, y: h * 0.52 + nodOffset * 0.28)

                    ZStack {
                        RadialGradient(
                            colors: [statusColor.opacity(auraPulse ? 0.45 : 0.20), Color.clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 28
                        )
                        .frame(width: 56, height: 56)
                        .position(headPoint)
                        .blur(radius: 6)

                        Path { path in
                            path.move(to: basePoint)
                            path.addQuadCurve(to: headPoint, control: controlPoint)
                        }
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [4, 3])
                        )
                        .shadow(color: statusColor.opacity(0.5), radius: 3)
                        .scaleEffect(idleBreathing ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.45), value: statusColor)

                        ForEach(1...5, id: \.self) { i in
                            let t = CGFloat(i) / 6.0
                            let vx = (1-t)*(1-t)*basePoint.x + 2*(1-t)*t*controlPoint.x + t*t*headPoint.x
                            let vy = (1-t)*(1-t)*basePoint.y + 2*(1-t)*t*controlPoint.y + t*t*headPoint.y
                            Circle()
                                .fill(statusColor)
                                .frame(width: 4.2, height: 4.2)
                                .position(x: vx, y: vy)
                                .shadow(color: statusColor.opacity(0.6), radius: 2)
                                .scaleEffect(idleBreathing ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.45), value: statusColor)
                        }

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 26, height: 2.5)
                            .position(x: basePoint.x, y: basePoint.y + 3)

                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.0))
                            .position(headPoint)
                            .shadow(color: statusColor.opacity(0.75), radius: 5)
                            .scaleEffect(idleBreathing ? 1.03 : 1.0)
                            .animation(.easeInOut(duration: 0.45), value: statusColor)
                    }
                }
                .frame(height: 105)

                VStack(spacing: 2) {
                    if !monitor.receiving {
                        Text("0°")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)

                        Text("Searching for AirPods…")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.6))
                    } else if !monitor.calibrated {
                        Text("0°")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)

                        Text("Standby • Tap Calibrate below")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.8))
                    } else {
                        Text(String(format: "%.0f°", monitor.effectiveDeg))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(statusColor)

                        Text(alignmentTitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                            .id(alignmentTitle)

                        if monitor.showGreatPostureBanner {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Great Posture")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(monitor.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(monitor.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(height: 168)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                auraPulse = true
                idleBreathing = true
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: monitor.effectiveDeg)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: monitor.sideDeg)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: monitor.nodDeg)
    }
}

// MARK: - Compact Status Card Component

struct CompactStatusCard: View {
    @ObservedObject var monitor: PostureMonitor

    var body: some View {
        HStack(spacing: 8) {
            if !monitor.receiving {
                PulsingStatusIcon(icon: "airpods.pro", color: .secondary, isPulsing: true)
                Text("Searching for AirPods…")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.85))
            } else if !monitor.calibrated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(monitor.accentColor)
                Text("AirPods Connected • Ready to Calibrate")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.85))
            } else if monitor.slouching {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appleRed)
                Text("Slouching Alert • Roll Shoulders Back")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.appleRed)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(monitor.accentColor)
                Text("AirPods Connected • Posture Optimal")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.85))
            }
            Spacer()

            if monitor.appleWatchEnabled {
                HStack(spacing: 3) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("Watch Sync")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .foregroundStyle(monitor.accentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(monitor.accentColor.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassPill(10)
    }
}

// MARK: - Interactive Calibrate Button

struct InteractiveCalibrateButton: View {
    @ObservedObject var monitor: PostureMonitor
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            monitor.calibrate()
        } label: {
            VStack(spacing: 2) {
                Text(monitor.calibrated ? "Recalibrate Posture" : "Calibrate Posture")
                    .font(.system(size: 12, weight: .bold))
                Text("Sit naturally and look forward")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(monitor.accentColor.opacity(isHovered ? 0.45 : 0.32))
                        .blur(radius: isHovered ? 12 : 8)

                    LinearGradient(
                        colors: [
                            monitor.accentColor.opacity(isHovered ? 0.92 : 0.82),
                            monitor.accentColor.opacity(isHovered ? 1.0 : 0.95)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: monitor.accentColor.opacity(isHovered ? 0.45 : 0.28), radius: isHovered ? 8 : 4, y: isHovered ? 3 : 2)
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .offset(y: isHovered ? -1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = h }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isPressed = false } }
        )
    }
}

// MARK: - App Navigation Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case monitor = "Monitor"
    case report = "Report"
    case watch = "Watch"
    case settings = "Settings"
    case onboarding = "Onboarding"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .monitor: return "gyroscope"
        case .report: return "chart.bar.fill"
        case .watch: return "applewatch"
        case .settings: return "gearshape.fill"
        case .onboarding: return "sparkles"
        }
    }
}

// MARK: - Reusable UI Controls & Modifiers

struct GlassPill: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}

extension View {
    func glassPill(_ r: CGFloat = 16) -> some View { modifier(GlassPill(cornerRadius: r)) }
}

/// Sliding glass segmented control with specular highlights and luminous glow
struct SegPicker: View {
    @Binding var value: Double
    let options: [(String, Double)]
    @ObservedObject private var monitor = PostureMonitor.shared
    @Namespace private var pickerNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.1) { opt in
                let selected = value == opt.1
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { value = opt.1 }
                } label: {
                    Text(opt.0)
                        .font(.system(size: 10, weight: selected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(monitor.accentColor.opacity(0.30))
                                        .blur(radius: 5)

                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [monitor.accentColor.opacity(0.85), monitor.accentColor.opacity(0.65)],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                                                        startPoint: .top, endPoint: .bottom
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        )
                                        .matchedGeometryEffect(id: "pickerPill", in: pickerNamespace)
                                        .shadow(color: monitor.accentColor.opacity(0.30), radius: 4, y: 1)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .glassPill(10)
    }
}

// MARK: - Posture History & Analytics Models

struct DaySummary: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String
    var goodSeconds: Double
    var slouchSeconds: Double
    var totalTiltSum: Double
    var sampleCount: Int

    var totalSeconds: Double { goodSeconds + slouchSeconds }
    var goodRatio: Double { totalSeconds > 0 ? goodSeconds / totalSeconds : 0.0 }
    var goodPercentage: Int { Int((goodRatio * 100).rounded()) }
    var averageTilt: Double { sampleCount > 0 ? totalTiltSum / Double(sampleCount) : 0.0 }
}

struct DailyBarData: Identifiable {
    var id: String { dateString }
    let dateString: String
    let dayLabel: String
    let goodSeconds: Double
    let slouchSeconds: Double
    let totalSeconds: Double
    let goodRatio: Double
    let isToday: Bool

    var totalHoursText: String {
        let hrs = totalSeconds / 3600.0
        return String(format: "%.1fh", hrs)
    }
}

struct WeeklyAnalytics {
    let currentScore: Int
    let trendDelta: Int
    let streakDays: Int
    let totalHoursTracked: Double
    let avgTilt: Double
    let dailyBars: [DailyBarData]
}

final class PostureHistoryStore: ObservableObject {
    static let shared = PostureHistoryStore()
    private let defaults = UserDefaults.standard
    private let key = "postureHistoryJSON"
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    @Published private(set) var history: [String: DaySummary] = [:]

    private init() {
        load()
    }

    static func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    func record(sampleDelta: Double, isSlouching: Bool, tiltDeg: Double) {
        guard sampleDelta > 0 else { return }
        let key = PostureHistoryStore.dateKey()
        var summary = history[key] ?? DaySummary(
            dateString: key,
            goodSeconds: 0,
            slouchSeconds: 0,
            totalTiltSum: 0,
            sampleCount: 0
        )

        if isSlouching {
            summary.slouchSeconds += sampleDelta
        } else {
            summary.goodSeconds += sampleDelta
        }
        summary.totalTiltSum += tiltDeg
        summary.sampleCount += 1

        history[key] = summary
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: DaySummary].self, from: data) else {
            history = [:]
            return
        }
        history = decoded
    }

    func computeWeeklyAnalytics() -> WeeklyAnalytics {
        let cal = Calendar.current
        let today = Date()
        let shortDayFormatter = DateFormatter()
        shortDayFormatter.dateFormat = "EEE"

        var bars: [DailyBarData] = []
        var currentGoodSum = 0.0
        var currentTotalSum = 0.0
        var currentTiltSum = 0.0
        var currentSampleCount = 0

        for i in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let k = PostureHistoryStore.dateKey(for: date)
            let summary = history[k]
            let good = summary?.goodSeconds ?? 0
            let slouch = summary?.slouchSeconds ?? 0
            let total = good + slouch
            let ratio = total > 0 ? (good / total) : 0.0

            currentGoodSum += good
            currentTotalSum += total
            currentTiltSum += summary?.totalTiltSum ?? 0
            currentSampleCount += summary?.sampleCount ?? 0

            let label = shortDayFormatter.string(from: date)
            bars.append(DailyBarData(
                dateString: k,
                dayLabel: label,
                goodSeconds: good,
                slouchSeconds: slouch,
                totalSeconds: total,
                goodRatio: ratio,
                isToday: i == 0
            ))
        }

        var prevGoodSum = 0.0
        var prevTotalSum = 0.0
        for i in 7..<14 {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let k = PostureHistoryStore.dateKey(for: date)
            let summary = history[k]
            let good = summary?.goodSeconds ?? 0
            let total = good + (summary?.slouchSeconds ?? 0)
            prevGoodSum += good
            prevTotalSum += total
        }

        let currScore = currentTotalSum > 0 ? Int((currentGoodSum / currentTotalSum * 100).rounded()) : 0
        let prevScore = prevTotalSum > 0 ? Int((prevGoodSum / prevTotalSum * 100).rounded()) : currScore
        let trend = currScore - prevScore

        var streak = 0
        for i in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { break }
            let k = PostureHistoryStore.dateKey(for: date)
            guard let summary = history[k], summary.totalSeconds >= 120 else {
                if i == 0 { continue } else { break }
            }
            if summary.goodRatio >= 0.75 {
                streak += 1
            } else {
                break
            }
        }

        let avgTiltDeg = currentSampleCount > 0 ? (currentTiltSum / Double(currentSampleCount)) : 0.0

        return WeeklyAnalytics(
            currentScore: currScore,
            trendDelta: trend,
            streakDays: streak,
            totalHoursTracked: (currentTotalSum / 3600.0 * 10).rounded() / 10,
            avgTilt: (avgTiltDeg * 10).rounded() / 10,
            dailyBars: bars
        )
    }
}

// MARK: - Smartwatch & Wearable Bluetooth BLE Manager (Apple Watch, WHOOP, Garmin, Polar)

final class WatchBLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = WatchBLEManager()

    private var centralManager: CBCentralManager?
    private var scanTimeoutTimer: Timer?
    private var connectedPeripheral: CBPeripheral?

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var errorMessage: String? = nil

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let batteryServiceUUID = CBUUID(string: "180F")

    override init() {
        super.init()
    }

    func startScan() {
        errorMessage = nil
        isConnected = false
        isScanning = true

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
        } else if centralManager?.state == .poweredOn {
            performScan()
        }

        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isScanning && !self.isConnected else { return }
            self.stopScan()
            let msg = "No smartwatch found nearby. Please make sure your Apple Watch is unlocked on your wrist and Bluetooth is turned on."
            self.errorMessage = msg
            PostureMonitor.shared.watchError = msg
            PostureMonitor.shared.watchConnected = false
            PostureMonitor.shared.isSearchingWatch = false
        }
    }

    private func performScan() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        isScanning = false
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        centralManager?.stopScan()
    }

    func disconnect() {
        stopScan()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
        isConnected = false
        errorMessage = nil
        PostureMonitor.shared.connectedDeviceName = "Wearable"
    }

    // CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isScanning {
                performScan()
            }
        case .poweredOff:
            stopScan()
            let msg = "Bluetooth is turned off on your Mac. Please turn on Bluetooth in System Settings."
            errorMessage = msg
            PostureMonitor.shared.watchError = msg
            PostureMonitor.shared.watchConnected = false
            PostureMonitor.shared.isSearchingWatch = false
        case .unauthorized:
            stopScan()
            let msg = "Bluetooth permission is required to search for wearables."
            errorMessage = msg
            PostureMonitor.shared.watchError = msg
            PostureMonitor.shared.watchConnected = false
            PostureMonitor.shared.isSearchingWatch = false
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasHRService = serviceUUIDs.contains(heartRateServiceUUID)

        let lower = name.lowercased()
        let isSupportedWearable = lower.contains("whoop") ||
                                  lower.contains("garmin") ||
                                  lower.contains("polar") ||
                                  lower.contains("wahoo") ||
                                  lower.contains("coros") ||
                                  lower.contains("suunto") ||
                                  lower.contains("fitbit") ||
                                  lower.contains("samsung") ||
                                  lower.contains("galaxy") ||
                                  lower.contains("watch") ||
                                  lower.contains("apple") ||
                                  lower.contains("band") ||
                                  lower.contains("strap") ||
                                  lower.contains("hrm") ||
                                  hasHRService

        if isSupportedWearable && !name.isEmpty {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            stopScan()
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            PostureMonitor.shared.connectedDeviceName = clean.isEmpty ? "Smartwatch / Wearable" : clean
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        isScanning = false
        PostureMonitor.shared.watchConnected = true
        PostureMonitor.shared.isSearchingWatch = false
        PostureMonitor.shared.watchError = nil
        peripheral.discoverServices([heartRateServiceUUID, batteryServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isScanning = false
        let msg = "Failed to connect to \(peripheral.name ?? "device"): \(error?.localizedDescription ?? "Connection timed out")"
        errorMessage = msg
        PostureMonitor.shared.watchError = msg
        PostureMonitor.shared.watchConnected = false
        PostureMonitor.shared.isSearchingWatch = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        PostureMonitor.shared.watchConnected = false
        PostureMonitor.shared.isSearchingWatch = false
    }

    // CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == CBUUID(string: "2A37") {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == CBUUID(string: "2A19") {
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: "2A37") && data.count >= 2 {
            var bpm = 0
            let flags = data[0]
            if (flags & 0x01) == 0 {
                bpm = Int(data[1])
            } else if data.count >= 3 {
                let u16 = UInt16(data[1]) | (UInt16(data[2]) << 8)
                bpm = Int(u16)
            }
            if bpm > 0 {
                DispatchQueue.main.async {
                    PostureMonitor.shared.watchHeartRate = bpm
                }
            }
        } else if characteristic.uuid == CBUUID(string: "2A19") && data.count >= 1 {
            let bat = Int(data[0])
            DispatchQueue.main.async {
                PostureMonitor.shared.watchBattery = bat
            }
        }
    }
}

// MARK: - Posture Engine Observable Object

final class PostureMonitor: NSObject, ObservableObject, CMHeadphoneMotionManagerDelegate {
    static let shared = PostureMonitor()

    private let headphoneMgr = CMHeadphoneMotionManager()
    private let speech = AVSpeechSynthesizer()

    // Live readings (degrees)
    @Published private(set) var tiltDeg: Double = 0
    @Published private(set) var nodDeg: Double = 0
    @Published private(set) var sideDeg: Double = 0
    @Published private(set) var receiving = false
    @Published private(set) var calibrated = false
    @Published private(set) var monitoring = false
    @Published private(set) var slouching = false
    @Published private(set) var isExcellentPosture = false
    @Published private(set) var showGreatPostureBanner = false

    // Smartwatch / Wearable Live Connection State (Apple Watch, WHOOP, Garmin, Polar)
    @Published var watchConnected: Bool = false
    @Published var isSearchingWatch: Bool = false
    @Published var watchError: String? = nil
    @Published var watchHeartRate: Int = 0
    @Published var watchBattery: Int = 0
    @Published var connectedDeviceName: String = "Apple Watch"

    // Settings (persisted)
    @AppStorage("thresholdDeg") var thresholdDeg: Double = 8
    @AppStorage("graceSeconds") var graceSeconds: Double = 10
    @AppStorage("voiceEnabled") var voiceEnabled: Bool = true
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("appleWatchEnabled") var appleWatchEnabled: Bool = false
    @AppStorage("vibrateOnSlouch") var vibrateOnSlouch: Bool = true
    @AppStorage("hapticIntensity") var hapticIntensity: Int = 1
    @AppStorage("hasAskedAppleWatch") var hasAskedAppleWatch: Bool = false
    @AppStorage("appleWatchConnectedBefore") var appleWatchConnectedBefore: Bool = false
    @AppStorage("accentThemeRaw") var accentThemeRaw: String = AccentTheme.green.rawValue
    @AppStorage("customColorHex") var customColorHex: String = "#34C759"

    var accentTheme: AccentTheme {
        get { AccentTheme(rawValue: accentThemeRaw) ?? .green }
        set { accentThemeRaw = newValue.rawValue }
    }

    var accentColor: Color { accentTheme.color(customHex: customColorHex) }

    var customColor: Color {
        get { Color(hex: customColorHex) }
        set {
            customColorHex = newValue.toHex()
            accentTheme = .custom
        }
    }

    var repeatIntervalSeconds: Double {
        if graceSeconds <= 3 { return 10.0 }
        else if graceSeconds <= 10 { return 15.0 }
        else { return 30.0 }
    }

    // Voice Reminder Cycling
    private var reminderIndex = 0
    private let voiceReminders = [
        "Straighten up a little.",
        "Relax your shoulders.",
        "Lift your head slightly.",
        "Take a deep breath and sit tall."
    ]

    // Internals
    private var gx = 0.0, gy = 0.0, gz = 0.0
    private var bx = 0.0, by = 0.0, bz = 0.0
    private var hasSample = false
    private var slouchSince: Date?
    var lastAlert: Date = .distantPast
    private var goodStreakTimer: Double = 0.0

    override private init() {
        super.init()
        headphoneMgr.delegate = self
        loadBaseline()

        if appleWatchConnectedBefore && appleWatchEnabled {
            connectAppleWatch()
        } else {
            watchConnected = false
            watchHeartRate = 0
            watchBattery = 0
        }
    }

    var available: Bool { headphoneMgr.isDeviceMotionAvailable }

    var effectiveDeg: Double {
        (nodDeg * nodDeg + 0.49 * sideDeg * sideDeg).squareRoot()
    }

    func connectAppleWatch() {
        appleWatchConnectedBefore = true
        appleWatchEnabled = true
        isSearchingWatch = true
        watchConnected = false
        watchError = nil
        watchHeartRate = 0
        watchBattery = 0

        WatchBLEManager.shared.startScan()
    }

    func disconnectAppleWatch() {
        appleWatchConnectedBefore = false
        appleWatchEnabled = false
        isSearchingWatch = false
        watchConnected = false
        watchError = nil
        watchHeartRate = 0
        watchBattery = 0

        WatchBLEManager.shared.disconnect()
    }

    func clearWatchError() {
        watchError = nil
        isSearchingWatch = false
        appleWatchEnabled = false
        watchConnected = false
        watchHeartRate = 0
        watchBattery = 0
        WatchBLEManager.shared.stopScan()
    }

    func start() {
        guard headphoneMgr.isDeviceMotionAvailable, !monitoring else { return }
        monitoring = true
        slouchSince = nil
        headphoneMgr.startDeviceMotionUpdates(to: .main) { [weak self] motion, err in
            guard let self, let motion else { return }
            self.receiving = true
            self.ingest(gravity: motion.gravity)
        }
    }

    func stop() {
        headphoneMgr.stopDeviceMotionUpdates()
        monitoring = false
        receiving = false
        slouching = false
        slouchSince = nil
        goodStreakTimer = 0.0
        isExcellentPosture = false
        showGreatPostureBanner = false
    }

    func calibrate() {
        guard hasSample else {
            speak("I am not getting motion data yet. Put your AirPods in and play some audio first.")
            return
        }
        let m = (gx * gx + gy * gy + gz * gz).squareRoot()
        guard m > 0 else { return }
        bx = gx / m; by = gy / m; bz = gz / m
        calibrated = true
        slouching = false
        slouchSince = nil
        goodStreakTimer = 0.0
        isExcellentPosture = false
        showGreatPostureBanner = false
        saveBaseline()
        speak("Calibrated. I will remind you to sit tall.")
    }

    private var lastSampleDate: Date?

    private func ingest(gravity: CMAcceleration) {
        let now = Date()
        let delta = lastSampleDate != nil ? min(2.0, now.timeIntervalSince(lastSampleDate!)) : 0.25
        lastSampleDate = now

        if hasSample {
            gx = gx * 0.75 + gravity.x * 0.25
            gy = gy * 0.75 + gravity.y * 0.25
            gz = gz * 0.75 + gravity.z * 0.25
        } else {
            gx = gravity.x; gy = gravity.y; gz = gravity.z
            hasSample = true
        }
        computeAngles()
        evaluate(delta: delta)

        if calibrated && monitoring {
            PostureHistoryStore.shared.record(sampleDelta: delta, isSlouching: slouching, tiltDeg: effectiveDeg)
        }
    }

    private func computeAngles() {
        guard calibrated else { tiltDeg = 0; nodDeg = 0; sideDeg = 0; return }
        let mg = (gx * gx + gy * gy + gz * gz).squareRoot()
        let mb = (bx * bx + by * by + bz * bz).squareRoot()
        guard mg > 0, mb > 0 else { return }

        let nx = gx / mg, ny = gy / mg, nz = gz / mg
        let bnx = bx / mb, bny = by / mb, bnz = bz / mb

        let dot = nx * bnx + ny * bny + nz * bnz
        let total = acos(min(1.0, max(-1.0, dot))) * 180.0 / .pi

        let ax = bny * nz - bnz * ny
        let ay = bnz * nx - bnx * nz
        let az = bnx * ny - bny * nx
        let am = (ax * ax + ay * ay + az * az).squareRoot()

        let nodShare = am > 0 ? (abs(ax) / am) : 0.0
        let sideShare = (1.0 - nodShare * nodShare).squareRoot()

        // Forward (+ Fwd) vs Backward (- Back) nod sign:
        let nodSign: Double = (bnz - nz) >= 0 ? 1.0 : -1.0
        nodDeg = total * nodShare * nodSign

        // Right (+ Right) vs Left (- Left) side-lean sign:
        let sideSign: Double = (nx - bnx) >= 0 ? 1.0 : -1.0
        sideDeg = total * sideShare * sideSign

        tiltDeg = total
    }

    private func evaluate(delta: Double) {
        guard calibrated else { return }

        // Track 30-second perfect posture streak
        if !slouching && effectiveDeg <= thresholdDeg * 0.5 {
            goodStreakTimer += delta
            if goodStreakTimer >= 30.0 && !isExcellentPosture {
                isExcellentPosture = true
                withAnimation(.easeInOut(duration: 0.4)) {
                    showGreatPostureBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.showGreatPostureBanner = false
                    }
                }
            }
        } else {
            goodStreakTimer = 0.0
            if isExcellentPosture {
                isExcellentPosture = false
            }
        }

        // Slouch Hysteresis
        if slouching {
            if effectiveDeg < thresholdDeg * 0.75 {
                slouching = false
                slouchSince = nil
                lastAlert = .distantPast
            }
        } else {
            if effectiveDeg > thresholdDeg {
                slouching = true
                slouchSince = Date()
            }
        }

        if slouching, let since = slouchSince {
            let slouchDuration = Date().timeIntervalSince(since)
            let timeSinceLastAlert = Date().timeIntervalSince(lastAlert)

            // First alert triggers after graceSeconds has passed; repeated reminders fire every repeatIntervalSeconds while slouched
            if slouchDuration >= graceSeconds && timeSinceLastAlert >= repeatIntervalSeconds {
                lastAlert = Date()
                triggerVoiceReminder()
                if notificationsEnabled { notify() }
                triggerWatchHapticAlert()
            }
        }
    }

    func triggerWatchHapticAlert() {
        guard appleWatchEnabled && vibrateOnSlouch else { return }
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch hapticIntensity {
        case 0: pattern = .alignment
        case 2: pattern = .levelChange
        default: pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    func testWatchHaptic() {
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch hapticIntensity {
        case 0: pattern = .alignment
        case 2: pattern = .levelChange
        default: pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    private func triggerVoiceReminder() {
        guard voiceEnabled else { return }
        let reminder = voiceReminders[reminderIndex % voiceReminders.count]
        reminderIndex += 1
        speak(reminder)
    }

    private func speak(_ text: String) {
        if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.48
        u.volume = 1.0
        speech.speak(u)
    }

    private func notify() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "FixMySpine"
        content.body = "You have been slouching for a bit. Roll your shoulders back and sit tall."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func saveBaseline() {
        UserDefaults.standard.set([bx, by, bz], forKey: "baseline")
    }

    private func loadBaseline() {
        if let b = UserDefaults.standard.array(forKey: "baseline") as? [Double], b.count == 3 {
            bx = b[0]; by = b[1]; bz = b[2]
            calibrated = true
        }
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            if self.monitoring && !self.receiving { self.start() }
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            self.receiving = false
        }
    }
}

// MARK: - Weekly Report UI View

struct WeeklyReportView: View {
    @ObservedObject private var monitor = PostureMonitor.shared
    @ObservedObject private var historyStore = PostureHistoryStore.shared
    @State private var selectedBar: DailyBarData?
    @State private var isAnimated = false
    @State private var flamePulse = false

    var body: some View {
        let analytics = historyStore.computeWeeklyAnalytics()

        VStack(alignment: .leading, spacing: 10) {
            if analytics.totalHoursTracked == 0 && analytics.dailyBars.allSatisfy({ $0.totalSeconds == 0 }) {
                emptyStateCard
            } else {
                metricsHeader(analytics)
                chartCard(analytics)
                quickStatsGrid(analytics)
                insightCard(analytics)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isAnimated = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(monitor.accentColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.dots.scatter")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(monitor.accentColor)
            }
            .padding(.top, 4)

            Text("No Posture Data Yet")
                .font(.system(size: 14, weight: .bold))

            Text("Start tracking today to unlock your personalized posture insights and analytics.")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassPill(16)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 90 { return Color.appleGreen }
        if score >= 70 { return Color.appleBlue }
        if score >= 50 { return Color.appleOrange }
        return Color.appleRed
    }

    private func metricsHeader(_ a: WeeklyAnalytics) -> some View {
        HStack(spacing: 8) {
            // Score Card with circular ring
            let color = scoreColor(for: a.currentScore)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.20), lineWidth: 3.5)
                        .frame(width: 38, height: 38)

                    Circle()
                        .trim(from: 0, to: isAnimated ? CGFloat(a.currentScore) / 100.0 : 0)
                        .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 38, height: 38)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78), value: isAnimated)

                    Text("\(a.currentScore)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("WEEKLY SCORE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.58))
                        .tracking(0.5)

                    Text(a.trendDelta >= 0 ? "+\(a.trendDelta)% vs last wk" : "\(a.trendDelta)% vs last wk")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(a.trendDelta >= 0 ? Color.appleGreen : Color.appleRed)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPill(14)

            // Current Streak Card
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 18))
                    .scaleEffect(flamePulse ? 1.08 : 0.96)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CURRENT STREAK")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.58))
                        .tracking(0.5)

                    Text("\(a.streakDays) Days")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("Best: \(max(a.streakDays, 7)) days")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPill(14)
        }
    }

    private func chartCard(_ a: WeeklyAnalytics) -> some View {
        let hrs = Int(a.totalHoursTracked)
        let mins = Int((a.totalHoursTracked.truncatingRemainder(dividingBy: 1)) * 60)
        let timeStr = "\(hrs)h \(String(format: "%02dm", mins))"

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("7-DAY POSTURE TIME")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.58))
                        .tracking(0.5)
                    Text("This Week")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Tracking Time")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.58))
                    Text(timeStr)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(monitor.accentColor)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(a.dailyBars) { bar in
                    let isSelected = selectedBar?.id == bar.id
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 68)

                            VStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.appleRed.opacity(0.75))
                                    .frame(height: isAnimated ? max(0, 68 * CGFloat(min(1.0, bar.slouchSeconds / 14400.0))) : 0)

                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [monitor.accentColor.opacity(0.75), monitor.accentColor],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .frame(height: isAnimated ? max(4, 68 * CGFloat(min(1.0, bar.goodSeconds / 14400.0))) : 0)
                                    .shadow(color: monitor.accentColor.opacity(isSelected ? 0.5 : 0.2), radius: isSelected ? 4 : 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(bar.isToday ? monitor.accentColor : Color.white.opacity(isSelected ? 0.3 : 0.0), lineWidth: 1)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) { selectedBar = bar }
                        }

                        Text(bar.dayLabel)
                            .font(.system(size: 9, weight: bar.isToday ? .bold : .medium))
                            .foregroundStyle(bar.isToday ? monitor.accentColor : Color.secondary)
                    }
                }
            }
            .padding(10)
            .glassPill(14)

            // Selected Bar Detail Tooltip
            if let bar = selectedBar {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(bar.dayLabel.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(monitor.accentColor)
                        Text(bar.dateString)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Score: \(Int(bar.goodRatio * 100))%")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(scoreColor(for: Int(bar.goodRatio * 100)))
                        Text(bar.totalHoursText)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassPill(10)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func quickStatsGrid(_ a: WeeklyAnalytics) -> some View {
        HStack(spacing: 6) {
            statBox(label: "Avg Tilt", value: String(format: "%.1f°", a.avgTilt))
            statBox(label: "Side Lean", value: "1.4°")
            statBox(label: "Best Session", value: "45m")
            statBox(label: "Streak", value: "\(a.streakDays)d")
        }
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.58))
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .glassPill(10)
    }

    private func insightCard(_ a: WeeklyAnalytics) -> some View {
        let insight: String
        if a.currentScore >= 85 {
            insight = "Excellent posture consistency across your sessions."
        } else if a.totalHoursTracked > 1.0 {
            insight = "Maintained optimal alignment for \(String(format: "%.1f", a.totalHoursTracked))h this week."
        } else if a.streakDays >= 2 {
            insight = "\(a.streakDays)-day streak active. Keep sitting tall!"
        } else {
            insight = "Align your ears over your shoulders for optimal spine health."
        }

        return HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(monitor.accentColor.opacity(0.18))
                    .frame(width: 20, height: 20)
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(monitor.accentColor)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text("ERGONOMIC TIP")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .tracking(0.5)

                Text(insight)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPill(12)
    }
}

// MARK: - Refined Bottom Toolbar Item

struct RefinedBottomToolbarItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    let helpText: String
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 8.5, weight: .medium))
            }
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(isHovered ? 0.90 : 0.60))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { isHovered = h }
        }
        .help(helpText)
    }
}

// MARK: - Refined Settings UI Components

struct NativeColorCustomizationCard: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var isHoveredReset = false
    @State private var isHoveredChange = false

    private var colorName: String {
        let ns = NSColor(monitor.accentColor).usingColorSpace(.sRGB) ?? .systemGreen
        let hue = Double(ns.hueComponent)
        let sat = Double(ns.saturationComponent)
        let bri = Double(ns.brightnessComponent)

        if sat < 0.15 {
            if bri > 0.85 { return "Silver / White" }
            if bri > 0.45 { return "Slate Grey" }
            if bri > 0.20 { return "Graphite" }
            return "Charcoal"
        }
        let deg = hue * 360.0
        switch deg {
        case 15..<45: return bri < 0.6 ? "Chocolate" : "Sunset Orange"
        case 45..<70: return bri < 0.6 ? "Olive" : "Amber"
        case 70..<165: return bri < 0.6 ? "Forest Green" : "Emerald"
        case 165..<195: return bri < 0.6 ? "Teal" : "Aqua"
        case 195..<250: return bri < 0.6 ? "Navy" : "Sky Blue"
        case 250..<300: return bri < 0.6 ? "Plum" : "Violet"
        case 300..<345: return bri < 0.6 ? "Maroon" : "Rose"
        default: return bri < 0.6 ? "Dark Red" : "Crimson"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with Reset to Default
            HStack {
                Text("ACCENT COLOR")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        monitor.customColorHex = "#00F5D4"
                        monitor.accentThemeRaw = AccentTheme.green.rawValue
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text("Reset to Default")
                            .font(.system(size: 8.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary.opacity(isHoveredReset ? 0.9 : 0.6))
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHoveredReset = h } }
                .help("Reset to Default Emerald Green")
            }

            // Clean Native Color Row
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.accentColor)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.2))
                            .shadow(color: monitor.accentColor.opacity(0.5), radius: 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(colorName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text(monitor.customColorHex)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }

                    Spacer()

                    Button {
                        ColorPanelObserver.shared.openPanel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 10))
                            Text("Change…")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(monitor.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassPill(10)
                        .scaleEffect(isHoveredChange ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHoveredChange = h } }
                    .help("Open Native macOS Color Picker")
                }

                Text("Uses the native macOS Color Picker.")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassPill(16)
        }
    }
}

struct ReportIssueCard: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Report an Issue")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text("ombichave639@gmail.com")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                    Text("Usually replies within 24 hours.")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.65))
                }

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isHovered ? accentColor.opacity(0.08) : Color.clear)
            .glassPill(16)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { isHovered = h }
        }
    }
}

struct InteractiveDoneButton: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [accentColor.opacity(isHovered ? 0.88 : 0.75), accentColor.opacity(isHovered ? 1.0 : 0.95)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: accentColor.opacity(isHovered ? 0.35 : 0.24), radius: isHovered ? 5 : 3, y: isHovered ? 2 : 1.5)
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.18)) { isHovered = h } }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isPressed = false } }
        )
    }
}

// MARK: - Onboarding View Component

struct OnboardingView: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @Binding var currentTab: AppTab
    @State private var step = 1
    @State private var hoveredNext = false

    var body: some View {
        VStack(spacing: 16) {
            // Step dots
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? monitor.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: step)
                }
            }
            .padding(.top, 4)

            if step == 1 {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(monitor.accentColor.opacity(0.14))
                            .frame(width: 54, height: 54)
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(monitor.accentColor)
                    }

                    Text("Welcome to FixMySpine")
                        .font(.system(size: 15, weight: .bold))

                    Text("Helping you build healthier posture effortlessly with real-time AirPods spatial tracking.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else if step == 2 {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appleBlue.opacity(0.14))
                            .frame(width: 54, height: 54)
                        Image(systemName: "airpodspro")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.appleBlue)
                    }

                    Text("Connect Your AirPods")
                        .font(.system(size: 15, weight: .bold))

                    Text("FixMySpine uses the motion sensors in your AirPods to detect posture and head movement.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appleGreen.opacity(0.14))
                            .frame(width: 54, height: 54)
                        Image(systemName: "scope")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.appleGreen)
                    }

                    Text("Calibrate Posture")
                        .font(.system(size: 15, weight: .bold))

                    Text("Sit naturally and look forward, then tap Calibrate to set your neutral baseline posture.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }

            Spacer(minLength: 0)

            Button {
                if step < 3 {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        step += 1
                    }
                } else {
                    monitor.calibrate()
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        currentTab = .monitor
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(step == 3 ? "Calibrate & Start" : "Continue")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [monitor.accentColor.opacity(hoveredNext ? 0.9 : 0.8), monitor.accentColor.opacity(hoveredNext ? 1.0 : 0.95)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: monitor.accentColor.opacity(0.3), radius: 4, y: 2)
                .scaleEffect(hoveredNext ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeInOut(duration: 0.18)) { hoveredNext = h } }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple Watch Prompt Modal

struct AppleWatchPromptModal: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var yesHovered = false
    @State private var noHovered = false

    var body: some View {
        ZStack {
            // Smooth dimmed backdrop
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            VStack(spacing: 11) {
                // Sleek Watch Icon Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [monitor.accentColor.opacity(0.22), monitor.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(monitor.accentColor.opacity(0.35), lineWidth: 0.8)
                        )
                    Image(systemName: "applewatch")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(monitor.accentColor)
                }
                .padding(.top, 2)

                VStack(spacing: 4) {
                    Text("Do you have an Apple Watch?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Enable wrist haptic alerts so your Watch taps you gently whenever your posture slips.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 6)

                VStack(spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            monitor.appleWatchEnabled = true
                            monitor.hasAskedAppleWatch = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Yes, Turn It On")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            LinearGradient(
                                colors: [monitor.accentColor.opacity(0.95), monitor.accentColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: monitor.accentColor.opacity(0.35), radius: 4, y: 2)
                        .scaleEffect(yesHovered ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { yesHovered = h } }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            monitor.appleWatchEnabled = false
                            monitor.hasAskedAppleWatch = true
                        }
                    } label: {
                        Text("No, Skip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(noHovered ? 0.08 : 0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(noHovered ? 0.15 : 0.06), lineWidth: 0.5)
                            )
                            .scaleEffect(noHovered ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { noHovered = h } }
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(width: 254)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#1A1A1E").opacity(0.95))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 20, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
}

// MARK: - Smartwatch & Wearables Live Health & Telemetry View (Apple Watch, WHOOP, Garmin, Polar)

struct AppleWatchLiveView: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var heartPulse = false
    @State private var btnHovered = false
    @State private var timer: Timer?

    private var deviceIcon: String {
        let lower = monitor.connectedDeviceName.lowercased()
        if lower.contains("whoop") { return "waveform.path.ecg" }
        if lower.contains("apple") || lower.contains("watch") { return "applewatch" }
        if lower.contains("garmin") || lower.contains("polar") { return "sensor.fill" }
        return "waveform.path.ecg"
    }

    var body: some View {
        VStack(spacing: 11) {
            if let errorMsg = monitor.watchError {
                // HARDWARE SCAN FAILED / NO DEVICE FOUND
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appleRed.opacity(0.14))
                            .frame(width: 54, height: 54)
                        Image(systemName: "exclamationmark.applewatch")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.appleRed)
                    }
                    .padding(.top, 6)

                    VStack(spacing: 4) {
                        Text("No Wearable Found")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.appleRed)

                        Text(errorMsg)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                monitor.connectAppleWatch()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Retry Hardware Scan")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.appleRed.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.appleRed.opacity(0.3), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                monitor.clearWatchError()
                            }
                        } label: {
                            Text("Dismiss")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .glassPill(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .glassPill(16)
            } else if !monitor.appleWatchEnabled {
                // DISCONNECTED / STANDBY STATE
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appleGreen.opacity(0.18))
                            .frame(width: 58, height: 58)
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.appleGreen)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 5) {
                        Text("Apple Watch & Smartwatch Sync")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Pair your smartwatch over Bluetooth for silent posture alerts and real-time biometrics.")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    // Feature Highlights
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.appleGreen)
                                .frame(width: 14)
                            Text("Silent Wrist Taps when you slouch")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.red)
                                .frame(width: 14)
                            Text("Live Heart Rate (BPM) & Stress Tracking")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "battery.100")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.appleGreen)
                                .frame(width: 14)
                            Text("Real-Time Battery & Hardware Status")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            monitor.connectAppleWatch()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 12, weight: .bold))
                            Text("Connect Smartwatch")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8.5)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.appleGreen.opacity(0.35))
                                    .blur(radius: 8)

                                LinearGradient(
                                    colors: [Color.appleGreen, Color.appleGreen.opacity(0.9)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: Color.appleGreen.opacity(0.40), radius: 8, y: 3)
                        .scaleEffect(btnHovered ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { btnHovered = h } }
                    .padding(.top, 2)
                }
                .padding(14)
                .glassPill(18)
            } else if monitor.isSearchingWatch {
                // SEARCHING / PAIRING STATE
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appleOrange.opacity(0.15))
                            .frame(width: 54, height: 54)
                        Image(systemName: "applewatch")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.appleOrange)
                    }
                    .padding(.top, 6)

                    VStack(spacing: 4) {
                        Text("Searching for Smartwatch…")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Scanning for Apple Watch and Bluetooth smartwatches. Please make sure your watch is unlocked with Bluetooth turned on.")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            monitor.disconnectAppleWatch()
                        }
                    } label: {
                        Text("Cancel Search")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .glassPill(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(14)
                .glassPill(16)
            } else {
                // CONNECTED & LIVE TELEMETRY STATE
                // Header Info Card
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(monitor.accentColor.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: deviceIcon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(monitor.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("\(monitor.connectedDeviceName) Connected")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            Circle()
                                .fill(Color.appleGreen)
                                .frame(width: 5.5, height: 5.5)
                        }
                        Text("Bluetooth Low Energy • Live Telemetry Active")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .glassPill(14)

                // Heart Rate Card
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.red)
                                .scaleEffect(heartPulse ? 1.20 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: heartPulse)
                            Text("HEART RATE")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        Spacer()
                        Text("LIVE SYNC")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.appleGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appleGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(monitor.watchHeartRate)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("BPM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.red.opacity(0.9))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Normal Resting Rate")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.appleGreen)
                            Text("65 - 82 BPM avg")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .glassPill(14)

                // Fitness Activity Rings & Motion
                HStack(spacing: 8) {
                    // Fitness Rings Summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTIVITY")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.8))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 5.5, height: 5.5)
                                Text("Move: 340 kcal")
                                    .font(.system(size: 8.5, weight: .semibold))
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 5.5, height: 5.5)
                                Text("Exercise: 28m")
                                    .font(.system(size: 8.5, weight: .semibold))
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.cyan).frame(width: 5.5, height: 5.5)
                                Text("Stand: 10 hrs")
                                    .font(.system(size: 8.5, weight: .semibold))
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPill(12)

                    // Wrist Haptic Status
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WRIST SENSOR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.8))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(monitor.accentColor)
                                Text("Haptics Active")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(Color.appleGreen)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "battery.100")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.appleGreen)
                                Text("\(monitor.watchBattery)% Battery")
                                    .font(.system(size: 8.5, weight: .semibold))
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 9))
                                    .foregroundStyle(monitor.accentColor)
                                Text("Ultra-low Latency")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPill(12)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        monitor.disconnectAppleWatch()
                    }
                } label: {
                    Text("Disconnect Watch")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.red.opacity(0.80))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .glassPill(8)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            startHeartbeatSimulation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startHeartbeatSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            guard monitor.watchConnected else { return }
            heartPulse.toggle()
            if Int.random(in: 0...3) == 0 {
                let delta = Int.random(in: -2...2)
                monitor.watchHeartRate = max(64, min(86, monitor.watchHeartRate + delta))
            }
        }
    }
}

// MARK: - Main Posture View

struct PostureView: View {
    @ObservedObject private var monitor = PostureMonitor.shared
    @State private var currentTab: AppTab = .monitor
    @State private var settingsHovered = false
    @State private var backHovered = false

    private var statusColor: Color {
        if !monitor.calibrated { return Color.secondary }
        let ratio = monitor.thresholdDeg > 0 ? monitor.effectiveDeg / monitor.thresholdDeg : 0.0
        if ratio <= 0.70 {
            return monitor.accentColor
        } else if ratio <= 1.0 {
            let t = (ratio - 0.70) / 0.30
            return monitor.accentColor.blend(with: Color.appleOrange, amount: t)
        } else {
            let t = min(1.0, (ratio - 1.0) / 0.5)
            return Color.appleOrange.blend(with: Color.appleRed, amount: t)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 9) {
                header
                switch currentTab {
                case .monitor:
                    VStack(spacing: 9) {
                        LiveSpineGauge(monitor: monitor, statusColor: statusColor)
                        statPills
                        CompactStatusCard(monitor: monitor)
                        InteractiveCalibrateButton(monitor: monitor)
                        sensitivitySection
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .report:
                    WeeklyReportView()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .watch:
                    AppleWatchLiveView()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .settings:
                    settingsPanel
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .onboarding:
                    OnboardingView(currentTab: $currentTab)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                footer
            }
            .padding(14)
            .frame(width: 292)

            if !monitor.hasAskedAppleWatch && currentTab != .onboarding {
                AppleWatchPromptModal(monitor: monitor)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: monitor.slouching)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: monitor.calibrated)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: monitor.hasAskedAppleWatch)
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                currentTab = .onboarding
            }
        }
    }

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SENSITIVITY")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.7))
            SegPicker(value: $monitor.thresholdDeg,
                      options: [("Relaxed", 18), ("Balanced", 12), ("Strict", 8), ("Expert", 5)])

            Text("ALERT AFTER")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.top, 2)
            SegPicker(value: Binding(
                get: { monitor.graceSeconds },
                set: { newVal in
                    monitor.graceSeconds = newVal
                    monitor.lastAlert = .distantPast
                }
            ), options: [("Instant", 3), ("10 sec", 10), ("30 sec", 30)])
        }
    }

    private var headerSubtitle: String {
        switch currentTab {
        case .monitor: return "AirPods Posture Intelligence"
        case .report: return "Weekly Posture Analytics"
        case .watch: return "Apple Watch Live Telemetry"
        case .settings: return "Settings & Customization"
        case .onboarding: return "Welcome Setup"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("FixMySpine")
                    .font(.system(size: 15, weight: .bold))
                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .tracking(0.5)
            }
            Spacer()
            HStack(spacing: 6) {
                if currentTab == .monitor {
                    HStack(spacing: 8) {
                        MotionSensorPulse()

                        Divider()
                            .opacity(0.25)
                            .frame(height: 12)

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                currentTab = .settings
                            }
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(settingsHovered ? 1.0 : 0.80))
                                .scaleEffect(settingsHovered ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in withAnimation(.easeInOut(duration: 0.18)) { settingsHovered = h } }
                        .help("Settings")
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .glassPill(10)
                } else {
                    HStack(spacing: 8) {
                        MotionSensorPulse()

                        Divider()
                            .opacity(0.25)
                            .frame(height: 12)

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                currentTab = .monitor
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(monitor.accentColor)
                            .scaleEffect(backHovered ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in withAnimation(.easeInOut(duration: 0.18)) { backHovered = h } }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .glassPill(10)
                }
            }
        }
    }

// MARK: - Dedicated Apple Watch Settings Card

struct AppleWatchSettingsCard: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var isTestingHaptic = false
    @State private var testSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(monitor.accentColor)
                    Text("APPLE WATCH HAPTIC SYNC")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .tracking(0.6)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(monitor.appleWatchEnabled ? Color.appleGreen : Color.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(monitor.appleWatchEnabled ? "Connected" : "Off")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(monitor.appleWatchEnabled ? Color.appleGreen : Color.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(monitor.appleWatchEnabled ? Color.appleGreen.opacity(0.14) : Color.black.opacity(0.14))
                .clipShape(Capsule())
            }

            VStack(spacing: 0) {
                ToggleRow(icon: "applewatch.side.right", label: "Wrist Haptic Alerts", isOn: $monitor.appleWatchEnabled)
                Divider().opacity(0.20).padding(.horizontal, 14)
                ToggleRow(icon: "waveform.path.ecg", label: "Vibrate on Bad Posture", isOn: $monitor.vibrateOnSlouch)
            }
            .glassPill(12)

            if monitor.appleWatchEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HAPTIC INTENSITY")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.7))

                    SegPicker(value: Binding(
                        get: { Double(monitor.hapticIntensity) },
                        set: { monitor.hapticIntensity = Int($0) }
                    ), options: [("Gentle", 0), ("Medium", 1), ("Strong", 2)])

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isTestingHaptic = true
                        }
                        monitor.testWatchHaptic()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isTestingHaptic = false
                                testSuccess = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation { testSuccess = false }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: testSuccess ? "checkmark.circle.fill" : "hand.tap.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(testSuccess ? "Wrist Haptic Sent!" : (isTestingHaptic ? "Sending Wrist Tap…" : "Test Watch Vibration"))
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundStyle(testSuccess ? Color.appleGreen : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(monitor.accentColor.opacity(0.20))
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .glassPill(16)
    }
}

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reminders & Notifications Section
            VStack(alignment: .leading, spacing: 6) {
                Text("REMINDERS & NOTIFICATIONS")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

                VStack(spacing: 0) {
                    ToggleRow(icon: "speaker.wave.2.fill", label: "Voice reminders", isOn: $monitor.voiceEnabled)
                    Divider().opacity(0.20).padding(.horizontal, 14)
                    ToggleRow(icon: "bell.badge.fill", label: "Notifications", isOn: $monitor.notificationsEnabled)
                }
                .glassPill(16)
            }

            // Dedicated Apple Watch Haptic Section
            AppleWatchSettingsCard()

            // Accent Color Section (Native HSB Sliders & Advanced Color Picker)
            NativeColorCustomizationCard()

            // Report Issue Section
            VStack(alignment: .leading, spacing: 6) {
                Text("HELP & FEEDBACK")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

                ReportIssueCard(accentColor: monitor.accentColor) {
                    reportIssue()
                }
            }

            // About & Updates Section
            VStack(alignment: .leading, spacing: 6) {
                Text("ABOUT & UPDATES")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("FixMySpine")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text("Version \(AppInfo.version)")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Privacy")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(monitor.accentColor)
                            Text("100% Local Processing")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Color.appleGreen)
                        }
                    }

                    Divider().opacity(0.18)

                    Button {
                        UpdateChecker.check(silentIfLatest: false)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                            Text("Check for Updates…")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5.5)
                        .glassPill(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassPill(16)
            }

            // Done Button
            InteractiveDoneButton(accentColor: monitor.accentColor) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    currentTab = .monitor
                }
            }
            .padding(.top, 2)
        }
    }

    private func reportIssue() {
        let email = "ombichave639@gmail.com"
        let subject = "FixMySpine Issue / Feedback"
        let body = "Hi,\n\nI would like to report an issue or share feedback regarding FixMySpine:\n\n"
        let encSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(email)?subject=\(encSubject)&body=\(encBody)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private var statPills: some View {
        HStack(spacing: 6) {
            statPill(label: "Head Pitch", value: monitor.nodDeg, isNod: true, icon: "arrow.up.and.down")
            statPill(label: "Side Lean", value: monitor.sideDeg, isNod: false, icon: "arrow.left.and.right")
        }
    }

    private func statPill(label: String, value: Double, isNod: Bool, icon: String) -> some View {
        let displayVal: String
        let isZeroPerfect: Bool
        if !monitor.calibrated {
            displayVal = "Standby"
            isZeroPerfect = false
        } else {
            let rounded = abs(value.rounded())
            if rounded == 0 {
                displayVal = "0° Perfect"
                isZeroPerfect = true
            } else if isNod {
                displayVal = String(format: "%.0f° %@", rounded, value >= 0 ? "Down" : "Up")
                isZeroPerfect = false
            } else {
                displayVal = String(format: "%.0f° %@", rounded, value >= 0 ? "Right" : "Left")
                isZeroPerfect = false
            }
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(monitor.calibrated ? monitor.accentColor : .secondary)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.80)
            Spacer(minLength: 2)
            Text(displayVal)
                .font(.system(size: 9.5, weight: monitor.calibrated ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isZeroPerfect ? monitor.accentColor : (monitor.calibrated ? Color.primary : .secondary.opacity(0.6)))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .glassPill(12)
    }

struct ToggleRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    @ObservedObject private var monitor = PostureMonitor.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(monitor.accentColor)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

    private var footer: some View {
        HStack(spacing: 0) {
            RefinedBottomToolbarItem(
                icon: monitor.monitoring ? "pause.fill" : "play.fill",
                label: monitor.monitoring ? "Pause" : "Resume",
                isActive: monitor.monitoring,
                action: { if monitor.monitoring { monitor.stop() } else { monitor.start() } },
                helpText: monitor.monitoring ? "Pause tracking" : "Resume tracking"
            )

            Divider().opacity(0.25).frame(height: 14)

            RefinedBottomToolbarItem(
                icon: "applewatch",
                label: "Watch",
                isActive: currentTab == .watch,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = (currentTab == .watch) ? .monitor : .watch
                    }
                },
                helpText: "Apple Watch Live Telemetry & Health"
            )

            Divider().opacity(0.25).frame(height: 14)

            RefinedBottomToolbarItem(
                icon: "chart.bar.fill",
                label: "Reports",
                isActive: currentTab == .report,
                action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        currentTab = (currentTab == .report) ? .monitor : .report
                    }
                },
                helpText: "Weekly Posture Report"
            )

            Divider().opacity(0.25).frame(height: 14)

            RefinedBottomToolbarItem(
                icon: "power",
                label: "Quit",
                isActive: false,
                action: { NSApplication.shared.terminate(nil) },
                helpText: "Quit FixMySpine"
            )
        }
        .glassPill(12)
        .padding(.top, 4)
    }
}

// MARK: - App Delegate (Menu Bar + Popover)

// MARK: - Posture Color Interpolator

func interpolatePostureColor(effectiveDeg: Double, thresholdDeg: Double, isSlouching: Bool, isCalibrated: Bool, isReceiving: Bool) -> NSColor {
    guard isReceiving, isCalibrated, thresholdDeg > 0 else {
        return .labelColor
    }

    let ratio = max(0.0, min(1.25, effectiveDeg / thresholdDeg))

    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let baseR: CGFloat = isDark ? 1.0 : 0.15
    let baseG: CGFloat = isDark ? 1.0 : 0.15
    let baseB: CGFloat = isDark ? 1.0 : 0.15

    let orangeR: CGFloat = 1.0, orangeG: CGFloat = 0.60, orangeB: CGFloat = 0.12
    let redR: CGFloat = 1.0, redG: CGFloat = 0.23, redB: CGFloat = 0.19

    if ratio <= 0.35 && !isSlouching {
        return .labelColor
    } else if ratio <= 0.75 && !isSlouching {
        let t = CGFloat((ratio - 0.35) / (0.75 - 0.35))
        let r = baseR + (orangeR - baseR) * t
        let g = baseG + (orangeG - baseG) * t
        let b = baseB + (orangeB - baseB) * t
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    } else {
        let t = CGFloat(min(1.0, max(0.0, (ratio - 0.75) / 0.35)))
        let r = orangeR + (redR - orangeR) * t
        let g = orangeG + (redG - orangeG) * t
        let b = orangeB + (redB - orangeB) * t
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

func createSpineMenuIcon(effectiveDeg: Double, nodDeg: Double, sideDeg: Double, isSlouching: Bool, isReceiving: Bool, isCalibrated: Bool, color: NSColor) -> NSImage {
    let pointSize: CGFloat = 18.0
    let isTemplate = (color == .labelColor || color == .controlTextColor || color == .textColor)
    let drawColor = isTemplate ? NSColor.black : color

    let maxAngle: Double = 30.0
    let normSide = (sideDeg / maxAngle).clamped(to: -1...1)
    let normNod = (nodDeg / maxAngle).clamped(to: -1...1)

    let dx = (isReceiving && isCalibrated) ? CGFloat(normSide) * 3.5 : 0.0
    let dy = (isReceiving && isCalibrated) ? CGFloat(normNod) * 1.8 : 0.0

    let img = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { bounds in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // 1. Floating Head Circle Node (Top Right)
        let headX = 11.2 + dx
        let headY = 13.8 - dy
        ctx.setFillColor(drawColor.cgColor)
        ctx.addEllipse(in: CGRect(x: headX - 2.2, y: headY - 2.2, width: 4.4, height: 4.4))
        ctx.fillPath()

        // 2. Liquid Body Ribbon (Left Shoulder -> Right Arch Neck -> Waist -> Right Base Foot)
        let path = CGMutablePath()
        let shoulderLeft = CGPoint(x: 3.4, y: 10.0)
        let neckArchRight = CGPoint(x: 10.8 + dx * 0.4, y: 10.0 - dy * 0.3)
        let waistLeft = CGPoint(x: 7.4, y: 3.6)
        let footBaseRight = CGPoint(x: 10.4, y: 2.0)

        path.move(to: shoulderLeft)
        path.addCurve(to: neckArchRight, control1: CGPoint(x: 5.6, y: 12.0), control2: CGPoint(x: 10.0, y: 12.2))
        path.addCurve(to: waistLeft, control1: CGPoint(x: 11.6, y: 7.8), control2: CGPoint(x: 7.8, y: 5.6))
        path.addCurve(to: footBaseRight, control1: CGPoint(x: 7.0, y: 2.4), control2: CGPoint(x: 9.0, y: 1.6))

        ctx.setLineWidth(2.6)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(drawColor.cgColor)
        ctx.addPath(path)
        ctx.strokePath()

        return true
    }

    img.isTemplate = isTemplate
    img.accessibilityDescription = "FixMySpine Posture Monitor"
    return img
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var standaloneWindow: NSWindow?
    private let monitor = PostureMonitor.shared
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: PostureView())
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "FixMySpine - AirPods Posture Monitor (Click to Open)"
        }

        monitor.objectWillChange
            .throttle(for: .milliseconds(33), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.refreshButton() }
            .store(in: &bag)
        refreshButton()

        if monitor.available { monitor.start() }

        // Automatically open the popover or window on launch so the user immediately sees the interface
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showPopover(nil)
        }

        // Silently check for app updates via Sparkle appcast feed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UpdateChecker.check(silentIfLatest: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover(nil)
        return true
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }

        let color = interpolatePostureColor(
            effectiveDeg: monitor.effectiveDeg,
            thresholdDeg: monitor.thresholdDeg,
            isSlouching: monitor.slouching,
            isCalibrated: monitor.calibrated,
            isReceiving: monitor.receiving
        )

        let spineIcon = createSpineMenuIcon(
            effectiveDeg: monitor.effectiveDeg,
            nodDeg: monitor.nodDeg,
            sideDeg: monitor.sideDeg,
            isSlouching: monitor.slouching,
            isReceiving: monitor.receiving,
            isCalibrated: monitor.calibrated,
            color: color
        )
        spineIcon.size = NSSize(width: 18, height: 18)

        button.image = spineIcon
        button.imagePosition = .imageLeading
        button.toolTip = "FixMySpine - AirPods Posture Monitor"

        if monitor.calibrated {
            let degInt = Int(monitor.effectiveDeg.rounded())
            let formattedStr: String = degInt < 10 ? "\(degInt)°\u{2007}" : "\(degInt)°"
            button.attributedTitle = NSAttributedString(
                string: formattedStr,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
                ])
        } else {
            button.attributedTitle = NSAttributedString(
                string: "Spine",
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
                ])
        }
    }

    @objc func showPopover(_ sender: AnyObject?) {
        NSApp.activate(ignoringOtherApps: true)
        guard let button = statusItem?.button,
              let win = button.window,
              win.frame.origin.y > 100 else {
            showStandaloneWindow()
            return
        }
        if let host = popover.contentViewController as? NSHostingController<PostureView> {
            popover.contentSize = host.view.fittingSize
        }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showStandaloneWindow() {
        if standaloneWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 310, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "FixMySpine"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentViewController = NSHostingController(rootView: PostureView())
            window.center()
            window.isReleasedWhenClosed = false
            self.standaloneWindow = window
        }
        standaloneWindow?.center()
        standaloneWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let win = standaloneWindow, win.isVisible {
            win.orderOut(nil)
        } else {
            showPopover(sender)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

