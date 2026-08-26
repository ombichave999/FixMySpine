/* ============================================================
   FixMySpine — Interaction & Motion Engine
   Modules: header, reveals (GSAP + IO fallback), posture
   simulation (spine SVG), drift morph, signal chain, bento
   micro-interactions, theme preview, card glow.
   All motion is transform/opacity based. Reduced-motion safe.
   ============================================================ */
(() => {
  "use strict";
  let activeUtterance = null;

  const root = document.documentElement;
  const reducedMQ = window.matchMedia("(prefers-reduced-motion: reduce)");
  let reduced = reducedMQ.matches;
  reducedMQ.addEventListener("change", e => { reduced = e.matches; });
  const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const $ = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => [...ctx.querySelectorAll(sel)];
  const SVG_NS = "http://www.w3.org/2000/svg";
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const easeInOut = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);

  /* ----------------------------------------------------------
     1. Header: scrolled state + mobile menu
  ---------------------------------------------------------- */
  const header = $("#site-header");
  const menuToggle = $("#menu-toggle");
  const mobileMenu = $("#mobile-menu");

  const onScrollHeader = () => header.classList.toggle("scrolled", window.scrollY > 10);
  onScrollHeader();
  window.addEventListener("scroll", onScrollHeader, { passive: true });

  const closeMenu = () => {
    mobileMenu.classList.remove("open");
    mobileMenu.setAttribute("aria-hidden", "true");
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "Open menu");
  };
  menuToggle.addEventListener("click", () => {
    const open = mobileMenu.classList.toggle("open");
    mobileMenu.setAttribute("aria-hidden", String(!open));
    menuToggle.setAttribute("aria-expanded", String(open));
    menuToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  });
  mobileMenu.addEventListener("click", (e) => {
    if (e.target.closest("a")) closeMenu();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && mobileMenu.classList.contains("open")) {
      closeMenu();
      menuToggle.focus();
    }
  });
  window.addEventListener("resize", () => {
    if (window.innerWidth >= 900 && mobileMenu.classList.contains("open")) {
      closeMenu();
    }
  }, { passive: true });

  /* ----------------------------------------------------------
     2. Spine SVG builder — shared by hero & demo panels
  ---------------------------------------------------------- */
  function buildSpine(container) {
    const W = 320, H = 360;
    const PIVOT = { x: 160, y: 52 };
    const TOP = 84, BOTTOM = 314, N = 12;
    const svg = document.createElementNS(SVG_NS, "svg");
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
    svg.setAttribute("fill", "none");
    svg.classList.add("spine-svg");
    svg.setAttribute("aria-hidden", "true");

    svg.innerHTML = `
      <defs>
        <linearGradient id="bone-${container.id}" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#475569"/>
          <stop offset="1" stop-color="#1e293b"/>
        </linearGradient>
        <radialGradient id="head-${container.id}" cx="0.38" cy="0.32" r="1">
          <stop offset="0" stop-color="#475569"/>
          <stop offset="1" stop-color="#1e293b"/>
        </radialGradient>
      </defs>
      <line x1="160" y1="16" x2="160" y2="332" stroke="rgba(0,0,0,0.08)" stroke-width="1" stroke-dasharray="2 6"/>
      <line x1="52" y1="176" x2="268" y2="176" stroke="rgba(0,0,0,0.04)" stroke-width="1" stroke-dasharray="2 6"/>
      <path d="M132 322h56" stroke="rgba(0,0,0,0.14)" stroke-width="3" stroke-linecap="round"/>
      <path d="M140 328h40" stroke="rgba(0,0,0,0.07)" stroke-width="3" stroke-linecap="round"/>
      <g class="spine-group"></g>
      <g class="head-group">
        <g class="head-rot">
          <circle class="head-skull" cx="0" cy="0" r="20" fill="url(#head-${container.id})" stroke-width="2"/>
          <circle class="head-nose" cx="21.5" cy="5" r="2"/>
          <circle class="ear-ring" cx="-2" cy="2" r="7" stroke-width="1.2" opacity="0.5"/>
          <circle class="airpod-core" cx="-2" cy="2" r="3.4"/>
          <rect class="airpod-stem" x="-3.7" y="5" width="3.4" height="10" rx="1.7"/>
          <path class="neck-l" d="M-9 17 L-10 30 M9 17 L10 30" stroke-width="2.4" stroke-linecap="round"/>
        </g>
      </g>
      <g class="arc-group" opacity="0.9">
        <line class="arc-ref" x1="160" y1="52" x2="160" y2="10" stroke="rgba(0,0,0,0.2)" stroke-width="1" stroke-dasharray="3 4"/>
        <path class="arc-path" fill="none" stroke-width="1.6"/>
        <text class="arc-label" x="0" y="0" text-anchor="start" font-size="12" font-family="ui-monospace,monospace" font-weight="600">0°</text>
      </g>
    `;

    const group = svg.querySelector(".spine-group");
    const headGroup = svg.querySelector(".head-group");
    const headRot = svg.querySelector(".head-rot");
    const vertebrae = [];

    for (let i = 0; i < N; i++) {
      const t = i / (N - 1);
      const g = document.createElementNS(SVG_NS, "g");
      g.setAttribute("class", "vertebra");
      const w = lerp(16, 30, t), h = lerp(6, 10, t);
      const body = document.createElementNS(SVG_NS, "rect");
      body.setAttribute("x", -w / 2);
      body.setAttribute("y", -h / 2);
      body.setAttribute("width", w);
      body.setAttribute("height", h);
      body.setAttribute("rx", h / 2);
      body.setAttribute("fill", `url(#bone-${container.id})`);
      body.setAttribute("stroke-width", "1.7");
      g.appendChild(body);
      group.appendChild(g);
      vertebrae.push({ g, t, y: TOP + t * (BOTTOM - TOP) });
    }

    container.appendChild(svg);

    const arcPath = svg.querySelector(".arc-path");
    const arcLabel = svg.querySelector(".arc-label");

    function render(deg, side) {
      const rad = (deg * Math.PI) / 180;
      const bend = clamp(deg, -6, 26) * 1.6;

      // Head rotation around pivot
      headGroup.setAttribute("transform", `translate(${PIVOT.x + bend * 0.05} ${PIVOT.y})`);
      headRot.setAttribute("transform", `rotate(${clamp(deg, -8, 30) * 0.9})`);

      // Vertebrae along a bending curve
      for (const v of vertebrae) {
        const x = 160 + Math.pow(v.t, 1.55) * bend - Math.sin(v.t * Math.PI) * 2.4 + side * v.t * 0.55;
        const rot = clamp(deg, -8, 30) * 0.62 * v.t;
        v.g.setAttribute("transform", `translate(${x.toFixed(2)} ${v.y.toFixed(2)}) rotate(${rot.toFixed(2)})`);
      }

      // Angle arc from vertical reference, above the head
      const r = 46;
      const ex = PIVOT.x + Math.sin(rad) * r;
      const ey = PIVOT.y - Math.cos(rad) * r;
      const sweep = deg >= 0 ? 1 : 0;
      arcPath.setAttribute("d", `M ${PIVOT.x} ${PIVOT.y - r} A ${r} ${r} 0 0 ${sweep} ${ex.toFixed(2)} ${ey.toFixed(2)}`);
      arcPath.setAttribute("stroke", "currentColor");
      arcLabel.setAttribute("x", (PIVOT.x + Math.sin(rad) * (r + 10) + 6).toFixed(1));
      arcLabel.setAttribute("y", (PIVOT.y - Math.cos(rad) * (r + 10) + 4).toFixed(1));
      arcLabel.textContent = `${deg.toFixed(1)}°`;
    }

    render(0, 0);
    return { render, svg };
  }

  /* ----------------------------------------------------------
     3. Posture simulation engine (one session drives all views)
  ---------------------------------------------------------- */
  const heroSpineEl = $("#hero-spine");
  const demoSpineEl = $("#demo-spine");
  const heroSpine = heroSpineEl ? buildSpine(heroSpineEl) : null;
  const demoSpine = demoSpineEl ? buildSpine(demoSpineEl) : null;

  const out = {
    instrument: $("#hero-instrument"),
    demoPanel: $("#demo-window-panel"),
    demoSpinePanel: $("#demo-spine-panel"),
    pill: $("#hero-state-pill"),
    demoPill: $("#demo-state-pill"),
    tilt: $("#stat-tilt"),
    side: $("#stat-side"),
    state: $("#stat-state"),
    chipPitch: $("#chip-pitch"),
    chipRoll: $("#chip-roll"),
    awAngle: $("#aw-angle"),
    awStatus: $("#aw-status"),
    awPitch: $("#aw-pitch"),
    awRoll: $("#aw-roll"),
    slider: $("#angle-slider"),
    sliderReadout: $("#slider-readout"),
  };

  const STATE_LABEL = { good: "Aligned", drift: "Drifting", alert: "Slouching" };
  const AW_STATUS = {
    good: "AirPods Pro — aligned",
    drift: "AirPods Pro — drifting",
    alert: "Slouch detected — realign",
  };

  // Auto-demo timeline: [time, angle] pairs, loops
  const TL = [[0, 1.2], [2.6, 2.2], [6.2, 9.4], [9.2, 9.9], [11.4, 14.7], [13.2, 15.1], [14.8, 1.4], [16.5, 1.2]];
  const TL_DUR = 16.5;

  const sim = {
    angle: 0, side: 0, shown: { tilt: null, side: null, state: "" },
    mode: "auto", userTarget: 0, lastUserAt: -1e9, visible: true,
  };

  function timelineAngle(t) {
    const tt = t % TL_DUR;
    for (let i = 0; i < TL.length - 1; i++) {
      const [t0, a0] = TL[i], [t1, a1] = TL[i + 1];
      if (tt >= t0 && tt <= t1) {
        const k = easeInOut((tt - t0) / (t1 - t0));
        return lerp(a0, a1, k);
      }
    }
    return TL[0][1];
  }

  let lastFrame = performance.now();
  function frame(now) {
    const dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;

    if (sim.visible && !document.hidden) {
      const t = now / 1000;
      if (sim.mode === "auto" && !reduced) {
        sim.angle = timelineAngle(t) + Math.sin(t * 2.1) * 0.18 + Math.sin(t * 0.63) * 0.12;
      } else {
        sim.angle = lerp(sim.angle, sim.userTarget, reduced ? 1 : 1 - Math.pow(0.0018, dt));
        if (!reduced && now - sim.lastUserAt > 6000) sim.mode = "auto";
      }
      sim.side = reduced ? 0 : Math.sin(t * 0.45) * 2.1 + Math.sin(t * 1.27) * 0.35;

      const a = sim.angle, s = sim.side;
      if (heroSpine) heroSpine.render(a, s);
      if (demoSpine) demoSpine.render(a, s);

      // State (README legend: ≤5 aligned · ≤12 drifting · >12 slouch)
      const state = a > 12 ? "alert" : a > 5 ? "drift" : "good";
      if (state !== sim.shown.state) {
        sim.shown.state = state;
        const label = STATE_LABEL[state];
        if (out.instrument) out.instrument.dataset.state = state;
        if (out.demoPanel) out.demoPanel.dataset.state = state;
        if (out.demoSpinePanel) out.demoSpinePanel.dataset.state = state;
        if (out.pill) out.pill.textContent = label;
        if (out.demoPill) out.demoPill.textContent = label;
        if (out.state) out.state.textContent = label;
        if (out.awStatus) out.awStatus.textContent = AW_STATUS[state];
      }

      // Text readouts, throttled to value changes
      const tiltTxt = a.toFixed(1), sideTxt = s.toFixed(1);
      if (tiltTxt !== sim.shown.tilt) {
        sim.shown.tilt = tiltTxt;
        if (out.tilt) out.tilt.textContent = `${tiltTxt}°`;
        if (out.awAngle) out.awAngle.textContent = `${tiltTxt}°`;
        if (out.awPitch) out.awPitch.textContent = `${tiltTxt}° fwd`;
        if (out.chipPitch) out.chipPitch.textContent = `${tiltTxt}° fwd`;
        if (out.sliderReadout) {
          out.sliderReadout.textContent = `${tiltTxt}°`;
          if (out.slider) out.slider.value = sim.angle;
        }
      }
      if (sideTxt !== sim.shown.side) {
        sim.shown.side = sideTxt;
        if (out.side) out.side.textContent = `${sideTxt}°`;
        if (out.awRoll) out.awRoll.textContent = `${sideTxt}° ${s >= 0 ? "R" : "L"}`;
        if (out.chipRoll) out.chipRoll.textContent = `${sideTxt}°`;
      }
      requestAnimationFrame(frame);
    }
  }
  requestAnimationFrame(frame);

  // Pause work when both watch regions are off-screen
  const visTargets = [$(".hero-stage"), $("#demo")].filter(Boolean);
  if (visTargets.length && "IntersectionObserver" in window) {
    const visMap = new Map();
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => visMap.set(en.target, en.isIntersecting));
      const wasVisible = sim.visible;
      sim.visible = [...visMap.values()].some(Boolean);
      if (sim.visible && !wasVisible && !document.hidden) {
        lastFrame = performance.now();
        requestAnimationFrame(frame);
      }
    }, { rootMargin: "80px" });
    visTargets.forEach((el) => io.observe(el));
  }

  // Slider interaction
  if (out.slider) {
    const goodEnd = ((5 - -5) / 30) * 100;
    out.slider.style.setProperty("--good-end", `${goodEnd}%`);
    out.slider.addEventListener("input", () => {
      sim.mode = "user";
      sim.lastUserAt = performance.now();
      sim.userTarget = parseFloat(out.slider.value);
      if (out.sliderReadout) out.sliderReadout.textContent = `${sim.userTarget.toFixed(1)}°`;
    });
    out.slider.addEventListener("pointerdown", () => {
      sim.mode = "user";
      sim.lastUserAt = performance.now();
    });
  }

  // Recalibrate button in app window
  const calBtn = $("#aw-calibrate");
  if (calBtn) {
    calBtn.addEventListener("click", () => {
      sim.mode = "user";
      sim.userTarget = 0;
      sim.lastUserAt = performance.now() + 4000;
      if (out.slider) out.slider.value = "0";
      if (out.sliderReadout) out.sliderReadout.textContent = "0.0°";
      const t = calBtn.querySelector(".t");
      const original = t.textContent;
      t.textContent = "Baseline captured ✓";
      calBtn.disabled = true;
      setTimeout(() => {
        t.textContent = original;
        calBtn.disabled = false;
      }, 1600);
    });
  }

  // Segmented controls (app window preview + features)
  function wireSegmented(container, onPick) {
    if (!container) return;
    $$("button", container).forEach((b) => {
      if (!b.hasAttribute("aria-pressed")) {
        b.setAttribute("aria-pressed", String(b.classList.contains("active")));
      }
    });
    container.addEventListener("click", (e) => {
      const btn = e.target.closest("button");
      if (!btn || !container.contains(btn)) return;
      $$("button", container).forEach((b) => {
        const active = b === btn;
        b.classList.toggle("active", active);
        b.setAttribute("aria-pressed", String(active));
      });
      if (onPick) onPick(btn);
    });
  }
  wireSegmented($(".aw-seg[aria-label='Sensitivity preset preview']"));
  wireSegmented($(".aw-seg[aria-label='Alert timing preview']"));
  wireSegmented($("#feat-sens"), (btn) => {
    const ro = $("#feat-sens-readout");
    if (ro) ro.textContent = `${btn.dataset.name} — ${btn.textContent === "Relaxed" ? "18°" : btn.textContent === "Balanced" ? "12°" : btn.textContent === "Strict" ? "8°" : "5°"} threshold`;
  });
  wireSegmented($("#feat-grace"), (btn) => {
    const ro = $("#feat-grace-readout");
    if (ro) ro.textContent = `Alert after ${btn.dataset.name.toLowerCase()}`;
  });

  /* ----------------------------------------------------------
     4. Drift morph (problem section)
  ---------------------------------------------------------- */
  const driftHost = $("#drift-svg");
  if (driftHost) {
    driftHost.innerHTML = `
      <svg viewBox="0 0 400 300" fill="none" aria-hidden="true">
        <line x1="200" y1="24" x2="200" y2="272" stroke="rgba(0,0,0,0.08)" stroke-width="1" stroke-dasharray="2 6"/>
        <path class="drift-curve" stroke-width="3.2" stroke-linecap="round" fill="none"/>
        <g class="drift-head">
          <circle r="15" stroke-width="2.4"/>
          <circle class="nose-dot" cx="16.5" cy="4.5" r="2"/>
        </g>
        <circle class="drift-anchor" cx="200" cy="252" r="3.4"/>
        <text class="drift-deg" x="0" y="0" font-size="12" font-family="ui-monospace,monospace" font-weight="600"></text>
      </svg>`;
    const curve = $(".drift-curve", driftHost);
    const head = $(".drift-head", driftHost);
    const degText = $(".drift-deg", driftHost);
    const anchor = $(".drift-anchor", driftHost);
    const beats = $$(".beat", driftHost.parentElement.parentElement);

    // Upright vs slouched control points (top → bottom)
    const UP = [[200, 52], [200, 100], [199, 148], [200, 196], [200, 244]];
    const SL = [[236, 58], [227, 108], [213, 154], [203, 198], [200, 244]];

    function catmull(points) {
      let d = `M ${points[0][0]} ${points[0][1]}`;
      for (let i = 0; i < points.length - 1; i++) {
        const p0 = points[Math.max(0, i - 1)], p1 = points[i], p2 = points[i + 1], p3 = points[Math.min(points.length - 1, i + 2)];
        d += ` C ${(p1[0] + (p2[0] - p0[0]) / 6).toFixed(1)} ${(p1[1] + (p2[1] - p0[1]) / 6).toFixed(1)}, ${(p2[0] - (p3[0] - p1[0]) / 6).toFixed(1)} ${(p2[1] - (p3[1] - p1[1]) / 6).toFixed(1)}, ${p2[0]} ${p2[1]}`;
      }
      return d;
    }

    let visible = false;
    function morph(now) {
      if (!visible || document.hidden) { last = now; return; }
      const t = (now - last) / 1000;
      const tt = t % CYCLE;
      let p;
      if (tt < 5) p = easeInOut(tt / 5);
      else if (tt < 6.5) p = 1;
      else if (tt < 10) p = 1 - easeInOut((tt - 6.5) / 3.5);
      else p = 0;
      const pts = UP.map((u, i) => [lerp(u[0], SL[i][0], p), lerp(u[1], SL[i][1], p)]);
      curve.setAttribute("d", catmull(pts));
      head.setAttribute("transform", `translate(${pts[0][0]} ${pts[0][1]}) rotate(${(p * 24).toFixed(1)})`);
      const deg = (p * 14).toFixed(0);
      degText.textContent = `${deg}° drift`;
      degText.setAttribute("x", pts[0][0] + 26);
      degText.setAttribute("y", pts[0][1] - 16);
      anchor.setAttribute("cx", pts[4][0]);

      const hot = p > 0.72, mid = p > 0.28 && p <= 0.72;
      curve.style.stroke = hot ? "var(--state-drift)" : "var(--accent)";
      head.style.stroke = curve.style.stroke;
      anchor.style.fill = curve.style.stroke;
      degText.style.fill = curve.style.stroke;
      if (beats.length) {
        beats[0].classList.toggle("active", p <= 0.28);
        beats[1].classList.toggle("active", mid);
        beats[2].classList.toggle("active", hot);
      }
      requestAnimationFrame(morph);
    }
    if (reduced) {
      curve.setAttribute("d", catmull(UP));
      head.setAttribute("transform", `translate(${UP[0][0]} ${UP[0][1]})`);
      curve.style.stroke = "var(--accent)";
      head.style.stroke = "var(--accent)";
      anchor.style.fill = "var(--accent)";
      beats.forEach((b, i) => b.classList.toggle("active", i === 0));
    } else {
      if ("IntersectionObserver" in window) {
        new IntersectionObserver((en) => {
          const wasVisible = visible;
          visible = en[0].isIntersecting;
          if (visible && !wasVisible && !document.hidden) {
            last = performance.now();
            requestAnimationFrame(morph);
          }
        }, { rootMargin: "60px" }).observe(driftHost);
      } else visible = true;
      requestAnimationFrame(morph);
    }
  }

  /* ----------------------------------------------------------
     5. Signal chain — sequential lighting while visible
  ---------------------------------------------------------- */
  const chain = $(".signal-chain");
  if (chain && !reduced) {
    const nodes = $$(".chain-node", chain);
    let idx = 0, timer = null, running = false;
    const step = () => {
      nodes.forEach((n, i) => n.classList.toggle("lit", i === idx));
      idx = (idx + 1) % nodes.length;
    };
    const start = () => {
      if (running) return;
      running = true;
      step();
      timer = setInterval(step, 1100);
    };
    const stop = () => {
      running = false;
      clearInterval(timer);
      nodes.forEach((n) => n.classList.remove("lit"));
    };
    if ("IntersectionObserver" in window) {
      new IntersectionObserver((en) => (en[0].isIntersecting ? start() : stop()), { rootMargin: "40px" }).observe(chain);
    } else start();
  } else if (chain) {
    $$(".chain-node", chain).forEach((n) => n.classList.add("lit"));
  }

  /* ----------------------------------------------------------
     6. Mini weekly chart (bento)
  ---------------------------------------------------------- */
  const chartHost = $("#mini-chart");
  if (chartHost) {
    const DATA = [
      { d: "M", s: 82, t: 3.8 }, { d: "T", s: 89, t: 3.2 }, { d: "W", s: 74, t: 4.6 },
      { d: "T", s: 94, t: 2.8 }, { d: "F", s: 91, t: 3.0 }, { d: "S", s: 85, t: 3.6 },
      { d: "S", s: 95, t: 2.5 },
    ];
    const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    DATA.forEach((row, i) => {
      const isSelected = i === 6;
      const col = document.createElement("button");
      col.type = "button";
      col.className = "col" + (isSelected ? " sel" : "");
      col.setAttribute("aria-pressed", String(isSelected));
      col.setAttribute("aria-label", `${dayNames[i]}: posture score ${row.s}%, average tilt ${row.t} degrees`);
      col.innerHTML = `<span class="bar-track"><span class="bar-fill" style="--h:${row.s}%"></span></span><span class="d">${row.d}</span>`;
      const select = () => {
        $$(".col", chartHost).forEach((c) => {
          c.classList.remove("sel");
          c.setAttribute("aria-pressed", "false");
        });
        col.classList.add("sel");
        col.setAttribute("aria-pressed", "true");
        $("#chart-day").textContent = i === 6 ? "Sunday · today" : dayNames[i];
        $("#chart-score").textContent = `${row.s}%`;
        $("#chart-tilt").textContent = `${row.t.toFixed(1)}°`;
      };
      col.addEventListener("pointerenter", select);
      col.addEventListener("focus", select);
      col.addEventListener("click", select);
      chartHost.appendChild(col);
    });
    if (!reduced && "IntersectionObserver" in window) {
      new IntersectionObserver((en, obs) => {
        if (en[0].isIntersecting) {
          chartHost.classList.add("in");
          obs.disconnect();
        }
      }, { rootMargin: "60px" }).observe(chartHost);
    } else chartHost.classList.add("in");
  }

  /* ----------------------------------------------------------
     7. Voice cues (speechSynthesis, guarded)
  ---------------------------------------------------------- */
  const synth = window.speechSynthesis || null;
  $$(".voice-row").forEach((row) => {
    const btn = $(".voice-play", row);
    btn.addEventListener("click", () => {
      const playing = row.classList.contains("playing");
      $$(".voice-row.playing").forEach((r) => r.classList.remove("playing"));
      if (synth) synth.cancel();
      if (playing) return;
      row.classList.add("playing");
      if (synth && !reduced) {
        try {
          const u = new SpeechSynthesisUtterance(row.dataset.phrase);
          u.rate = 0.96;
          u.pitch = 1;
          u.onend = u.onerror = () => { row.classList.remove("playing"); activeUtterance = null; };
          activeUtterance = u;
          synth.speak(u);
        } catch { row.classList.remove("playing"); activeUtterance = null; }
      } else {
        setTimeout(() => row.classList.remove("playing"), 1400);
      }
    });
  });

  /* ----------------------------------------------------------
     8. Accent theme preview (mirrors app AccentTheme)
  ---------------------------------------------------------- */
  const themeRow = $("#theme-row");
  const THEME_NAMES = { "": "Green", blue: "Blue", purple: "Purple", orange: "Orange", pink: "Pink" };
  function applyTheme(theme, persist = true) {
    if (theme) root.setAttribute("data-theme", theme);
    else root.removeAttribute("data-theme");
    if (persist) {
      try { localStorage.setItem("fms-accent", theme); } catch { /* private mode */ }
    }
    $$(".theme-chip", themeRow).forEach((c) => c.setAttribute("aria-pressed", String(c.dataset.theme === theme)));
    const ro = $("#theme-readout");
    if (ro) ro.textContent = `Accent — ${THEME_NAMES[theme] || "Green"}`;
  }
  if (themeRow) {
    themeRow.addEventListener("click", (e) => {
      const chip = e.target.closest(".theme-chip");
      if (chip) applyTheme(chip.dataset.theme);
    });
    let saved = "";
    try { saved = localStorage.getItem("fms-accent") || ""; } catch { /* ignore */ }
    if (saved && saved in THEME_NAMES) applyTheme(saved, false);
  }

  /* ----------------------------------------------------------
     9. Pointer-tracked glow on cards (fine pointers only)
  ---------------------------------------------------------- */
  if (finePointer && !reduced) {
    const cards = $$(".bento-card, .instrument, .demo-panel, .step-card");
    cards.forEach((card) => {
      card.classList.add("glow-card");
      let r = null;
      card.addEventListener("pointerenter", () => {
        r = card.getBoundingClientRect();
      });
      card.addEventListener("pointermove", (e) => {
        if (!r) r = card.getBoundingClientRect();
        card.style.setProperty("--mx", `${e.clientX - r.left}px`);
        card.style.setProperty("--my", `${e.clientY - r.top}px`);
      }, { passive: true });
    });
  }

  /* ----------------------------------------------------------
     10. Calibration card — live delta shimmer
  ---------------------------------------------------------- */
  const calLive = $("#cal-live");
  if (calLive && !reduced) {
    let visible = false;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver((en) => { visible = en[0].isIntersecting; }, { rootMargin: "40px" }).observe(calLive);
    } else visible = true;
    setInterval(() => {
      if (!visible) return;
      const v = (0.4 + (Math.random() - 0.5) * 0.5).toFixed(1);
      calLive.textContent = `+${v}°`;
    }, 900);
  }

  /* ----------------------------------------------------------
     11. Reveal system + hero entrance (GSAP with IO fallback)
  ---------------------------------------------------------- */
  const heroFadeEls = $$(".hero-fade");
  const h1 = $("#hero-title");
  const revealEls = $$("[data-reveal]");

  let gsapReady = false;
  try {
    if (typeof gsap !== "undefined" && !reduced) {
      gsap.set(heroFadeEls, { opacity: 0, y: 22 });
      gsap.set(revealEls, { opacity: 0, y: 28 });

      gsap.timeline({ delay: 0.15 })
        .to(".hero-badge", { opacity: 1, y: 0, duration: 0.6, ease: "power3.out" })
        .add(() => h1.classList.add("h1-in"), 0.12)
        .to(".hero-position", { opacity: 1, y: 0, duration: 0.65, ease: "power3.out" }, 0.35)
        .to(".hero-sub", { opacity: 1, y: 0, duration: 0.7, ease: "power3.out" }, 0.46)
        .to(".hero-ctas", { opacity: 1, y: 0, duration: 0.7, ease: "power3.out" }, 0.58)
        .to(".hero-trust", { opacity: 1, y: 0, duration: 0.7, ease: "power3.out" }, 0.70)
        .to(".hero-stage", { opacity: 1, y: 0, duration: 1.05, ease: "power3.out" }, 0.55);

      // Reveal engine: native IntersectionObserver trigger (bulletproof for
      // jumps, fast scrolls, resizes) + GSAP tweens for the motion quality.
      let batchQueue = [];
      let batchTimer = null;
      const flushBatch = () => {
        if (!batchQueue.length) return;
        const els = batchQueue;
        batchQueue = [];
        gsap.to(els, { opacity: 1, y: 0, duration: 0.9, stagger: 0.08, ease: "power3.out", overwrite: "auto", clearProps: "transform" });
      };
      const revealIO = new IntersectionObserver((entries) => {
        entries.forEach((en) => {
          if (!en.isIntersecting) return;
          revealIO.unobserve(en.target);
          if (!batchQueue.includes(en.target)) batchQueue.push(en.target);
        });
        clearTimeout(batchTimer);
        batchTimer = setTimeout(flushBatch, 40);
      }, { rootMargin: "0px 0px -10% 0px", threshold: 0.05 });
      revealEls.forEach((el) => revealIO.observe(el));

      // Safety sweep: force-reveal anything in-viewport that was skipped
      const sweep = () => {
        revealEls.forEach((el) => {
          if (gsap.getProperty(el, "opacity") < 1) {
            const r = el.getBoundingClientRect();
            if (r.top < window.innerHeight && r.bottom > 0) {
              gsap.to(el, { opacity: 1, y: 0, duration: 0.6, ease: "power3.out", overwrite: "auto", clearProps: "transform" });
            }
          }
        });
      };
      setTimeout(sweep, 2000);
      let resizeT = null;
      window.addEventListener("resize", () => {
        clearTimeout(resizeT);
        resizeT = setTimeout(sweep, 250);
      }, { passive: true });

      root.classList.add("gsap-ready");
      gsapReady = true;
    }
  } catch (err) {
    // Safety: never leave content invisible
    if (typeof gsap !== "undefined") gsap.set([heroFadeEls, revealEls].flat(), { clearProps: "all" });
    h1 && h1.classList.add("h1-in");
  }

  if (!gsapReady) {
    // No GSAP (offline CDN) or reduced motion: content is visible via CSS.
    heroFadeEls.forEach((el) => (el.style.opacity = ""));
    revealEls.forEach((el) => el.classList.add("reveal-done"));
    h1 && h1.classList.add("h1-in");
  }

  /* ----------------------------------------------------------
     12. Footer year
  ---------------------------------------------------------- */
  const year = $("#year");
  if (year) year.textContent = String(new Date().getFullYear());

  // ---------- 13. Newsletter Signup ----------
  {
    const form = $("#signup-form");
    const emailInput = $("#signup-email");
    const btn = $("#signup-btn");
    const status = $("#signup-status");
    const API = window.location.hostname === "localhost"
      ? "http://localhost:5001"
      : ""; // Production: same-origin or set your API URL

    if (form) {
      form.addEventListener("submit", async (e) => {
        e.preventDefault();
        const email = emailInput.value.trim();
        if (!email) return;

        btn.disabled = true;
        btn.textContent = "Sending…";
        status.textContent = "";
        status.className = "signup-status";

        try {
          const res = await fetch(`${API}/api/subscribe`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, source: "website" }),
          });
          const data = await res.json();

          if (res.ok && data.success) {
            status.textContent = data.isNew
              ? "✓ You're in! We'll notify you on new releases."
              : "✓ You're already subscribed — no action needed.";
            status.className = "signup-status success";
            emailInput.value = "";
          } else {
            status.textContent = data.error || "Something went wrong. Please try again.";
            status.className = "signup-status error";
          }
        } catch {
          status.textContent = "Could not reach the server. Please try again later.";
          status.className = "signup-status error";
        } finally {
          btn.disabled = false;
          btn.textContent = "Get Notified";
        }
      });
    }
  }
})();
