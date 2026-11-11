// Quality gate for a generated HTML/React app before it is delivered: runs the real app in a phone-sized
// headless browser, walks its screens and presses every interactive element, and reports concrete UI bugs that a
// static check cannot see:
//   - JavaScript errors thrown on load or when an element is pressed
//   - DEAD controls: a button/link/tab whose press does nothing (no navigation, no DOM change, no handler)
//   - a blank / empty screen (nothing visible rendered)
//   - horizontal overflow (the layout is broken and scrolls sideways)
//   - broken images (declared but did not load)
// It also saves a screenshot of each distinct screen it reaches (for the visual check).
//
// Usage: node scripts/qa_gate.js path/to/index.html [--shots DIR] [--json OUT]
// Prints the problems (most useful first) and exits 1 when it finds any; exits 0 when the app looks clean or no
// browser is available here (the build still runs it).
const fs = require("fs");
const path = require("path");

const NOISE =
  /Failed to fetch|NetworkError|Load failed|ERR_|net::|Script error\.?$|ResizeObserver|AbortError|NotAllowedError|NotFoundError: Requested device|SecurityError|Permission|play\(\)|vibrate|wakeLock|serviceWorker|Notification|geolocation|getUserMedia|Capacitor|PushNotifications|supabase|firebase/i;

function loadBrowser() {
  for (const mod of ["playwright", "playwright-core"]) {
    try {
      return require(mod).chromium;
    } catch {}
  }
  return null;
}

function browserPath() {
  const list = [
    process.env.CHROME_PATH,
    "/opt/pw-browsers/chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
  ];
  return list.find((p) => p && fs.existsSync(p));
}

// Runs inside the page: a compact digest of what is visible now, so we can tell if a click changed anything.
function snapshotFn() {
  const vis = (el) => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && s.opacity !== "0";
  };
  let shown = 0;
  let text = "";
  document.querySelectorAll("body *").forEach((el) => {
    if (vis(el)) {
      shown++;
      if (el.childElementCount === 0 && el.textContent) text += el.textContent.trim().slice(0, 40);
    }
  });
  return { hash: location.hash, shown, len: text.length, digest: text.slice(0, 4000) };
}

