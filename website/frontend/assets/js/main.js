(() => {
  "use strict";

  const $ = (selector, context = document) => context.querySelector(selector);
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const header = $("#site-header");
  const menuToggle = $("#menu-toggle");
  const mobileMenu = $("#mobile-menu");

  const updateHeader = () => header?.classList.toggle("scrolled", window.scrollY > 16);
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  if (menuToggle && mobileMenu) {
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
    mobileMenu.addEventListener("click", (event) => {
      if (event.target.closest("a")) closeMenu();
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && mobileMenu.classList.contains("open")) {
        closeMenu();
        menuToggle.focus();
      }
    });
    window.addEventListener("resize", () => {
      if (window.innerWidth > 980) closeMenu();
    }, { passive: true });
  }

  /* A restrained pointer tilt makes the hero feel physical without hijacking scroll. */
  const stage = $("#hero-stage");
  if (stage && !reducedMotion && window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    stage.addEventListener("pointermove", (event) => {
      const rect = stage.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width - 0.5;
      const y = (event.clientY - rect.top) / rect.height - 0.5;
      stage.style.transform = `rotateX(${(-y * 5).toFixed(2)}deg) rotateY(${(x * 7).toFixed(2)}deg)`;
    });
    stage.addEventListener("pointerleave", () => { stage.style.transform = ""; });
  }

  /* Interactive spine instrument. */
  const demoHost = $("#demoSpineHost");
  const slider = $("#postureSlider");
  const degree = $("#sliderDegDisplay");
  const pitchReadout = $("#demoPitchReadout");
  const stateReadout = $("#demoStateReadout");
  const gauge = $("#popoverGaugeRing");
  const angleReadout = $("#popoverAngleText");
  const statusReadout = $("#popoverStatusText");
  const popoverPitch = $("#popoverPitchVal");
  const popoverRoll = $("#popoverRollVal");

  function createSpine() {
    if (!demoHost) return null;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 320 380");
    svg.setAttribute("aria-hidden", "true");
    svg.innerHTML = `<defs><linearGradient id="spine-gradient" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b6ff65"/><stop offset="1" stop-color="#557c52"/></linearGradient></defs><line x1="160" y1="20" x2="160" y2="360" stroke="rgba(182,255,101,.14)" stroke-dasharray="2 6"/><path d="M132 350h56" stroke="rgba(255,255,255,.34)" stroke-width="3" stroke-linecap="round"/><path id="spine-curve" stroke="url(#spine-gradient)" stroke-width="4" stroke-linecap="round" fill="none"/><g id="vertebrae"></g><g id="spine-head"><circle cx="0" cy="0" r="22" fill="#172019" stroke="#f2f4f1" stroke-width="2"/><circle cx="21" cy="4" r="2.5" fill="#b6ff65"/><circle cx="-3" cy="0" r="7" fill="none" stroke="#b6ff65" stroke-width="1.4"/><rect x="-5" y="4" width="4" height="12" rx="2" fill="#f2f4f1"/></g>`;
    demoHost.appendChild(svg);
    const vertebrae = $("#vertebrae", svg);
    const nodes = [];
    for (let i = 0; i < 12; i += 1) {
      const node = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      node.setAttribute("width", i < 4 ? "13" : "20");
      node.setAttribute("height", "7");
      node.setAttribute("rx", "3.5");
      node.setAttribute("fill", "#172019");
      node.setAttribute("stroke", "#b6ff65");
      node.setAttribute("stroke-width", "1.2");
      vertebrae.appendChild(node);
      nodes.push(node);
    }
    return { svg, curve: $("#spine-curve", svg), head: $("#spine-head", svg), nodes };
  }

  const spine = createSpine();
  function renderPosture(rawValue) {
    const value = Number(rawValue);
    const radians = (value * Math.PI) / 180;
    let label = "Aligned";
    let color = "#b6ff65";
    if (Math.abs(value) > 5 && Math.abs(value) <= 12) { label = "Drifting"; color = "#ffc857"; }
    if (Math.abs(value) > 12) { label = "Slouch alert"; color = "#ff6d57"; }
    if (degree) degree.textContent = `${value >= 0 ? "+" : ""}${value.toFixed(1)}°`;
    if (pitchReadout) pitchReadout.innerHTML = `${Math.abs(value).toFixed(1)}° <small>${value >= 0 ? "forward" : "backward"}</small>`;
    if (stateReadout) stateReadout.innerHTML = `<i class="state-dot" style="background:${color}" aria-hidden="true"></i> ${label}`;
    if (angleReadout) angleReadout.textContent = `${Math.abs(value).toFixed(1)}°`;
    if (statusReadout) { statusReadout.textContent = `AirPods Pro — ${label}`; statusReadout.style.color = color; }
    if (popoverPitch) popoverPitch.textContent = `${value >= 0 ? "+" : ""}${value.toFixed(1)}°`;
    if (popoverRoll) popoverRoll.textContent = `${(Math.sin(radians * 1.5) * .8).toFixed(1)}°`;
    if (gauge) { gauge.style.borderColor = color; gauge.style.boxShadow = `0 0 26px ${color}33`; }
    if (!spine) return;
    const topX = 160 + Math.sin(radians) * 64;
    const topY = 68 + (1 - Math.cos(radians)) * 26;
    const midX = 160 + Math.sin(radians) * 34;
    spine.head.setAttribute("transform", `translate(${topX} ${topY}) rotate(${value * 1.1})`);
    spine.curve.setAttribute("d", `M 160 350 Q ${midX} 210 ${topX} ${topY}`);
    spine.nodes.forEach((node, index) => {
      const t = (index + 1) / 13;
      const x = (1 - t) ** 2 * 160 + 2 * (1 - t) * t * midX + t ** 2 * topX;
      const y = (1 - t) ** 2 * 350 + 2 * (1 - t) * t * 210 + t ** 2 * topY;
      node.setAttribute("transform", `translate(${x} ${y}) rotate(${value * t * .85})`);
      node.setAttribute("stroke", color);
    });
  }
  if (slider) { slider.addEventListener("input", (event) => renderPosture(event.target.value)); renderPosture(slider.value); }

  /* Early access form — real backend request, never a simulated success. */
  const form = $("#signup-form");
  const emailInput = $("#signup-email");
  const submitButton = $("#signup-btn");
  const status = $("#signup-status");
  const localHosts = new Set(["localhost", "127.0.0.1", "[::1]"]);
  const apiBase = window.FIXMYSPINE_API_BASE || (localHosts.has(window.location.hostname) ? `${window.location.protocol}//${window.location.hostname}:5001` : "");
  const setStatus = (message, kind) => { if (!status) return; status.textContent = message; status.className = `signup-status ${kind}`; status.setAttribute("role", kind === "error" ? "alert" : "status"); };
  if (form && emailInput && submitButton) {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const email = emailInput.value.trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { setStatus("Please enter a valid email address.", "error"); emailInput.focus(); return; }
      submitButton.disabled = true; submitButton.setAttribute("aria-busy", "true"); submitButton.innerHTML = "Saving…"; setStatus("", "");
      try {
        const response = await fetch(`${apiBase}/api/subscribe`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, source: "website" }) });
        const data = await response.json().catch(() => ({}));
        if (!response.ok || !data.success) throw new Error(data.error || "Request failed");
        setStatus(data.message || "You're on the list. We'll email you on release.", "success"); emailInput.value = "";
      } catch (_error) { setStatus("We couldn't save that yet. Please try again in a moment.", "error"); }
      finally { submitButton.disabled = false; submitButton.removeAttribute("aria-busy"); submitButton.innerHTML = "Join the list <span aria-hidden=\"true\">↗</span>"; }
    });
  }

  const heroJoin = $("#heroJoinBtn");
  if (heroJoin && emailInput) heroJoin.addEventListener("click", (event) => { event.preventDefault(); $("#get-notified")?.scrollIntoView({ behavior: reducedMotion ? "auto" : "smooth", block: "center" }); window.setTimeout(() => emailInput.focus(), reducedMotion ? 0 : 450); });
  const year = $("#year"); if (year) year.textContent = String(new Date().getFullYear());
})();
