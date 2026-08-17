# Project Abstract & Synopsis

## Project Title
**FixMySpine: A Real-Time Posture Tracking and Alert System for macOS Using Apple AirPods**

---

### Submitted By:
- **Project Type:** 3rd Year Engineering Project
- **Domain:** Ubiquitous Computing, Ergonomics & Human-Computer Interaction (HCI)
- **Target Platform:** Apple Ecosystem (macOS, iOS, iPadOS)

---

## 1. Abstract

**FixMySpine is a smart desktop application built exclusively for the Apple ecosystem to detect bad sitting posture and help users sit straight while working on their computers.** Today, students and professionals spend several hours every day sitting in front of screens. Over time, most people unknowingly slouch, lean to one side, or bend their neck forward toward the screen. This bad habit puts continuous stress on the neck and spine, leading to neck stiffness, headaches, and long-term back pain.

Most existing posture correction apps rely on webcams to watch the user continuously. However, this causes serious privacy concerns and quickly drains the laptop battery. **FixMySpine solves this problem in a smart, camera-free way by using the built-in motion sensors inside Apple AirPods.**

The working of the application is simple:
1. The user connects their AirPods to their Mac, sits in their natural straight posture, and clicks a single **Calibrate** button to set their baseline.
2. As the user works, FixMySpine continuously monitors head tilt and forward bending angles in the background.
3. If the user slouches or bends their neck down past the set limit for more than a few seconds, the app automatically alerts them with a gentle voice reminder (such as *"Straighten up a little"*) and a screen notification to correct their posture.

**Current Status (Ready Now):**  
The core **macOS and AirPods application is fully developed, tested, and working**. It includes a live visual spine gauge in the Mac menu bar, customizable timer settings, and a built-in analytics dashboard that tracks daily posture scores and weekly progress charts. It runs 100% locally on the Mac without needing internet or camera access, ensuring complete privacy and high battery efficiency.

**Future Scope:**  
While the current version is completely ready for Mac users, the project will be expanded in the next phase to include:
- **iOS (iPhone) Version with AirPods:** To monitor posture while studying, reading, or working on mobile devices.
- **iPadOS (iPad) Version:** For students and digital artists using iPads at study desks.
- **Apple Watch Integration:** To deliver silent, gentle haptic vibrations directly on the wrist whenever bad posture is detected.

---

## 2. Key Objectives & Features

- **Non-Invasive Tracking:** Eliminates the need for awkward posture braces or continuous webcam video feeds.
- **100% Privacy Protection:** All motion calculations happen directly on the device with zero camera access and zero cloud data transfer.
- **Multi-Modal Biofeedback:** Provides real-time alerts through three channels:
  - *Auditory:* Subtle voice reminders cycling through helpful posture cues.
  - *Visual:* Dynamic biomorphic spine gauge in the macOS menu bar and desktop notifications.
  - *Haptic (Future):* Silent wrist tap via Apple Watch.
- **Habit Formation & Analytics:** Tracks daily posture quality percentages and weekly charts to encourage long-term posture correction.

---

## 3. System Workflow

```
+--------------------------+
|      Apple AirPods       |  (Captures 3D Motion & Tilt Data)
+--------------------------+
             |
             v
+--------------------------+
|  Apple CoreMotion API    |  (Extracts Pitch & Roll Angles)
+--------------------------+
             |
             v
+--------------------------+
|   FixMySpine Engine      |  (Compares against Calibrated Baseline)
+--------------------------+
             |
             +-------------------------+
             |                         |
     [Posture is Normal]       [Slouch Detected > Grace Period]
             |                         |
             v                         v
     (Update Progress)       +-----------------------------------+
                             |  Multi-Modal Alerts Triggered:    |
                             |  1. Spoken Voice Reminder         |
                             |  2. Mac Banner Notification       |
                             |  3. Menu Bar Spine Gauge (Red)    |
                             +-----------------------------------+
```

---

## 4. Technical Specifications

| Parameter | Details |
| :--- | :--- |
| **Operating System** | macOS 14.0+ (Sonoma / Sequoia) |
| **Programming Language** | Swift 6.0 |
| **UI Framework** | SwiftUI (Native Apple Dark Glass design) |
| **System Frameworks** | CoreMotion, AVFoundation, UserNotifications, Cocoa |
| **Supported Hardware (Current)** | Apple Mac + AirPods Pro / Max / 3rd Gen |
| **Planned Hardware (Future Scope)** | Apple iPhone (iOS), Apple iPad (iPadOS), Apple Watch (watchOS) |
| **Network Dependency** | None (100% Offline & Local) |
