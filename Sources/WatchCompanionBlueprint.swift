//
//  WatchCompanionBlueprint.swift
//  FixMySpine watchOS Companion Target Blueprint
//

import SwiftUI
import WatchKit
import WatchConnectivity

// MARK: - Watch Connectivity Manager for watchOS

final class WatchOSSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchOSSessionManager()

    @Published private(set) var liveScore: Int = 100
    @Published private(set) var tiltDeg: Double = 0.0
    @Published private(set) var nodDeg: Double = 0.0
    @Published private(set) var sideDeg: Double = 0.0
    @Published private(set) var isSlouching: Bool = false
    @Published private(set) var isMacConnected: Bool = false

    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isMacConnected = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                if type == "telemetry" {
                    if let s = message["score"] as? Int { self.liveScore = s }
                    if let t = message["tiltDeg"] as? Double { self.tiltDeg = t }
                    if let n = message["nodDeg"] as? Double { self.nodDeg = n }
                    if let sd = message["sideDeg"] as? Double { self.sideDeg = sd }
                    if let sl = message["slouching"] as? Bool { self.isSlouching = sl }
                } else if type == "hapticAlert" {
                    WKInterfaceDevice.current().play(.notification)
                }
            }
            self.isMacConnected = true
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isMacConnected = session.isReachable
        }
    }
}

// MARK: - WatchOS View Component

struct FixMySpineWatchView: View {
    @ObservedObject var session = WatchOSSessionManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(session.isSlouching ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: CGFloat(session.liveScore) / 100.0)
                    .stroke(session.isSlouching ? Color.red : Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(session.liveScore)%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(session.isSlouching ? "Slouching" : "Good Posture")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(session.isSlouching ? Color.red : Color.green)
                }
            }
            .frame(width: 90, height: 90)

            HStack {
                Circle()
                    .fill(session.isMacConnected ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(session.isMacConnected ? "Mac Connected" : "Standby")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
