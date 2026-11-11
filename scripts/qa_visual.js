// Captures screenshots of the APPROVED design and of the BUILT app, phone-sized, so an AI vision check can compare
// how the app actually looks against the design the owner signed off on (scripts/qa_visual.py does the comparing).
//
// Usage: node scripts/qa_visual.js <app_dir> <out_dir>
//   <app_dir>/design.html -> out/design_NN.png (one per screen, via the #apkfact-screens switcher)
//   <app_dir>/index.html  -> out/app_NN.png    (first screen + each bottom-nav / tab destination)
// Prints the files it wrote. Needs a browser (playwright + system Chrome); prints nothing and exits 0 if none.
const fs = require("fs");
const path = require("path");

function loadBrowser() {
  for (const m of ["playwright", "playwright-core"]) {
    try {
      return require(m).chromium;
    } catch {}
  }
  return null;
}
function browserPath() {
  return [process.env.CHROME_PATH, "/opt/pw-browsers/chromium", "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser"].find(
    (p) => p && fs.existsSync(p)
  );
}

async function newApp(browser, html) {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  const URL = "http://app.local/index.html";
  await page.route("**/*", (route) => {
    const req = route.request();
    if (req.url().split("#")[0].split("?")[0] === URL) return route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: html });
    if (["script", "stylesheet", "font", "image"].includes(req.resourceType()) && req.method() === "GET") return route.continue();
    return route.abort();
  });
  await page.addInitScript(() => (window.open = () => null));
  page.on("dialog", (d) => d.accept(d.type() === "prompt" ? "1" : undefined).catch(() => {}));
  await page.goto(URL, { waitUntil: "load", timeout: 25000 }).catch(() => {});
  await page.waitForTimeout(900);
  return page;
}

const HIDE = "qa-hide-switcher";
// Hide the reviewer-only #apkfact-screens bar for a screenshot, so the design shot shows the app only (the built
// app has no such bar). Toggled around each shot because we still need the bar to click between screens.
async function setSwitcherHidden(page, hidden) {
  await page.evaluate(
    ([id, on]) => {
      let st = document.getElementById(id);
      if (on) {
        if (!st) {
          st = document.createElement("style");
          st.id = id;
          st.textContent = "#apkfact-screens,[id*=apkfact-screens]{display:none!important}";
          document.head.appendChild(st);
        }
        window.scrollTo(0, 0);
      } else if (st) {
        st.remove();
      }
    },
    [HIDE, hidden]
  );
}

async function shootDesign(page, outDir) {
  const files = [];
  // The switcher pills are the screens. Click each, then screenshot the app with the bar hidden.
  const pills = await page.$$(
    "#apkfact-screens [onclick], #apkfact-screens a, #apkfact-screens button, #apkfact-screens [role=button], " +
      "#apkfact-screens li, #apkfact-screens .screen-pill, #apkfact-screens .pill, #apkfact-screens > div, #apkfact-screens > span"
  );
  const n = Math.min(pills.length || 1, 6);
  for (let i = 0; i < n; i++) {
    try {
      if (pills[i]) {
        await pills[i].click({ timeout: 1500 }).catch(() => {});
        await page.waitForTimeout(500);
      }
      await setSwitcherHidden(page, true);
      const f = path.join(outDir, `design_${String(i + 1).padStart(2, "0")}.png`);
      await page.screenshot({ path: f });
      files.push(f);
      await setSwitcherHidden(page, false);
    } catch {}
  }
  return files;
}

async function shootApp(page, outDir) {
  const files = [];
  const shoot = async (i) => {
    const f = path.join(outDir, `app_${String(i).padStart(2, "0")}.png`);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: f }).catch(() => {});
    files.push(f);
  };
  await shoot(1);
  // Visit each bottom-nav / tab destination.
  const navs = await page.$$(
    "nav a, nav button, [class*=bottom] a, [class*=bottom] button, [class*=tab] button, [class*=tab] a, [role=tab], footer a, footer button"
  );
  let i = 1;
  for (const el of navs.slice(0, 8)) {
    if (i >= 6) break;
    try {
      const vis = await el.isVisible().catch(() => false);
      if (!vis) continue;
      await el.click({ timeout: 1500 });
      await page.waitForTimeout(500);
      i++;
      await shoot(i);
    } catch {}
  }
  return files;
}

async function main() {
  const appDir = process.argv[2];
  const outDir = process.argv[3];
  if (!appDir || !outDir) {
    console.error("Usage: node scripts/qa_visual.js <app_dir> <out_dir>");
    process.exit(2);
  }
  const chromium = loadBrowser();
  if (!chromium) {
    console.log("Visual capture skipped (no browser)");
    process.exit(0);
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
    console.log("Visual capture skipped (browser would not launch)");
    process.exit(0);
  }
  fs.mkdirSync(outDir, { recursive: true });
  const out = { design: [], app: [] };
  try {
    const designHtml = path.join(appDir, "design.html");
    if (fs.existsSync(designHtml)) {
      const p = await newApp(browser, fs.readFileSync(designHtml, "utf8"));
      out.design = await shootDesign(p, outDir);
      await p.close().catch(() => {});
    }
    const indexHtml = path.join(appDir, "index.html");
    if (fs.existsSync(indexHtml)) {
      const p = await newApp(browser, fs.readFileSync(indexHtml, "utf8"));
      out.app = await shootApp(p, outDir);
      await p.close().catch(() => {});
    }
  } finally {
    await browser.close().catch(() => {});
  }
  fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(out, null, 1));
  console.log(`Visual capture: ${out.design.length} design screen(s), ${out.app.length} app screen(s) -> ${outDir}`);
}

if (require.main === module) main();
