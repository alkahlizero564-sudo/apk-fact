// Check for a generated HTML app, before it is saved and before every build.
//  1. JavaScript syntax errors in its inline <script> blocks and in inline event handlers (onclick="...").
//  2. When a browser is available (playwright-core + Chrome/Chromium): runs the app headless, reports errors
//     thrown while it loads, buttons that call functions that are not defined, and errors thrown when its
//     buttons are pressed. These don't fail the APK build, but they leave the app blank or broken.
//
// Usage: node scripts/check_html.js path/to/index.html
// Prints problems (with the line number in index.html) and exits 1 when it finds any.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const JS_TYPES = ["", "text/javascript", "application/javascript", "module", "text/babel"];

function checkHtml(html) {
  const problems = [];
  const re = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "check-html-"));
  let m;
  try {
    while ((m = re.exec(html))) {
      const attrs = m[1];
      if (/\bsrc\s*=/i.test(attrs)) continue;
      const typeMatch = attrs.match(/\btype\s*=\s*["']?([^"'\s>]+)/i);
      const type = typeMatch ? typeMatch[1].toLowerCase() : "";
      if (!JS_TYPES.includes(type) || type === "text/babel") continue;
      const code = m[2];
      if (!code.trim()) continue;
      // Line in index.html where the script's code starts.
      const offset = html.slice(0, m.index + m[0].indexOf(">") + 1).split("\n").length - 1;
      const file = path.join(tmp, `s${m.index}${type === "module" ? ".mjs" : ".js"}`);
      fs.writeFileSync(file, code);
      try {
        execFileSync(process.execPath, ["--check", file], { stdio: "pipe" });
      } catch (e) {
        const out = String(e.stderr || e.message);
        const lineMatch = out.match(new RegExp(file.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ":(\\d+)"));
        const line = lineMatch ? offset + Number(lineMatch[1]) : offset + 1;
        const msg = (out.match(/^(SyntaxError: .*)$/m) || [null, out.trim().split("\n").pop()])[1];
        problems.push(`line ${line}: ${msg}`);
      }
    }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
  if (!/<html|<!doctype/i.test(html)) problems.push("line 1: not a complete HTML document");
  return problems.concat(handlerErrors(html));
}

// Inline event handlers (onclick="..."): a syntax error there only shows up when the button is pressed.
function handlerErrors(html) {
  const out = [];
  const re = /\son([a-z]+)\s*=\s*"([^"]*)"/g;
  let m;
  let n = 0;
  while ((m = re.exec(html)) && n < 300) {
    n++;
    const v = m[2].replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
    // Handlers built inside JavaScript strings/templates ("onclick=\"f('+id+')\"") are checked when they run.
    if (/['"]\s*\+|\+\s*['"]|\$\{|\\/.test(v)) continue;
    try {
      new Function("event", v);
    } catch (e) {
      const line = html.slice(0, m.index).split("\n").length;
      out.push(`line ${line}: SyntaxError in on${m[1]}="${m[2].slice(0, 60)}": ${e.message}`);
    }
  }
  return out;
}

// Errors that come from the missing network/hardware in the headless check, not from the app's code.
const NOISE =
  /Failed to fetch|NetworkError|Load failed|ERR_|net::|Script error\.?$|ResizeObserver|AbortError|NotAllowedError|NotFoundError: Requested device|SecurityError|Permission|play\(\)|vibrate|wakeLock|serviceWorker|Notification|geolocation|getUserMedia|Capacitor|PushNotifications|supabase|firebase/i;

function loadBrowser() {
  for (const mod of ["playwright-core", "playwright"]) {
    try {
      return require(mod).chromium;
    } catch {}
  }
  return null;
}

function browserPath() {
  const list = [process.env.CHROME_PATH, "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser"];
  return list.find((p) => p && fs.existsSync(p));
}

// Runs the app in a phone-sized headless browser and presses its buttons. Returns null when no browser is available.
async function runtimeErrors(html) {
  const chromium = loadBrowser();
  if (!chromium) return null;
  let browser;
  try {
    const exe = browserPath();
    browser = await chromium.launch({ headless: true, args: ["--no-sandbox"], ...(exe ? { executablePath: exe } : {}) });
  } catch (e) {
    try {
      browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
    } catch {
      console.log(`Runtime check skipped (no browser: ${String(e.message).split("\n")[0]})`);
      return null;
    }
  }
  const errors = [];
  const failedLibs = []; // CDN scripts that could not be downloaded here: their globals are missing, not the app's fault
  const add = (msg) => {
    msg = String(msg || "").split("\n")[0].slice(0, 300);
    const undef = msg.match(/ReferenceError: (\w+) is not defined/);
    if (undef && failedLibs.some((u) => u.includes(undef[1].toLowerCase()))) return;
    if (msg && !NOISE.test(msg) && !errors.includes(msg)) errors.push(msg);
  };
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true });
    const URL = "http://app.local/index.html";
    // Serve the app from a real origin (localStorage works); no data calls leave the machine while buttons are
    // pressed, but libraries/fonts/images from CDNs still load.
    await page.route("**/*", (route) => {
      const req = route.request();
      if (req.url().split("#")[0].split("?")[0] === URL)
        return route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: html });
      if (["script", "stylesheet", "font", "image"].includes(req.resourceType()) && req.method() === "GET")
        return route.continue();
      return route.abort();
    });
    page.on("requestfailed", (r) => {
      if (r.resourceType() === "script") failedLibs.push(r.url().toLowerCase());
    });
    page.on("response", (r) => {
      if (r.request().resourceType() === "script" && r.status() >= 400) failedLibs.push(r.url().toLowerCase());
    });
    page.on("pageerror", (e) => add(e.message ? `${e.name || "Error"}: ${e.message}` : e));
    page.on("dialog", (d) => d.accept(d.type() === "prompt" ? "1" : undefined).catch(() => {}));
    page.on("popup", (p) => p.close().catch(() => {}));
    await page.addInitScript(() => {
      window.open = () => null;
    });
    await page.goto(URL, { waitUntil: "load", timeout: 20000 }).catch((e) => add(`The page did not load: ${e.message}`));
    await page.waitForTimeout(800);

    const scan = () =>
      page
        .evaluate(() => {
          const SKIP = new Set(["if", "return", "function", "typeof", "new", "while", "for", "switch", "catch", "void", "delete", "await"]);
          const has = (n) => {
            try {
              return n in window || (0, eval)("typeof " + n) !== "undefined";
            } catch {
              return true; // eval blocked (CSP): don't guess
            }
          };
          const miss = {};
          document.querySelectorAll("*").forEach((el) => {
            for (const a of el.attributes) {
              if (!/^on/.test(a.name)) continue;
              const re = /(^|[^.\w$])([A-Za-z_$][\w$]*)\s*\(/g;
              let m;
              while ((m = re.exec(a.value))) if (!SKIP.has(m[2]) && !has(m[2])) miss[m[2]] = a.name;
            }
          });
          return Object.entries(miss).map(([n, on]) => `ReferenceError: ${n}() is called from ${on}="..." but is not defined`);
        })
        .catch(() => []);

    (await scan()).forEach(add);
    // Press the buttons (skipping ones that delete, reset, sign out or leave the page) and watch for errors.
    const pressed = await page
      .evaluate(async () => {
        const DANGER = /delete|remove|clear|reset|logout|log ?out|sign ?out|reload|location|حذف|مسح|امسح|خروج|إعادة ضبط/i;
        const els = [...document.querySelectorAll("button, [onclick], [role=button], input[type=button], input[type=submit]")].slice(0, 60);
        let n = 0;
        for (const el of els) {
          if (!el.isConnected || el.disabled) continue;
          const text = (el.getAttribute("onclick") || "") + " " + (el.textContent || "") + " " + (el.id || "") + " " + (el.className || "");
          if (DANGER.test(text)) continue;
          try {
            el.click();
            n++;
          } catch {}
          await new Promise((r) => setTimeout(r, 40));
        }
        return n;
      })
      .catch(() => 0);
    await page.waitForTimeout(600);
    if (page.url().split("#")[0].split("?")[0] === URL) (await scan()).forEach(add);
    console.log(`Runtime check: the app ran and ${pressed} buttons were pressed`);
  } finally {
    await browser.close().catch(() => {});
  }
  return errors.slice(0, 12).map((e) => `runtime: ${e}`);
}

// Syntax check, then (when there are no syntax errors and a browser is available) the runtime check.
async function checkHtmlFull(html) {
  const problems = checkHtml(html);
  if (problems.length || process.env.CHECK_HTML_RUNTIME === "0") return problems;
  try {
    return (await runtimeErrors(html)) || [];
  } catch (e) {
    console.log(`Runtime check skipped (${e.message})`);
    return [];
  }
}

module.exports = { checkHtml, checkHtmlFull, runtimeErrors };

if (require.main === module) {
  (async () => {
    const problems = await checkHtmlFull(fs.readFileSync(process.argv[2], "utf8"));
    if (problems.length) {
      console.log("error: HTML check failed:");
      for (const p of problems) console.log(`error: ${p}`);
      process.exit(1);
    }
    console.log("HTML check passed");
  })();
}
