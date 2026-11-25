// Runs the REAL Flutter app (its web build) signed in, presses its buttons and tabs like a user, and photographs
// every screen it reaches: what an AI reviewer then looks at (scripts/qa_flutter_web.py).
//
// Usage: node scripts/qa_flutter_web.js <build/web dir> <out dir> <storage.json>
//   storage.json: {"flutter.<prefix>.access": "\"<token>\"", ...}  — localStorage entries (a signed-in session)
// Writes <out>/shot_NN.png and <out>/manifest.json:
//   [{file, path: ["tab", "button"], changed: bool, errors: ["..."]}]
// Never presses sign-out / delete buttons. Exits 0 without output when no browser is available.
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

const TYPES = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json",
  ".wasm": "application/wasm", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".ttf": "font/ttf",
  ".otf": "font/otf", ".woff2": "font/woff2", ".css": "text/css", ".ico": "image/x-icon", ".bin": "application/octet-stream",
  ".frag": "application/octet-stream",
};
const SKIP = /(خروج|تسجيل الخروج|حذف|إلغاء الحساب|احذف|مسح|logout|log out|sign out|delete|remove)/i;
const MAX_SHOTS = 26;
const crypto = require("crypto");

async function main() {
  const [dir, out, storageFile] = process.argv.slice(2);
  const chromium = loadBrowser();
  if (!chromium || !dir || !fs.existsSync(path.join(dir, "index.html"))) return;
  fs.mkdirSync(out, { recursive: true });
  const storage = storageFile && fs.existsSync(storageFile) ? JSON.parse(fs.readFileSync(storageFile, "utf8")) : {};
  const exe = browserPath();
  // The app is served from a made-up origin; let it reach its backend whatever address that has.
  const args = ["--no-sandbox", "--disable-features=BlockInsecurePrivateNetworkRequests,PrivateNetworkAccessSendPreflights,PrivateNetworkAccessRespectPreflightResults"];
  const browser = await chromium.launch(exe ? { executablePath: exe, args } : { args });
  const manifest = [];
  const seen = new Map(); // screenshot hash -> path that first reached it

  async function open() {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1.5 });
    const errors = [];
    page.on("console", (m) => {
      const t = m.text();
      if (m.type() === "error" || /EXCEPTION CAUGHT|Another exception was thrown|RenderFlex overflowed|Null check operator/i.test(t)) {
        if (!/favicon|Failed to load resource: the server responded with a status of 404/.test(t)) errors.push(t.slice(0, 300));
      }
    });
    page.on("pageerror", (e) => errors.push(String(e.message || e).slice(0, 300)));
    const base = "http://app.local/";
    await page.route("**/*", async (route) => {
      const url = route.request().url();
      if (!url.startsWith(base)) {
        // The app's own backend calls go out for real, sent by Playwright (no browser private-network rules).
        try {
          return await route.fulfill({ response: await route.fetch() });
        } catch {
          return route.abort();
        }
      }
      let rel = decodeURIComponent(url.slice(base.length).split("?")[0].split("#")[0]) || "index.html";
      const file = path.join(dir, rel);
      if (!file.startsWith(path.resolve(dir)) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        return route.fulfill({ status: 404, body: "" });
      }
      return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || "application/octet-stream", body: fs.readFileSync(file) });
    });
    await page.addInitScript((entries) => {
      for (const [k, v] of Object.entries(entries)) localStorage.setItem(k, v);
    }, storage);
    await page.goto(base, { waitUntil: "load", timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(6000); // first frame + the first data from the backend
    await page.evaluate(() => {
      const e = document.querySelector("flt-semantics-placeholder");
      if (e) e.click();
    });
    await page.waitForTimeout(700);
    return { page, errors };
  }

  async function targets(page) {
    // Everything a user can press, from Flutter's accessibility tree.
    return page.evaluate(() => {
      const out = [];
      const nodes = document.querySelectorAll('flt-semantics[role="button"], flt-semantics[role="tab"], flt-semantics[role="link"], flt-semantics[role="menuitem"], [flt-tappable]');
      for (const n of nodes) {
        const r = n.getBoundingClientRect();
        if (r.width < 8 || r.height < 8 || r.bottom < 0 || r.top > window.innerHeight) continue;
        const name = (n.getAttribute("aria-label") || n.textContent || "").trim().replace(/\s+/g, " ").slice(0, 60);
        out.push({ name, x: r.left + r.width / 2, y: r.top + r.height / 2, tab: n.getAttribute("role") === "tab" || r.top > window.innerHeight - 110 });
      }
      return out;
    });
  }

  async function shoot(page, errors, trail) {
    // Mouse away from what was pressed, so a hover / ripple color does not count as "the screen changed".
    await page.mouse.move(2, 2);
    await page.waitForTimeout(1800);
    const buf = await page.screenshot();
    const hash = crypto.createHash("sha1").update(buf).digest("hex");
    const before = seen.get(hash);
    const entry = { file: null, path: trail, changed: true, errors: [...new Set(errors)] };
    if (before && trail.length) {
      entry.changed = false; // same picture as a screen already seen
      entry.same_as = before.join(" > ") || "the first screen";
    } else {
      const file = `shot_${String(manifest.filter((m) => m.file).length + 1).padStart(2, "0")}.png`;
      fs.writeFileSync(path.join(out, file), buf);
      entry.file = file;
      seen.set(hash, trail);
    }
    manifest.push(entry);
    return entry;
  }

  async function replay(trail) {
    const { page, errors } = await open();
    for (const label of trail) {
      const t = (await targets(page)).find((x) => x.name === label);
      if (!t) break;
      await page.mouse.click(t.x, t.y);
      await page.waitForTimeout(1400);
    }
    return { page, errors };
  }

  // The first screen, then every tab (bottom navigation), then the buttons of each of those screens.
  let { page, errors } = await open();
  await shoot(page, errors, []);
  const first = (await targets(page)).filter((t) => t.name && !SKIP.test(t.name));
  await page.close();
  const tabs = first.filter((t) => t.tab);
  const roots = [[], ...tabs.map((t) => [t.name])];
  for (const root of roots) {
    if (manifest.filter((m) => m.file).length >= MAX_SHOTS) break;
    let base = null;
    if (root.length) {
      ({ page, errors } = await replay(root));
      base = await shoot(page, errors, root);
      await page.close();
      if (!base.changed) continue;
    }
    ({ page, errors } = await replay(root));
    const buttons = (await targets(page)).filter((t) => t.name && !t.tab && !SKIP.test(t.name)).slice(0, 5);
    await page.close();
    for (const b of buttons) {
      if (manifest.filter((m) => m.file).length >= MAX_SHOTS) break;
      ({ page, errors } = await replay([...root, b.name]));
      await shoot(page, errors, [...root, b.name]);
      await page.close();
    }
  }
  await browser.close();
  fs.writeFileSync(path.join(out, "manifest.json"), JSON.stringify(manifest, null, 1));
  console.log(`Captured ${manifest.filter((m) => m.file).length} screens, ${manifest.length} presses`);
}

main().catch((e) => {
  console.log(`QA run skipped: ${e.message}`);
});
