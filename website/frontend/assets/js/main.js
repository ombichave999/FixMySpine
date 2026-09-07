/**
 * FixMySpine — macOS Desktop Simulator & Posture Intelligence Engine
 * 100% Exact Swift calculation & interaction model matching Sources/main.swift
 */

(function () {
  "use strict";

  // App State matching PostureMonitor in Swift
  const state = {
    nodDeg: 3.0,          // Forward / Backward Head Pitch
    sideDeg: -1.0,        // Left / Right Lateral Lean
    calibrated: true,
    monitoring: true,
    thresholdDeg: 12.0,   // Relaxed (18), Balanced (12), Strict (8), Expert (5)
    graceSeconds: 30,     // Instant (3), 10 sec (10), 30 sec (30)
    currentTab: "monitor",// monitor, reports, watch, settings
    theme: localStorage.getItem("fms-theme") || "green",
    popoverOpen: true,
    audioCtx: null
  };

  // Helper
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);
  const clamp = (val, min, max) => Math.max(min, Math.min(max, val));

  // DOM Elements
  const dom = {
    // Menu Bar
    mbFixMySpine: $("#mbFixMySpine"),
    mbExtraAngle: $("#mbExtraAngle"),
    mbOrigIcon: $("#mbOrigIcon"),
    mbClock: $("#mbClock"),
    mbStatusChip: $(".mb-status-chip"),

    // Popover Shell
    popover: $("#popover"),
    fmsHeaderSub: $("#fmsHeaderSub"),
    fmsBtnSettings: $("#fmsBtnSettings"),
    fmsSettingsIcon: $("#fmsSettingsIcon"),
    fmsBackLabel: $("#fmsBackLabel"),
    fmsSensorPulse: $("#fmsSensorPulse"),

    // Monitor Tab Elements
    tabPaneMonitor: $("#tabPaneMonitor"),
    tabPaneReports: $("#tabPaneReports"),
    tabPaneWatch: $("#tabPaneWatch"),
    tabPaneSettings: $("#tabPaneSettings"),
    fmsHeroGauge: $("#fmsHeroGauge"),
    fmsGaugeAura: $("#fmsGaugeAura"),
    fmsSpineSvg: $("#fmsSpineSvg"),
    fmsGaugeAngle: $("#fmsGaugeAngle"),
    fmsGaugeTitle: $("#fmsGaugeTitle"),
    fmsGreatBadge: $("#fmsGreatBadge"),
    fmsStatPitch: $("#fmsStatPitch"),
    fmsStatRoll: $("#fmsStatRoll"),
    fmsStatusCard: $("#fmsStatusCard"),
    fmsStatusText: $("#fmsStatusText"),
    fmsBtnCalibrate: $("#fmsBtnCalibrate"),
    fmsCalTitle: $("#fmsCalTitle"),

    // Hardware Simulation Widget
    hwPitchSlider: $("#hwPitchSlider"),
    hwPitchVal: $("#hwPitchVal"),
    hwRollSlider: $("#hwRollSlider"),
    hwRollVal: $("#hwRollVal"),
    airpods3dImg: $("#airpods3dImg"),
    btnDeskCalibrate: $("#btnDeskCalibrate"),
    btnTestChimeDesk: $("#btnTestChimeDesk"),
    btnTogglePopoverDesk: $("#btnTogglePopoverDesk"),

    // Footer Toolbar
    fmsFootPause: $("#fmsFootPause"),
    fmsPauseIcon: $("#fmsPauseIcon"),
    fmsPauseLabel: $("#fmsPauseLabel"),
    fmsFootWatch: $("#fmsFootWatch"),
    fmsFootReports: $("#fmsFootReports"),
    fmsFootQuit: $("#fmsFootQuit"),

    // Dock
    dockAppFixMySpine: $("#dockAppFixMySpine"),
    dockCalibrate: $("#dockCalibrate")
  };

  // ================= 1. POSTURE COLOR & TITLE CALCULATIONS (Swift parity) =================
  function computeEffectiveDeg() {
    return Math.sqrt(state.nodDeg * state.nodDeg + state.sideDeg * state.sideDeg);
  }

  function getStatusColor(effectiveDeg) {
    if (!state.calibrated) return "#8e8e93";
    const ratio = state.thresholdDeg > 0 ? effectiveDeg / state.thresholdDeg : 0.0;
    if (ratio <= 0.70) {
      return getComputedStyle(document.documentElement).getPropertyValue("--accent").trim() || "#00d053";
    } else if (ratio <= 1.0) {
      return "#ff9f0a"; // appleOrange
    } else {
      return "#ff453a"; // appleRed
    }
  }

  function getAlignmentTitle(effectiveDeg) {
    if (!state.calibrated) return "Standby • Tap Calibrate below";
    const isSlouching = effectiveDeg > state.thresholdDeg;
    if (isSlouching) {
      if (state.nodDeg < -3) {
        return Math.abs(state.sideDeg) > 3 ? (state.sideDeg > 0 ? "Backward & Right Lean" : "Backward & Left Lean") : "Backward Lean";
      } else if (state.nodDeg > 3) {
        return Math.abs(state.sideDeg) > 3 ? (state.sideDeg > 0 ? "Forward & Right Lean" : "Forward & Left Lean") : "Forward Lean";
      } else if (Math.abs(state.sideDeg) > 3) {
        return state.sideDeg > 0 ? "Right Side Lean" : "Left Side Lean";
      } else {
        return "Spine Slouched";
      }
    }
    if (effectiveDeg > state.thresholdDeg * 0.7) {
      if (state.nodDeg < -3) return "Backward Lean";
      if (state.nodDeg > 3) return "Forward Lean";
      if (Math.abs(state.sideDeg) > 3) return state.sideDeg > 0 ? "Right Side Lean" : "Left Side Lean";
      return "Forward Lean";
    }
    if (effectiveDeg <= 2.5) return "Perfect Alignment";
    return "Good Posture";
  }

  // ================= 2. LIVE SPINE SVG RENDERER (Exact LiveSpineGauge Geometry) =================
  function renderSpineSvg(effectiveDeg, statusColor) {
    if (!dom.fmsSpineSvg) return;

    const w = 260;
    const h = 115;
    const basePoint = { x: w / 2, y: h * 0.82 }; // 130, 94.3

    const maxTilt = 30.0;
    const sideTilt = state.calibrated ? state.sideDeg : 0;
    const nodTilt = state.calibrated ? state.nodDeg : 0;

    const sideOffset = clamp(sideTilt / maxTilt, -1, 1) * 36.0;
    const nodOffset = clamp(nodTilt / maxTilt, -1, 1) * 22.0;

    const headPoint = { x: w / 2 + sideOffset, y: h * 0.22 + nodOffset };
    const controlPoint = { x: w / 2 + sideOffset * 0.42, y: h * 0.52 + nodOffset * 0.28 };

    // Build 5 vertebrae circles
    let vertebraeSvg = "";
    for (let i = 1; i <= 5; i++) {
      const t = i / 6.0;
      const vx = (1 - t) * (1 - t) * basePoint.x + 2 * (1 - t) * t * controlPoint.x + t * t * headPoint.x;
      const vy = (1 - t) * (1 - t) * basePoint.y + 2 * (1 - t) * t * controlPoint.y + t * t * headPoint.y;
      vertebraeSvg += `<circle cx="${vx.toFixed(2)}" cy="${vy.toFixed(2)}" r="2.1" fill="${statusColor}" filter="drop-shadow(0 0 3px ${statusColor})" />`;
    }

    dom.fmsSpineSvg.innerHTML = `
      <defs>
        <filter id="headGlow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <!-- Head Aura Radial -->
      <circle cx="${headPoint.x.toFixed(2)}" cy="${headPoint.y.toFixed(2)}" r="18" fill="${statusColor}" opacity="0.25" filter="url(#headGlow)" />

      <!-- Quad Bezier Curve (Dashed Spine Track) -->
      <path d="M ${basePoint.x} ${basePoint.y} Q ${controlPoint.x.toFixed(2)} ${controlPoint.y.toFixed(2)} ${headPoint.x.toFixed(2)} ${headPoint.y.toFixed(2)}"
            fill="none"
            stroke="${statusColor}"
            stroke-width="2.4"
            stroke-linecap="round"
            stroke-dasharray="4, 3"
            filter="drop-shadow(0 0 3px ${statusColor})" />

      <!-- 5 Vertebrae Beads -->
      ${vertebraeSvg}

      <!-- Base Pedestal Line -->
      <rect x="${(basePoint.x - 13).toFixed(2)}" y="${(basePoint.y + 2).toFixed(2)}" width="26" height="2.5" rx="1.25" fill="rgba(255, 255, 255, 0.35)" />

      <!-- Head Node (Glowing Circle + Specular Ring) -->
      <circle cx="${headPoint.x.toFixed(2)}" cy="${headPoint.y.toFixed(2)}" r="6" fill="${statusColor}" filter="url(#headGlow)" />
      <circle cx="${headPoint.x.toFixed(2)}" cy="${headPoint.y.toFixed(2)}" r="6" fill="none" stroke="rgba(255, 255, 255, 0.7)" stroke-width="1.0" />
    `;
  }

  // ================= 3. UPDATE UI FROM STATE =================
  function updateUI() {
    const effectiveDeg = computeEffectiveDeg();
    const statusColor = getStatusColor(effectiveDeg);
    const alignTitle = getAlignmentTitle(effectiveDeg);
    const isSlouching = state.calibrated && (effectiveDeg > state.thresholdDeg);

    // 1. Render Spine SVG
    renderSpineSvg(effectiveDeg, statusColor);

    // 2. Readout numbers & titles
    if (dom.fmsGaugeAngle) {
      dom.fmsGaugeAngle.textContent = Math.round(effectiveDeg) + "°";
      dom.fmsGaugeAngle.style.color = statusColor;
    }
    if (dom.fmsGaugeTitle) {
      dom.fmsGaugeTitle.textContent = alignTitle;
    }
    if (dom.fmsGreatBadge) {
      dom.fmsGreatBadge.classList.toggle("is-visible", effectiveDeg <= 2.5 && state.calibrated);
    }

    // 3. Stat Pills
    if (dom.fmsStatPitch) {
      const roundedPitch = Math.abs(Math.round(state.nodDeg));
      dom.fmsStatPitch.textContent = roundedPitch === 0 ? "0° Perfect" : `${roundedPitch}° ${state.nodDeg >= 0 ? "Forward" : "Backward"}`;
      dom.fmsStatPitch.style.color = roundedPitch === 0 ? statusColor : "#fff";
    }
    if (dom.fmsStatRoll) {
      const roundedRoll = Math.abs(Math.round(state.sideDeg));
      dom.fmsStatRoll.textContent = roundedRoll === 0 ? "0° Perfect" : `${roundedRoll}° ${state.sideDeg >= 0 ? "Right" : "Left"}`;
      dom.fmsStatRoll.style.color = roundedRoll === 0 ? statusColor : "#fff";
    }

    // 4. Status Card
    if (dom.fmsStatusCard) {
      dom.fmsStatusCard.classList.toggle("slouching", isSlouching);
    }
    if (dom.fmsStatusText) {
      if (!state.calibrated) {
        dom.fmsStatusText.textContent = "AirPods Connected • Ready to Calibrate";
      } else if (isSlouching) {
        dom.fmsStatusText.textContent = "Slouching Alert • Roll Shoulders Back";
      } else {
        dom.fmsStatusText.textContent = "AirPods Connected • Posture Optimal";
      }
    }

    // 5. Menu Bar Extra
    if (dom.mbExtraAngle) {
      dom.mbExtraAngle.textContent = Math.round(effectiveDeg) + "°";
      dom.mbExtraAngle.style.color = statusColor;
    }
    if (dom.mbOrigIcon) {
      // Subtle tilt of the menubar icon
      const tiltAngle = clamp(state.nodDeg * 0.8, -12, 16);
      dom.mbOrigIcon.style.transform = `rotate(${tiltAngle}deg)`;
      dom.mbOrigIcon.style.filter = `drop-shadow(0 0 4px ${statusColor})`;
    }

    // 6. Hardware Stage (Desktop Widget)
    if (dom.hwPitchVal) {
      dom.hwPitchVal.textContent = `${state.nodDeg.toFixed(1)}° ${state.nodDeg >= 0 ? "Forward" : "Backward"}`;
      dom.hwPitchVal.style.color = statusColor;
    }
    if (dom.hwRollVal) {
      dom.hwRollVal.textContent = `${Math.abs(state.sideDeg).toFixed(1)}° ${state.sideDeg >= 0 ? "Right" : "Left"}`;
      dom.hwRollVal.style.color = statusColor;
    }
    if (dom.airpods3dImg) {
      const rx = clamp(-state.nodDeg * 1.5, -24, 20);
      const ry = clamp(state.sideDeg * 1.6, -20, 20);
      dom.airpods3dImg.style.transform = `rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${-ry * 0.4}deg)`;
    }
  }

  // ================= 4. TAB NAVIGATION =================
  function setTab(tabName) {
    state.currentTab = tabName;

    // Subtitle in header
    const subtitles = {
      monitor: "Realign. Redefine.",
      reports: "Weekly Posture Analytics",
      watch: "Apple Watch Live Telemetry",
      settings: "Settings & Customization"
    };
    if (dom.fmsHeaderSub) dom.fmsHeaderSub.textContent = subtitles[tabName] || "Realign. Redefine.";

    // Header Right Button: Gear vs Back
    const isBack = tabName !== "monitor";
    if (dom.fmsSettingsIcon) dom.fmsSettingsIcon.style.display = isBack ? "none" : "block";
    if (dom.fmsBackLabel) dom.fmsBackLabel.hidden = !isBack;

    // Panes
    const panes = [
      { name: "monitor", el: dom.tabPaneMonitor },
      { name: "reports", el: dom.tabPaneReports },
      { name: "watch", el: dom.tabPaneWatch },
      { name: "settings", el: dom.tabPaneSettings }
    ];

    panes.forEach((p) => {
      if (p.el) {
        if (p.name === tabName) {
          p.el.hidden = false;
          p.el.classList.add("is-active");
        } else {
          p.el.hidden = true;
          p.el.classList.remove("is-active");
        }
      }
    });

    // Footer toolbar highlights
    if (dom.fmsFootReports) dom.fmsFootReports.classList.toggle("is-active", tabName === "reports");
    if (dom.fmsFootWatch) dom.fmsFootWatch.classList.toggle("is-active", tabName === "watch");
  }

  // Header settings button click
  if (dom.fmsBtnSettings) {
    dom.fmsBtnSettings.addEventListener("click", () => {
      if (state.currentTab === "monitor") {
        setTab("settings");
      } else {
        setTab("monitor");
      }
    });
  }

  // Footer Toolbar Action Handlers
  if (dom.fmsFootReports) {
    dom.fmsFootReports.addEventListener("click", () => {
      setTab(state.currentTab === "reports" ? "monitor" : "reports");
    });
  }

  if (dom.fmsFootWatch) {
    dom.fmsFootWatch.addEventListener("click", () => {
      setTab(state.currentTab === "watch" ? "monitor" : "watch");
    });
  }

  if (dom.fmsFootPause) {
    dom.fmsFootPause.addEventListener("click", () => {
      state.monitoring = !state.monitoring;
      if (dom.fmsPauseLabel) dom.fmsPauseLabel.textContent = state.monitoring ? "Pause" : "Resume";
      if (dom.fmsPauseIcon) {
        dom.fmsPauseIcon.innerHTML = `<use href="${state.monitoring ? "#i-pause" : "#i-play"}"/>`;
      }
      dom.fmsFootPause.classList.toggle("is-active", state.monitoring);
    });
  }

  if (dom.fmsFootQuit) {
    dom.fmsFootQuit.addEventListener("click", () => {
      if (confirm("Quit FixMySpine?")) {
        togglePopover(false);
      }
    });
  }

  // ================= 5. CALIBRATION & AUDIO CHIME =================
  function playHapticChime() {
    try {
      if (!state.audioCtx) {
        state.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      const ctx = state.audioCtx;
      if (ctx.state === "suspended") ctx.resume();

      const now = ctx.currentTime;
      // Tone 1: 880 Hz (A5)
      const osc1 = ctx.createOscillator();
      const gain1 = ctx.createGain();
      osc1.type = "sine";
      osc1.frequency.setValueAtTime(880, now);
      gain1.gain.setValueAtTime(0.2, now);
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.28);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.3);

      // Tone 2: 1320 Hz (E6)
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.type = "sine";
      osc2.frequency.setValueAtTime(1320, now + 0.08);
      gain2.gain.setValueAtTime(0.25, now + 0.08);
      gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(now + 0.08);
      osc2.stop(now + 0.48);
    } catch (e) {
      // Audio autoplay policy fallback
    }
  }

  function triggerCalibration() {
    state.nodDeg = 0.0;
    state.sideDeg = 0.0;
    state.calibrated = true;
    if (dom.hwPitchSlider) dom.hwPitchSlider.value = 0;
    if (dom.hwRollSlider) dom.hwRollSlider.value = 0;

    if (dom.fmsCalTitle) {
      dom.fmsCalTitle.textContent = "✓ Calibrated Upright";
      setTimeout(() => {
        if (dom.fmsCalTitle) dom.fmsCalTitle.textContent = "Recalibrate Posture";
      }, 1600);
    }

    playHapticChime();
    updateUI();
  }

  if (dom.fmsBtnCalibrate) dom.fmsBtnCalibrate.addEventListener("click", triggerCalibration);
  if (dom.btnDeskCalibrate) dom.btnDeskCalibrate.addEventListener("click", triggerCalibration);
  if (dom.dockCalibrate) dom.dockCalibrate.addEventListener("click", triggerCalibration);
  if ($("#menuItemCalibrate")) $("#menuItemCalibrate").addEventListener("click", triggerCalibration);
  if (dom.btnTestChimeDesk) dom.btnTestChimeDesk.addEventListener("click", playHapticChime);

  // ================= 6. SLIDERS & SENSITIVITY =================
  if (dom.hwPitchSlider) {
    dom.hwPitchSlider.addEventListener("input", (e) => {
      state.nodDeg = parseFloat(e.target.value);
      updateUI();
    });
  }

  if (dom.hwRollSlider) {
    dom.hwRollSlider.addEventListener("input", (e) => {
      state.sideDeg = parseFloat(e.target.value);
      updateUI();
    });
  }

  // Sensitivity Segmented Buttons
  $$("#segSensitivity .fms-seg-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      $$("#segSensitivity .fms-seg-btn").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      state.thresholdDeg = parseFloat(btn.dataset.val);
      updateUI();
    });
  });

  // Alert After Segmented Buttons
  $$("#segAlertAfter .fms-seg-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      $$("#segAlertAfter .fms-seg-btn").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      state.graceSeconds = parseInt(btn.dataset.val, 10);
    });
  });

  // Theme Swatches
  $$("#fmsThemePicker .fms-theme-swatch").forEach((btn) => {
    btn.addEventListener("click", () => {
      $$("#fmsThemePicker .fms-theme-swatch").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      const theme = btn.dataset.theme;
      state.theme = theme;
      document.documentElement.setAttribute("data-theme", theme);
      localStorage.setItem("fms-theme", theme);
      updateUI();
    });
  });

  // ================= 7. POPOVER TOGGLE & DOCK =================
  function togglePopover(show) {
    const isVisible = show !== undefined ? show : dom.popover.hidden;
    dom.popover.hidden = !isVisible;
    state.popoverOpen = isVisible;
    if (dom.mbFixMySpine) dom.mbFixMySpine.classList.toggle("is-active", isVisible);
  }

  if (dom.mbFixMySpine) {
    dom.mbFixMySpine.addEventListener("click", (e) => {
      e.stopPropagation();
      togglePopover();
    });
  }
  if (dom.btnTogglePopoverDesk) {
    dom.btnTogglePopoverDesk.addEventListener("click", () => togglePopover());
  }
  if (dom.dockAppFixMySpine) {
    dom.dockAppFixMySpine.addEventListener("click", () => togglePopover());
  }

  // ================= 8. LIVE CLOCK =================
  function updateClock() {
    if (!dom.mbClock) return;
    const now = new Date();
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const day = days[now.getDay()];
    const date = now.getDate();
    const month = months[now.getMonth()];
    let hours = now.getHours();
    const ampm = hours >= 12 ? "PM" : "AM";
    hours = hours % 12 || 12;
    const mins = String(now.getMinutes()).padStart(2, "0");
    dom.mbClock.textContent = `${day} ${date} ${month} ${hours}:${mins} ${ampm}`;
  }

  // Keyboard shortcut: Escape closes popover
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") togglePopover(false);
  });

  // ================= 9. INITIALIZATION =================
  document.documentElement.setAttribute("data-theme", state.theme);
  updateClock();
  setInterval(updateClock, 1000);
  togglePopover(true);
  updateUI();
  document.body.classList.remove("booting");

})();
