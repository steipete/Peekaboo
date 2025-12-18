const commands = {
  brew: "brew install steipete/tap/peekaboo",
  npm: "npx -y @steipete/peekaboo",
};

function setActiveTab(root, tabName) {
  const code = root.querySelector("[data-code]");
  const tabs = Array.from(root.querySelectorAll("[data-tab]"));

  for (const tab of tabs) {
    const isActive = tab.dataset.tab === tabName;
    tab.classList.toggle("isActive", isActive);
    tab.setAttribute("aria-selected", isActive ? "true" : "false");
  }

  if (code) code.textContent = commands[tabName] ?? commands.brew;
}

function setupCommandCard() {
  const root = document.querySelector("[data-cmd]");
  if (!root) return;

  setActiveTab(root, "brew");

  root.addEventListener("click", async (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;

    const tabName = target.dataset.tab;
    if (tabName) {
      setActiveTab(root, tabName);
      return;
    }

    if (!target.hasAttribute("data-copy")) return;

    const code = root.querySelector("[data-code]");
    if (!code) return;
    const text = code.textContent ?? "";

    try {
      await navigator.clipboard.writeText(text);
      target.textContent = "Copied";
      window.setTimeout(() => {
        target.textContent = "Copy";
      }, 900);
    } catch {
      // clipboard can fail in some browsers; silent fallback
    }
  });
}

function setupEye() {
  const eyes = Array.from(document.querySelectorAll(".eye"));
  if (eyes.length === 0) return;

  let lastX = 0;
  let lastY = 0;
  let raf = 0;

  const tick = () => {
    raf = 0;

    for (const eye of eyes) {
      const rect = eye.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = lastX - cx;
      const dy = lastY - cy;

      const max = 3.2;
      const len = Math.hypot(dx, dy) || 1;
      const ux = (dx / len) * max;
      const uy = (dy / len) * max;

      eye.style.transform = `translate(calc(-50% + ${ux}px), calc(-50% + ${uy}px))`;
    }
  };

  window.addEventListener(
    "pointermove",
    (event) => {
      lastX = event.clientX;
      lastY = event.clientY;
      if (!raf) raf = window.requestAnimationFrame(tick);
    },
    { passive: true },
  );

  // blink
  window.setInterval(() => {
    for (const eye of eyes) {
      eye.animate(
        [{ transform: eye.style.transform, filter: "saturate(1)" }, { transform: `${eye.style.transform} scaleY(0.1)`, filter: "saturate(0.8)" }, { transform: eye.style.transform, filter: "saturate(1)" }],
        { duration: 170, easing: "ease-out" },
      );
    }
  }, 5200);
}

setupCommandCard();
setupEye();

