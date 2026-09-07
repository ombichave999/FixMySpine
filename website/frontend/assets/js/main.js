/**
 * FixMySpine — macOS Desktop Simulator & Posture Intelligence Engine
 * 100% Vanilla ES6 · Apple SF Pro Design & CoreMotion Simulation
 */

(function () {
  "use strict";

  // State
  const state = {
    pitch: 2.0,
    targetPitch: 2.0,
    roll: 1.2,
    targetRoll: 1.2,
    yaw: 0.4,
    calibratedOffset: 0.0,
    sensitivity: "balanced", // strict (8), balanced (12), gentle (15)
    gracePeriod: 10,
    soundEnabled: true,
    screenDimEnabled: false,
    theme: localStorage.getItem("fms-theme") || "green",
    popoverOpen: true,
    windowOpen: true,
    windowMinimized: false,
    audioCtx: null
  };

  // DOM Elements
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  const dom = {
    // Menu Bar
    mbClock: $("#mbClock"),
    mbPitchVal: $("#mbPitchVal"),
    mbFixMySpine: $("#mbFixMySpine"),
    mbExtraDot: $("#mbExtraDot"),

    // Popover
    popover: $("#popover"),
    popStateBadge: $("#popStateBadge"),
    popStateText: $("#popStateText"),
    popSpineSvg: $("#popSpineSvg"),
    popPitchReadout: $("#popPitchReadout"),
    popRollReadout: $("#popRollReadout"),
    angleSlider: $("#angleSlider"),
    sliderValueText: $("#sliderValueText"),
    btnCalibrateAction: $("#btnCalibrateAction"),
    calBtnText: $("#calBtnText"),
    btnOpenMainWindow: $("#btnOpenMainWindow"),
    btnTestChime: $("#btnTestChime"),
    chimeStatusText: $("#chimeStatusText"),
    toggleSound: $("#toggleSound"),
    toggleScreenDim: $("#toggleScreenDim"),
    miniChart: $("#miniChart"),
    chartSelectedDay: $("#chartSelectedDay"),
    chartSelectedScore: $("#chartSelectedScore"),
    sensExplainer: $("#sensExplainer"),

    // Window
    winSettings: $("#winSettings"),
    tlClose: $("#tlClose"),
    tlMin: $("#tlMin"),
    tlZoom: $("#tlZoom"),
    winPitchSummary: $("#winPitchSummary"),
    winTelPitch: $("#winTelPitch"),
    winTelRoll: $("#winTelRoll"),
    winTelYaw: $("#winTelYaw"),
    sparkPitch: $("#sparkPitch"),
    sparkRoll: $("#sparkRoll"),
    sparkYaw: $("#sparkYaw"),
    quatW: $("#quatW"),
    quatX: $("#quatX"),
    quatY: $("#quatY"),
    quatZ: $("#quatZ"),
    winSearch: $("#winSearch"),

    // Dock
    dockAppSettings: $("#dockAppSettings"),
    dockSettingsDot: $("#dockSettingsDot"),
    dockCalibrate: $("#dockCalibrate"),
    dockDownload: $("#dockDownload"),

    // Desktop
    deskIconSettings: $("#deskIconSettings"),
    deskIconCalibrate: $("#deskIconCalibrate"),
    deskIconDownload: $("#deskIconDownload"),

    // Modal
    downloadModal: $("#downloadModal"),
    btnCloseModal: $("#btnCloseModal")
  };

  // ================= 1. LIVE SPINE SVG RENDERER =================
  const VERTEBRAE_COUNT = 10;
  
  function initSpineSvg() {
    if (!dom.popSpineSvg) return;
    dom.popSpineSvg.innerHTML = `
      <defs>
        <linearGradient id="spineGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--accent)" />
          <stop offset="100%" stop-color="var(--accent-deep)" />
        </linearGradient>
      </defs>
      <path id="spinePath" fill="none" stroke="rgba(255,255,255,0.12)" stroke-width="3" stroke-dasharray="3 3" />
      <g id="vertebraeGroup"></g>
      <!-- Head node with AirPods icon -->
      <g id="headNode">
        <circle cx="80" cy="30" r="16" fill="rgba(255,255,255,0.06)" stroke="var(--accent)" stroke-width="2" />
        <circle cx="80" cy="30" r="5" fill="var(--accent)" />
        <!-- Earbud stems -->
        <line x1="72" y1="30" x2="68" y2="44" stroke="var(--text-hi)" stroke-width="2.5" stroke-linecap="round" />
        <line x1="88" y1="30" x2="92" y2="44" stroke="var(--text-hi)" stroke-width="2.5" stroke-linecap="round" />
      </g>
    `;

    const vGroup = $("#vertebraeGroup");
    for (let i = 0; i < VERTEBRAE_COUNT; i++) {
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("class", "vert-node");
      rect.setAttribute("rx", "2");
      rect.setAttribute("ry", "2");
      rect.setAttribute("fill", "var(--accent)");
      vGroup.appendChild(rect);
    }
  }

  function updateSpine(pitchAngle) {
    const vGroup = $("#vertebraeGroup");
    const headNode = $("#headNode");
    const spinePath = $("#spinePath");
    if (!vGroup || !headNode) return;

    const nodes = vGroup.querySelectorAll(".vert-node");
    const baseY = 200;
    const baseCenterX = 80;
    
    // Curvature factor proportional to pitch (0° = vertical, 20° = forward curve)
    const curveAmount = (pitchAngle / 20) * 35;
    
    let pathD = `M ${baseCenterX} ${baseY}`;
    
    nodes.forEach((node, idx) => {
      const t = (VERTEBRAE_COUNT - idx) / VERTEBRAE_COUNT; // 1 at bottom, 0 at top
      const y = baseY - (idx * 15);
      const xOffset = Math.sin((1 - t) * Math.PI * 0.5) * curveAmount;
      const x = baseCenterX + xOffset;
      
      const width = 16 - (idx * 0.6);
      const height = 6;
      
      node.setAttribute("x", (x - width / 2).toFixed(1));
      node.setAttribute("y", (y - height / 2).toFixed(1));
      node.setAttribute("width", width.toFixed(1));
      node.setAttribute("height", height.toString());
      node.setAttribute("opacity", (0.5 + (0.5 * (1 - t))).toFixed(2));
      
      pathD += ` L ${x.toFixed(1)} ${y.toFixed(1)}`;
    });

    if (spinePath) spinePath.setAttribute("d", pathD);

    // Position head node at top of spine curve
    const topX = baseCenterX + curveAmount;
    const topY = baseY - (VERTEBRAE_COUNT * 15) - 10;
    headNode.setAttribute("transform", `translate(${topX - 80}, ${topY - 30}) rotate(${(pitchAngle * 0.8).toFixed(1)}, 80, 30)`);
  }

  // ================= 2. POSTURE STATE & METRICS LOOP =================
  function evaluatePostureState(angle) {
    let status = "good";
    let text = "Aligned";
    let threshold = 12;

    if (state.sensitivity === "strict") threshold = 8;
    if (state.sensitivity === "gentle") threshold = 15;

    if (angle > threshold) {
      status = "slouch";
      text = `Slouching (>${threshold}°)`;
    } else if (angle > threshold * 0.5) {
      status = "drift";
      text = `Drift (${angle.toFixed(1)}°)`;
    }

    // Update Popover Badge
    if (dom.popStateBadge) {
      dom.popStateBadge.setAttribute("data-state", status);
      dom.popStateText.textContent = text;
    }

    // Update Menubar Dot
    if (dom.mbExtraDot) {
      if (status === "good") dom.mbExtraDot.style.background = "var(--accent)";
      if (status === "drift") dom.mbExtraDot.style.background = "var(--orange)";
      if (status === "slouch") dom.mbExtraDot.style.background = "var(--red)";
    }
  }

  function updateTelemetryReadouts() {
    const pitchStr = `${state.pitch.toFixed(1)}°`;
    const rollStr = `${state.roll.toFixed(1)}°`;
    const yawStr = `${state.yaw.toFixed(1)}°`;

    if (dom.popPitchReadout) dom.popPitchReadout.textContent = pitchStr;
    if (dom.popRollReadout) dom.popRollReadout.textContent = rollStr;
    if (dom.mbPitchVal) dom.mbPitchVal.textContent = pitchStr;

    // Window Telemetry Pane
    if (dom.winPitchSummary) dom.winPitchSummary.textContent = pitchStr;
    if (dom.winTelPitch) dom.winTelPitch.textContent = pitchStr;
    if (dom.winTelRoll) dom.winTelRoll.textContent = rollStr;
    if (dom.winTelYaw) dom.winTelYaw.textContent = yawStr;

    if (dom.sparkPitch) dom.sparkPitch.style.width = `${Math.min(100, Math.max(5, (state.pitch / 25) * 100))}%`;
    if (dom.sparkRoll) dom.sparkRoll.style.width = `${Math.min(100, Math.max(5, (state.roll / 15) * 100))}%`;
    if (dom.sparkYaw) dom.sparkYaw.style.width = `${Math.min(100, Math.max(5, (state.yaw / 10) * 100))}%`;

    // Simulated Quaternions
    const pRad = (state.pitch * Math.PI) / 180;
    const rRad = (state.roll * Math.PI) / 180;
    if (dom.quatW) dom.quatW.textContent = Math.cos(pRad / 2).toFixed(3);
    if (dom.quatX) dom.quatX.textContent = Math.sin(pRad / 2).toFixed(3);
    if (dom.quatY) dom.quatY.textContent = Math.sin(rRad / 2).toFixed(3);
  }

  // Animation Frame Physics Loop
  function tick() {
    // Spring interpolation towards target pitch
    const dPitch = state.targetPitch - state.pitch;
    state.pitch += dPitch * 0.16;

    // Gentle organic micro-drift
    const time = Date.now() * 0.002;
    state.roll = state.targetRoll + Math.sin(time) * 0.4;
    state.yaw = Math.cos(time * 0.7) * 0.3;

    updateSpine(state.pitch);
    evaluatePostureState(state.pitch);
    updateTelemetryReadouts();

    requestAnimationFrame(tick);
  }

  // ================= 3. AUDIO SYNTHESIZER (Web Audio API) =================
  function playHapticChime() {
    try {
      if (!state.audioCtx) {
        state.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      if (state.audioCtx.state === "suspended") {
        state.audioCtx.resume();
      }

      const ctx = state.audioCtx;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "sine";
      osc.frequency.setValueAtTime(880, ctx.currentTime); // A5
      osc.frequency.exponentialRampToValueAtTime(1318.51, ctx.currentTime + 0.12); // E6

      gain.gain.setValueAtTime(0.08, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.45);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(ctx.currentTime + 0.48);

      if (dom.chimeStatusText) {
        dom.chimeStatusText.textContent = "Chime Played 🔔";
        setTimeout(() => { dom.chimeStatusText.textContent = "Web Audio ready"; }, 1500);
      }
    } catch (e) {
      console.warn("Web Audio not allowed without user gesture:", e);
    }
  }

  // ================= 4. SLIDER & CALIBRATION EVENTS =================
  if (dom.angleSlider) {
    dom.angleSlider.addEventListener("input", (e) => {
      const val = parseFloat(e.target.value);
      state.targetPitch = val;
      if (dom.sliderValueText) dom.sliderValueText.textContent = `${val.toFixed(1)}°`;
    });
  }

  function triggerCalibration() {
    state.targetPitch = 0.0;
    if (dom.angleSlider) dom.angleSlider.value = "0";
    if (dom.sliderValueText) dom.sliderValueText.textContent = "0.0°";

    if (dom.calBtnText) {
      const old = dom.calBtnText.textContent;
      dom.calBtnText.textContent = "Calibrated! ✓";
      setTimeout(() => { dom.calBtnText.textContent = old; }, 1600);
    }

    playHapticChime();
  }

  if (dom.btnCalibrateAction) dom.btnCalibrateAction.addEventListener("click", triggerCalibration);
  if (dom.dockCalibrate) dom.dockCalibrate.addEventListener("click", triggerCalibration);
  if (dom.deskIconCalibrate) dom.deskIconCalibrate.addEventListener("click", triggerCalibration);
  if ($("#menuItemCalibrate")) $("#menuItemCalibrate").addEventListener("click", triggerCalibration);

  // ================= 5. POPOVER CONTROLLER =================
  function togglePopover(show) {
    const isVisible = show !== undefined ? show : dom.popover.hidden;
    dom.popover.hidden = !isVisible;
    state.popoverOpen = isVisible;
    if (dom.mbFixMySpine) dom.mbFixMySpine.setAttribute("aria-expanded", isVisible ? "true" : "false");
    if (dom.mbFixMySpine) dom.mbFixMySpine.classList.toggle("is-active", isVisible);
  }

  if (dom.mbFixMySpine) {
    dom.mbFixMySpine.addEventListener("click", (e) => {
      e.stopPropagation();
      togglePopover();
    });
  }

  // Popover Tab Navigation
  const popNavBtns = $$("#popNav .sn-btn");
  popNavBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      popNavBtns.forEach((b) => {
        b.classList.remove("is-active");
        b.setAttribute("aria-selected", "false");
      });
      btn.classList.add("is-active");
      btn.setAttribute("aria-selected", "true");

      const targetTab = btn.getAttribute("data-tab");
      $$(".pop-tab").forEach((tab) => {
        if (tab.getAttribute("data-tab-content") === targetTab) {
          tab.classList.add("is-active");
          tab.hidden = false;
        } else {
          tab.classList.remove("is-active");
          tab.hidden = true;
        }
      });
    });
  });

  // Sensitivity segmented selector
  $$("#segSensitivity .sc-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      $$("#segSensitivity .sc-btn").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      state.sensitivity = btn.getAttribute("data-val");

      if (dom.sensExplainer) {
        if (state.sensitivity === "strict") dom.sensExplainer.textContent = "Strict (8°) — Ideal for focused posture correction.";
        if (state.sensitivity === "balanced") dom.sensExplainer.textContent = "Balanced (12°) — Default ergonomic setting for daily work.";
        if (state.sensitivity === "gentle") dom.sensExplainer.textContent = "Gentle (15°) — Relaxed setting with fewer alerts.";
      }
    });
  });

  // Grace period selector
  $$("#segGrace .sc-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      $$("#segGrace .sc-btn").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      state.gracePeriod = parseInt(btn.getAttribute("data-val"), 10);
    });
  });

  // Preview chime
  if (dom.btnTestChime) dom.btnTestChime.addEventListener("click", playHapticChime);

  // Weekly Mini-Chart Generator
  const weekData = [
    { day: "M", full: "Monday", score: 88, slouch: "22m" },
    { day: "T", full: "Tuesday", score: 92, slouch: "15m" },
    { day: "W", full: "Wednesday", score: 94, slouch: "12m" },
    { day: "T", full: "Thursday", score: 89, slouch: "19m" },
    { day: "F", full: "Friday", score: 96, slouch: "8m" },
    { day: "S", full: "Saturday", score: 90, slouch: "16m" },
    { day: "S", full: "Sunday", score: 95, slouch: "10m" }
  ];

  if (dom.miniChart) {
    dom.miniChart.innerHTML = "";
    weekData.forEach((item, idx) => {
      const col = document.createElement("div");
      col.className = `chart-col ${idx === 2 ? "is-active" : ""}`;
      col.innerHTML = `
        <div class="bar" style="height: ${(item.score / 100) * 46}px"></div>
        <span class="day-lbl">${item.day}</span>
      `;
      col.addEventListener("click", () => {
        $$(".chart-col").forEach((c) => c.classList.remove("is-active"));
        col.classList.add("is-active");
        if (dom.chartSelectedDay) dom.chartSelectedDay.textContent = item.full;
        if (dom.chartSelectedScore) dom.chartSelectedScore.textContent = `${item.score}% Aligned (${item.slouch} slouch)`;
      });
      dom.miniChart.appendChild(col);
    });
  }

  // Themes
  $$(".t-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      $$(".t-chip").forEach((c) => c.classList.remove("is-active"));
      chip.classList.add("is-active");
      const themeName = chip.getAttribute("data-theme");
      document.documentElement.setAttribute("data-theme", themeName);
      localStorage.setItem("fms-theme", themeName);
      state.theme = themeName;
      if ($("#themeSelectedName")) $("#themeSelectedName").textContent = chip.getAttribute("title");
    });
  });

  // Apply saved theme
  if (state.theme && state.theme !== "green") {
    document.documentElement.setAttribute("data-theme", state.theme);
    const activeChip = $(`.t-chip[data-theme="${state.theme}"]`);
    if (activeChip) {
      $$(".t-chip").forEach((c) => c.classList.remove("is-active"));
      activeChip.classList.add("is-active");
    }
  }

  // ================= 6. DRAGGABLE SETTINGS WINDOW =================
  function toggleSettingsWindow(show) {
    const isVisible = show !== undefined ? show : dom.winSettings.hidden;
    dom.winSettings.hidden = !isVisible;
    state.windowOpen = isVisible;
    if (dom.dockSettingsDot) dom.dockSettingsDot.hidden = !isVisible;
    if (isVisible) bringWindowToFront();
  }

  function bringWindowToFront() {
    if (dom.winSettings) dom.winSettings.style.zIndex = "120";
  }

  if (dom.btnOpenMainWindow) dom.btnOpenMainWindow.addEventListener("click", () => toggleSettingsWindow(true));
  if (dom.deskIconSettings) dom.deskIconSettings.addEventListener("click", () => toggleSettingsWindow(true));
  if (dom.dockAppSettings) dom.dockAppSettings.addEventListener("click", () => toggleSettingsWindow(true));
  if ($("#menuItemSettings")) $("#menuItemSettings").addEventListener("click", () => toggleSettingsWindow(true));

  // Traffic lights
  if (dom.tlClose) dom.tlClose.addEventListener("click", () => toggleSettingsWindow(false));
  if (dom.tlMin) {
    dom.tlMin.addEventListener("click", () => {
      dom.winSettings.style.transform = "scale(0.2) translate(0, 500px)";
      dom.winSettings.style.opacity = "0";
      dom.winSettings.style.transition = "all 0.3s ease";
      setTimeout(() => {
        toggleSettingsWindow(false);
        dom.winSettings.style.transform = "";
        dom.winSettings.style.opacity = "";
        dom.winSettings.style.transition = "";
      }, 300);
    });
  }
  if (dom.tlZoom) {
    dom.tlZoom.addEventListener("click", () => {
      const isZoomed = dom.winSettings.getAttribute("data-zoomed") === "true";
      if (!isZoomed) {
        dom.winSettings.setAttribute("data-zoomed", "true");
        dom.winSettings.style.top = "44px";
        dom.winSettings.style.left = "16px";
        dom.winSettings.style.width = "calc(100vw - 32px)";
        dom.winSettings.style.height = "calc(100vh - 120px)";
      } else {
        dom.winSettings.removeAttribute("data-zoomed");
        dom.winSettings.style.top = "";
        dom.winSettings.style.left = "";
        dom.winSettings.style.width = "";
        dom.winSettings.style.height = "";
      }
    });
  }

  // Dragging Engine
  const titlebar = $("[data-drag]");
  if (titlebar && dom.winSettings) {
    let isDragging = false;
    let startX = 0;
    let startY = 0;
    let winX = 180;
    let winY = 85;

    titlebar.addEventListener("pointerdown", (e) => {
      if (e.target.closest(".traffic-lights")) return;
      isDragging = true;
      startX = e.clientX;
      startY = e.clientY;
      const rect = dom.winSettings.getBoundingClientRect();
      winX = rect.left;
      winY = rect.top;
      titlebar.setPointerCapture(e.pointerId);
      bringWindowToFront();
    });

    titlebar.addEventListener("pointermove", (e) => {
      if (!isDragging) return;
      const dx = e.clientX - startX;
      const dy = e.clientY - startY;
      const newX = Math.max(10, Math.min(window.innerWidth - 300, winX + dx));
      const newY = Math.max(38, Math.min(window.innerHeight - 100, winY + dy));
      dom.winSettings.style.left = `${newX}px`;
      dom.winSettings.style.top = `${newY}px`;
    });

    titlebar.addEventListener("pointerup", (e) => {
      isDragging = false;
      try { titlebar.releasePointerCapture(e.pointerId); } catch (_) {}
    });
  }

  // Resizing Engine
  const resizeHandle = $("[data-resize]");
  if (resizeHandle && dom.winSettings) {
    let isResizing = false;
    let rStartX = 0;
    let rStartY = 0;
    let rStartW = 820;
    let rStartH = 540;

    resizeHandle.addEventListener("pointerdown", (e) => {
      isResizing = true;
      rStartX = e.clientX;
      rStartY = e.clientY;
      const rect = dom.winSettings.getBoundingClientRect();
      rStartW = rect.width;
      rStartH = rect.height;
      resizeHandle.setPointerCapture(e.pointerId);
    });

    resizeHandle.addEventListener("pointermove", (e) => {
      if (!isResizing) return;
      const newW = Math.max(480, rStartW + (e.clientX - rStartX));
      const newH = Math.max(340, rStartH + (e.clientY - rStartY));
      dom.winSettings.style.width = `${newW}px`;
      dom.winSettings.style.height = `${newH}px`;
    });

    resizeHandle.addEventListener("pointerup", (e) => {
      isResizing = false;
      try { resizeHandle.releasePointerCapture(e.pointerId); } catch (_) {}
    });
  }

  // Window Sidebar Navigation
  const sbItems = $$(".sb-item");
  sbItems.forEach((btn) => {
    btn.addEventListener("click", () => {
      sbItems.forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");

      const paneKey = btn.getAttribute("data-win-pane");
      $$(".win-pane").forEach((pane) => {
        if (pane.getAttribute("data-pane") === paneKey) {
          pane.classList.add("is-active");
          pane.hidden = false;
        } else {
          pane.classList.remove("is-active");
          pane.hidden = true;
        }
      });
    });
  });

  // Sidebar Search filter
  if (dom.winSearch) {
    dom.winSearch.addEventListener("input", (e) => {
      const q = e.target.value.toLowerCase().trim();
      sbItems.forEach((btn) => {
        const txt = btn.textContent.toLowerCase();
        btn.hidden = q.length > 0 && !txt.includes(q);
      });
    });
  }

  // ================= 7. DOWNLOAD MODAL =================
  function toggleDownloadModal(show) {
    if (dom.downloadModal) dom.downloadModal.hidden = !show;
  }
  if (dom.deskIconDownload) dom.deskIconDownload.addEventListener("click", () => toggleDownloadModal(true));
  if (dom.dockDownload) dom.dockDownload.addEventListener("click", () => toggleDownloadModal(true));
  if (dom.btnCloseModal) dom.btnCloseModal.addEventListener("click", () => toggleDownloadModal(false));

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
    hours = hours % 12;
    hours = hours ? hours : 12;
    const mins = String(now.getMinutes()).padStart(2, "0");

    dom.mbClock.textContent = `${day} ${date} ${month} ${hours}:${mins} ${ampm}`;
  }

  // ================= 9. GLOBAL KEYBOARD & CLICK OUTSIDE =================
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      togglePopover(false);
      toggleDownloadModal(false);
    }
  });

  // ================= 10. INITIALIZATION =================
  initSpineSvg();
  updateClock();
  setInterval(updateClock, 1000);

  // Start with open popover & window on desktop, popover on mobile
  togglePopover(true);
  toggleSettingsWindow(window.innerWidth > 768);

  // Remove booting class
  document.body.classList.remove("booting");

  // Start physics loop
  requestAnimationFrame(tick);

})();
