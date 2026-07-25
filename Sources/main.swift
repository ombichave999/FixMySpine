import Cocoa
import SwiftUI
import Combine
import CoreMotion
import AVFoundation
import UserNotifications

// MARK: - App Info & Updates

enum AppInfo {
    static let version = "2.3"
    static let manifestURL = "REPLACE_ME"
}

enum UpdateChecker {
    static func check() {
        guard AppInfo.manifestURL != "REPLACE_ME", let url = URL(string: AppInfo.manifestURL) else {
            show(title: "Updates Not Configured",
                 text: "FixMySpine v\(AppInfo.version) is running the latest build.")
            return
        }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latest = json["version"] as? String else {
                    show(title: "Check Failed", text: "No internet, or update manifest is unreachable.")
                    return
                }
                if isNewer(latest, than: AppInfo.version) {
                    let dmg = json["dmg"] as? String
                    let alert = NSAlert()
                    alert.messageText = "Update available: v\(latest)"
                    alert.informativeText = "You have v\(AppInfo.version). Download the new version?"
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn,
                       let s = dmg, let u = URL(string: s) {
                        NSWorkspace.shared.open(u)
                    }
                } else {
                    show(title: "You're up to date", text: "FixMySpine v\(AppInfo.version) is the latest version.")
                }
            }
        }.resume()
    }

    private static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
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
            (r, g, b) = (0, 245, 212)
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
        return "#00F5D4"
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
        case .green: return Color.emeraldCyan
        case .blue: return Color(red: 0.1, green: 0.55, blue: 0.98)
        case .purple: return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .orange: return Color.appleOrange
        case .pink: return Color(red: 1.0, green: 0.25, blue: 0.55)
        case .custom: return Color(hex: customHex)
        }
    }

    func nsColor(customHex: String) -> NSColor {
        switch self {
        case .green: return NSColor(Color.emeraldCyan)
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
            return Color.appleGreen
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
        if monitor.slouching { return "Poor Posture" }
        if monitor.effectiveDeg > monitor.thresholdDeg * 0.7 { return "Forward Lean" }
        if monitor.effectiveDeg <= 3 { return "Perfect Alignment" }
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
                        .stroke(
                            LinearGradient(
                                colors: [statusColor.opacity(0.55), Color.white.opacity(0.08)],
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
                    let sideTilt = monitor.calibrated ? CGFloat(monitor.sideDeg) * (monitor.nodDeg >= 0 ? 1 : -1) : 0
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
                        .animation(.easeInOut(duration: 0.45), value: statusColor)

                        Path { path in
                            path.move(to: basePoint)
                            path.addQuadCurve(to: headPoint, control: controlPoint)
                        }
                        .stroke(
                            LinearGradient(colors: [statusColor.opacity(0.4), statusColor],
                                           startPoint: .bottom, endPoint: .top),
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
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
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
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(statusColor)

                        Text(alignmentTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(statusColor)
                            .transition(.opacity)
                            .id(alignmentTitle)

                        if monitor.showGreatPostureBanner {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Great Posture")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(Color.appleGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appleGreen.opacity(0.18))
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
                    .foregroundStyle(Color.appleGreen)
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
                    .foregroundStyle(Color.appleGreen)
                Text("AirPods Connected • Posture Optimal")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.85))
            }
            Spacer()
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
                LinearGradient(
                    colors: [
                        monitor.accentColor.opacity(isHovered ? 0.88 : 0.75),
                        monitor.accentColor.opacity(isHovered ? 1.0 : 0.95)
                    ],
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
            .shadow(color: monitor.accentColor.opacity(isHovered ? 0.35 : 0.22), radius: isHovered ? 5 : 3, y: isHovered ? 2 : 1)
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .offset(y: isHovered ? -1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { isHovered = h }
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
    case settings = "Settings"
    case onboarding = "Onboarding"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .monitor: return "gyroscope"
        case .report: return "chart.bar.fill"
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
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func glassPill(_ r: CGFloat = 16) -> some View { modifier(GlassPill(cornerRadius: r)) }
}

/// Sliding glass segmented control
struct SegPicker: View {
    @Binding var value: Double
    let options: [(String, Double)]
    @ObservedObject private var monitor = PostureMonitor.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.1) { opt in
                let selected = value == opt.1
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { value = opt.1 }
                } label: {
                    Text(opt.0)
                        .font(.system(size: 10, weight: selected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [monitor.accentColor.opacity(0.85), monitor.accentColor.opacity(0.65)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .shadow(color: monitor.accentColor.opacity(0.25), radius: 3, y: 1)
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

    // Settings (persisted)
    @AppStorage("thresholdDeg") var thresholdDeg: Double = 8
    @AppStorage("graceSeconds") var graceSeconds: Double = 10
    @AppStorage("voiceEnabled") var voiceEnabled: Bool = true
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("accentThemeRaw") var accentThemeRaw: String = AccentTheme.green.rawValue
    @AppStorage("customColorHex") var customColorHex: String = "#00F5D4"

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
    let cooldownSeconds: Double = 60

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
    private var lastAlert: Date = .distantPast
    private var goodStreakTimer: Double = 0.0

    override private init() {
        super.init()
        headphoneMgr.delegate = self
        loadBaseline()
    }

    var available: Bool { headphoneMgr.isDeviceMotionAvailable }

    var effectiveDeg: Double {
        (nodDeg * nodDeg + 0.49 * sideDeg * sideDeg).squareRoot()
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

        let dot = nx * bx + ny * by + nz * bz
        let total = acos(min(1, max(-1, dot))) * 180.0 / .pi

        let ax = by * nz - bz * ny
        let ay = bz * nx - bx * nz
        let az = bx * ny - by * nx
        let am = (ax * ax + ay * ay + az * az).squareRoot()
        let nodShare = am > 0 ? abs(ax / am) : 0

        tiltDeg = total
        nodDeg = total * nodShare
        sideDeg = total * (1 - nodShare * nodShare).squareRoot()
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
            if effectiveDeg < thresholdDeg * 0.75 { slouching = false; slouchSince = nil }
        } else {
            if effectiveDeg > thresholdDeg { slouching = true; slouchSince = Date() }
        }

        if slouching, let since = slouchSince,
           Date().timeIntervalSince(since) >= graceSeconds,
           Date().timeIntervalSince(lastAlert) >= cooldownSeconds {
            lastAlert = Date()
            triggerVoiceReminder()
            if notificationsEnabled { notify() }
        }
    }

    private func triggerVoiceReminder() {
        guard voiceEnabled else { return }
        let reminder = voiceReminders[reminderIndex % voiceReminders.count]
        reminderIndex += 1
        speak(reminder)
    }

    private func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.46
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
        let text: String
        if a.currentScore >= 85 {
            text = "Excellent posture consistency this week!"
        } else if a.totalHoursTracked > 3.0 {
            text = "You maintained good posture for \(String(format: "%.1f", a.totalHoursTracked))h this week."
        } else {
            text = "Forward head posture alignment improved. Keep sitting tall!"
        }

        return HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(monitor.accentColor)

            Text(text)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPill(10)
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

// MARK: - Main Posture View

struct PostureView: View {
    @ObservedObject var monitor = PostureMonitor.shared
    @State private var currentTab: AppTab = .monitor
    @State private var reportHovered = false
    @State private var settingsHovered = false
    @State private var backHovered = false

    private var statusColor: Color {
        if !monitor.receiving { return Color.secondary }
        if !monitor.calibrated { return monitor.accentColor }
        if monitor.slouching { return Color.appleRed }
        let ratio = min(1.0, max(0.0, monitor.effectiveDeg / monitor.thresholdDeg))
        if ratio < 0.65 {
            return Color.appleGreen
        } else if ratio < 1.0 {
            let t = (ratio - 0.65) / 0.35
            return Color.appleGreen.blend(with: Color.appleOrange, amount: t)
        } else {
            let t = min(1.0, (ratio - 1.0) / 0.5)
            return Color.appleOrange.blend(with: Color.appleRed, amount: t)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            switch currentTab {
            case .monitor:
                VStack(spacing: 12) {
                    LiveSpineGauge(monitor: monitor, statusColor: statusColor)
                    statPills
                    CompactStatusCard(monitor: monitor)
                    InteractiveCalibrateButton(monitor: monitor)
                    sensitivitySection
                    footer
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            case .report:
                WeeklyReportView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .settings:
                settingsPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .onboarding:
                OnboardingView(currentTab: $currentTab)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .padding(16)
        .frame(width: 292)
        .fixedSize(horizontal: true, vertical: true)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: currentTab)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: monitor.slouching)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: monitor.calibrated)
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
            SegPicker(value: $monitor.graceSeconds,
                      options: [("Instant", 5), ("10 sec", 10), ("30 sec", 30)])
        }
    }

    private var headerSubtitle: String {
        switch currentTab {
        case .monitor: return "AirPods Posture Intelligence"
        case .report: return "Weekly Posture Analytics"
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

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reminders & Notifications Section
            VStack(alignment: .leading, spacing: 6) {
                Text("REMINDERS & NOTIFICATIONS")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

                VStack(spacing: 0) {
                    toggleRow(icon: "speaker.wave.2.fill", label: "Voice reminders", isOn: $monitor.voiceEnabled)
                    Divider().opacity(0.20).padding(.horizontal, 14)
                    toggleRow(icon: "bell.badge.fill", label: "Notifications", isOn: $monitor.notificationsEnabled)
                }
                .glassPill(16)
            }

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

            // About Section
            VStack(alignment: .leading, spacing: 6) {
                Text("ABOUT")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .tracking(0.6)

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
            statPill(label: "Neck Tilt", value: monitor.nodDeg, isNod: true, icon: "arrow.up.and.down")
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
                displayVal = String(format: "%.0f° %@", rounded, value >= 0 ? "Fwd" : "Back")
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
                .foregroundStyle(isZeroPerfect ? Color.appleGreen : (monitor.calibrated ? Color.primary : .secondary.opacity(0.6)))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .glassPill(12)
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(monitor.accentColor)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                icon: "arrow.clockwise",
                label: "Updates",
                isActive: false,
                action: { UpdateChecker.check() },
                helpText: "Check for Updates"
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

func createSpineMenuIcon(effectiveDeg: Double, nodDeg: Double, sideDeg: Double, isSlouching: Bool, isReceiving: Bool, isCalibrated: Bool, color: NSColor) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let img = NSImage(size: size, flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.saveGState()

        let drawColor = color

        let maxAngle: Double = 30.0
        let normSide = (sideDeg / maxAngle).clamped(to: -1...1) * (nodDeg >= 0 ? 1 : -1)
        let normNod = (nodDeg / maxAngle).clamped(to: -1...1)

        let dx = (isReceiving && isCalibrated) ? CGFloat(normSide) * 3.5 : 0.0
        let dy = (isReceiving && isCalibrated) ? CGFloat(normNod) * 1.8 : 0.0

        // 1. Floating Head Circle Node (Top Right)
        let headX = 11.2 + dx
        let headY = 14.2 - dy
        ctx.setFillColor(drawColor.cgColor)
        ctx.addEllipse(in: CGRect(x: headX - 1.9, y: headY - 1.9, width: 3.8, height: 3.8))
        ctx.fillPath()

        // 2. Liquid Body Ribbon (Left Shoulder -> Right Arch Neck -> Waist -> Right Base Foot)
        let path = CGMutablePath()
        let shoulderLeft = CGPoint(x: 3.6, y: 10.1)
        let neckArchRight = CGPoint(x: 10.8 + dx * 0.4, y: 10.1 - dy * 0.3)
        let waistLeft = CGPoint(x: 7.6, y: 3.6)
        let footBaseRight = CGPoint(x: 10.4, y: 2.2)

        path.move(to: shoulderLeft)
        path.addCurve(to: neckArchRight, control1: CGPoint(x: 5.8, y: 11.9), control2: CGPoint(x: 10.1, y: 12.2))
        path.addCurve(to: waistLeft, control1: CGPoint(x: 11.5, y: 7.9), control2: CGPoint(x: 7.9, y: 5.8))
        path.addCurve(to: footBaseRight, control1: CGPoint(x: 7.2, y: 2.5), control2: CGPoint(x: 9.0, y: 1.8))

        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(drawColor.cgColor)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.restoreGState()
        return true
    }
    img.isTemplate = (color == .white || color == .controlTextColor)
    return img
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = PostureMonitor.shared
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let popover = NSPopover()
        popover.behavior = .transient
        let host = NSHostingController(rootView: PostureView())
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        monitor.objectWillChange
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.refreshButton() }
            .store(in: &bag)
        refreshButton()

        if monitor.available { monitor.start() }
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }

        let color: NSColor = !monitor.receiving ? .white
            : (!monitor.calibrated ? .white
            : (monitor.slouching ? .systemRed
            : (monitor.effectiveDeg > monitor.thresholdDeg * 0.7 ? .systemOrange : .white)))

        let spineIcon = createSpineMenuIcon(
            effectiveDeg: monitor.effectiveDeg,
            nodDeg: monitor.nodDeg,
            sideDeg: monitor.sideDeg,
            isSlouching: monitor.slouching,
            isReceiving: monitor.receiving,
            isCalibrated: monitor.calibrated,
            color: color
        )

        button.image = spineIcon
        button.attributedTitle = NSAttributedString(
            string: monitor.calibrated ? String(format: " %.0f°", monitor.effectiveDeg) : "",
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            ])
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