async function run(htmlPath, shotsDir) {
  const html = fs.readFileSync(htmlPath, "utf8");
  const chromium = loadBrowser();
  if (!chromium) {
    console.log("QA gate skipped (no browser available here)");
    return { skipped: true, problems: [] };
  }
  const exe = browserPath();
  let browser;
  for (const opts of [{ headless: true, args: ["--no-sandbox"], ...(exe ? { executablePath: exe } : {}) }, { headless: true, args: ["--no-sandbox"] }]) {
    try {
      browser = await chromium.launch(opts);
      break;
    } catch {}
  }
  if (!browser) {
    console.log("QA gate skipped (browser would not launch)");
    return { skipped: true, problems: [] };
  }

  const problems = [];
  const errors = [];
  const failedLibs = [];
  const seen = new Set();
  const reported = {}; // report each layout/blank kind only once
  const addErr = (msg) => {
    msg = String(msg || "").split("\n")[0].slice(0, 300);
    const undef = msg.match(/ReferenceError: (\w+) is not defined/);
    if (undef && failedLibs.some((u) => u.includes(undef[1].toLowerCase()))) return;
    if (msg && !NOISE.test(msg) && !errors.includes(msg)) errors.push(msg);
  };

  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, deviceScaleFactor: 1 });
    const URL = "http://app.local/index.html";
    await page.route("**/*", (route) => {
      const req = route.request();
      if (req.url().split("#")[0].split("?")[0] === URL)
        return route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: html });
      if (["script", "stylesheet", "font", "image"].includes(req.resourceType()) && req.method() === "GET") return route.continue();
      return route.abort();
    });
    page.on("requestfailed", (r) => r.resourceType() === "script" && failedLibs.push(r.url().toLowerCase()));
    page.on("response", (r) => r.request().resourceType() === "script" && r.status() >= 400 && failedLibs.push(r.url().toLowerCase()));
    page.on("pageerror", (e) => addErr(e.message ? `${e.name || "Error"}: ${e.message}` : e));
    page.on("console", (m) => m.type() === "error" && addErr(m.text()));
    page.on("dialog", (d) => d.accept(d.type() === "prompt" ? "1" : undefined).catch(() => {}));
    page.on("popup", (p) => p.close().catch(() => {}));
    await page.addInitScript(() => (window.open = () => null));

    await page.goto(URL, { waitUntil: "load", timeout: 25000 }).catch((e) => addErr(`The page did not load: ${e.message}`));
    await page.waitForTimeout(900);

    if (shotsDir) fs.mkdirSync(shotsDir, { recursive: true });
    let shotN = 0;
    const screens = [];
    const snapshot = async () => page.evaluate(snapshotFn).catch(() => null);
    const shoot = async (snap) => {
      if (!snap) return;
      const key = snap.digest.replace(/\s+/g, " ").slice(0, 200);
      if (seen.has(key)) return;
      seen.add(key);
      if (shotsDir) {
        const f = path.join(shotsDir, `screen_${String(++shotN).padStart(2, "0")}.png`);
        await page.screenshot({ path: f }).catch(() => {});
        screens.push(f);
      }
    };

    // Layout/content health of the view currently on screen.
    const healthOf = async (label) => {
      const h = await page
        .evaluate(() => {
          const out = {};
          out.overflow = document.documentElement.scrollWidth - window.innerWidth;
          const vis = (el) => {
            const r = el.getBoundingClientRect();
            const s = getComputedStyle(el);
            return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && s.opacity !== "0";
          };
          out.visible = [...document.querySelectorAll("body *")].filter(vis).length;
          out.text = document.body.innerText.trim().length;
          return out;
        })
        .catch(() => null);
      if (!h) return;
      // Sideways scroll is always a broken layout. "Blank" only when the view is genuinely empty (no text at all
      // and almost nothing visible) — a conservative test so a minimal/splash screen is never falsely flagged.
      // Report each kind at most once, so the fixer gets one clear instruction instead of a repeated complaint.
      if (h.overflow > 3 && !reported.overflow) {
        reported.overflow = true;
        problems.push(`layout: the ${label} scrolls sideways (content ${h.overflow}px wider than the screen — a broken layout; make nothing wider than the viewport)`);
      }
      if (h.text < 1 && h.visible < 4 && !reported.blank) {
        reported.blank = true;
        problems.push(`blank: the ${label} renders nothing visible (empty or broken)`);
      }
    };

    const first = await snapshot();
    await shoot(first);
    await healthOf("first screen");

    // Walk the interactive controls: press each, see whether it did anything (navigation or DOM change). Report
    // the ones that are dead. Skip controls that delete / sign out / reload so the walk stays safe.
    const DANGER = /delete|remove|clear|reset|logout|log ?out|sign ?out|reload|location|حذف|مسح|امسح|خروج|إعادة ضبط|تسجيل الخروج/i;
    let pressed = 0;
    let dead = 0;
    const controls = await page.$$("button, a[href], [role=button], [onclick], input[type=button], input[type=submit], .tab, [class*=tab], [class*=nav] li");
    for (const el of controls.slice(0, 80)) {
      let info;
      try {
        info = await el.evaluate((n) => ({
          txt: ((n.getAttribute("aria-label") || "") + " " + (n.textContent || "") + " " + (n.id || "") + " " + (n.className || "") + " " + (n.getAttribute("onclick") || "")).trim().slice(0, 80),
          hasHandler: !!(n.onclick || n.getAttribute("onclick") || n.getAttribute("href") || n.closest("form")),
          visible: (() => {
            const r = n.getBoundingClientRect();
            const s = getComputedStyle(n);
            return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && !n.disabled;
          })(),
        }));
      } catch {
        continue;
      }
      if (!info.visible || DANGER.test(info.txt)) continue;

      const before = await snapshot();
      // Count DOM mutations during the click.
      await page.evaluate(() => {
        window.__qaMut = 0;
        window.__qaObs && window.__qaObs.disconnect();
        window.__qaObs = new MutationObserver((ms) => (window.__qaMut += ms.length));
        window.__qaObs.observe(document.body, { childList: true, subtree: true, attributes: true, characterData: true });
      });
      try {
        await el.click({ timeout: 1500, trial: false });
        pressed++;
      } catch {
        continue; // not clickable (covered/animating): not counted as dead
      }
      await page.waitForTimeout(220);
      const mut = await page.evaluate(() => (window.__qaObs && window.__qaObs.disconnect(), window.__qaMut || 0)).catch(() => 0);
      const after = await snapshot();
      const changed = !before || !after || before.hash !== after.hash || Math.abs(before.shown - after.shown) > 1 || before.digest !== after.digest || mut > 1;
      if (!changed && !info.hasHandler) {
        dead++;
        if (dead <= 8) problems.push(`dead control: pressing «${info.txt.replace(/\s+/g, " ").trim() || "(no label)"}» does nothing — no navigation, no change, no handler`);
      } else if (changed) {
        await shoot(after);
        await healthOf("screen after «" + (info.txt.replace(/\s+/g, " ").trim().slice(0, 24) || "a control") + "»");
      }
    }

    errors.slice(0, 12).forEach((e) => problems.push(`runtime error: ${e}`));
    console.log(`QA gate: ran the app, pressed ${pressed} controls, found ${dead} dead and ${errors.length} runtime error(s); ${screens.length} screen(s) captured`);
    return { skipped: false, problems, screens };
  } finally {
    await browser.close().catch(() => {});
  }
}

async function main() {
  const args = process.argv.slice(2);
  const htmlPath = args.find((a) => !a.startsWith("--"));
  const shotsDir = args.includes("--shots") ? args[args.indexOf("--shots") + 1] : null;
  const jsonOut = args.includes("--json") ? args[args.indexOf("--json") + 1] : null;
  if (!htmlPath || !fs.existsSync(htmlPath)) {
    console.error("Usage: node scripts/qa_gate.js path/to/index.html [--shots DIR] [--json OUT]");
    process.exit(2);
  }
  const res = await run(htmlPath, shotsDir);
  if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(res, null, 1));
  if (res.problems.length) {
    console.log("\nUI problems found:");
    res.problems.forEach((p) => console.log("- " + p));
    process.exit(1);
  }
  console.log(res.skipped ? "QA gate skipped." : "QA gate: no UI problems found.");
  process.exit(0);
}

if (require.main === module) main();
module.exports = { run };
