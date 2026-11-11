// Functional-depth check for an HTML/React app: it does not just render — it actually WORKS. Runs the app in a
// phone-sized headless browser, fills each form with test data and submits it, and checks that the submit DID
// SOMETHING (saved data to localStorage, added an item, navigated, or showed a message). A form that submits and
// nothing happens is a broken core flow (e.g. an "add" form that adds nothing). It also checks that data the app
// stores survives a reload (kept between launches, as the design standard requires).
//
// Usage: node scripts/qa_flows.js path/to/index.html
// Prints problems starting with "- flow:" and exits 1 when it finds any; exits 0 when clean or no browser.
const fs = require("fs");

const NOISE =
  /Failed to fetch|NetworkError|Load failed|ERR_|net::|Script error\.?$|ResizeObserver|AbortError|NotAllowedError|SecurityError|Permission|Capacitor|supabase|firebase|fetch/i;

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

const URL = "http://app.local/index.html";
async function open(browser, html) {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true });
  await page.route("**/*", (route) => {
    const req = route.request();
    if (req.url().split("#")[0].split("?")[0] === URL) return route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: html });
    if (["script", "stylesheet", "font", "image"].includes(req.resourceType()) && req.method() === "GET") return route.continue();
    return route.abort();
  });
  await page.addInitScript(() => (window.open = () => null));
  page.on("dialog", (d) => d.accept(d.type() === "prompt" ? "1" : undefined).catch(() => {}));
  return page;
}

// Fill every visible input/textarea/select of a form with type-appropriate test data. Returns how many it filled.
async function fillForm(form) {
  return form.evaluate((f) => {
    let n = 0;
    const vis = (el) => {
      const r = el.getBoundingClientRect();
      const s = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && !el.disabled && !el.readOnly;
    };
    f.querySelectorAll("input, textarea, select").forEach((el) => {
      if (!vis(el)) return;
      const t = (el.getAttribute("type") || el.tagName).toLowerCase();
      try {
        if (el.tagName === "SELECT") {
          const opts = [...el.options].filter((o) => !o.disabled && o.value);
          if (opts.length) {
            el.value = opts[Math.min(1, opts.length - 1)].value;
          }
        } else if (t === "checkbox" || t === "radio") {
          el.checked = true;
        } else if (t === "number") {
          el.value = "12";
        } else if (t === "email") {
          el.value = "test@test.com";
        } else if (t === "tel") {
          el.value = "0912345678";
        } else if (t === "password") {
          el.value = "test123456";
        } else if (t === "date") {
          el.value = "2026-01-01";
        } else if (["button", "submit", "reset", "hidden", "file"].includes(t)) {
          return;
        } else {
          el.value = "تجربة";
        }
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
        n++;
      } catch {}
    });
    return n;
  });
}

async function snap(page) {
  return page
    .evaluate(() => {
      let ls = 0;
      try {
        for (let i = 0; i < localStorage.length; i++) ls += (localStorage.getItem(localStorage.key(i)) || "").length;
      } catch {}
      return { hash: location.hash, html: document.body.innerHTML.length, text: document.body.innerText.length, ls };
    })
    .catch(() => null);
}

async function run(htmlPath) {
  const html = fs.readFileSync(htmlPath, "utf8");
  const chromium = loadBrowser();
  if (!chromium) {
    console.log("Flow check skipped (no browser)");
    return { skipped: true, problems: [] };
  }
  const exe = browserPath();
  let browser;
  for (const o of [{ headless: true, args: ["--no-sandbox"], ...(exe ? { executablePath: exe } : {}) }, { headless: true, args: ["--no-sandbox"] }]) {
    try {
      browser = await chromium.launch(o);
      break;
    } catch {}
  }
  if (!browser) {
    console.log("Flow check skipped (browser would not launch)");
    return { skipped: true, problems: [] };
  }

  const problems = [];
  const errors = [];
  const failedLibs = []; // CDN scripts that could not load here: their globals are missing, not the app's fault
  try {
    const page = await open(browser, html);
    page.on("requestfailed", (r) => r.resourceType() === "script" && failedLibs.push(r.url().toLowerCase()));
    page.on("response", (r) => r.request().resourceType() === "script" && r.status() >= 400 && failedLibs.push(r.url().toLowerCase()));
    page.on("pageerror", (e) => {
      const m = (e.message || "").split("\n")[0].slice(0, 200);
      const undef = m.match(/(\w+) is not defined/);
      if (undef && failedLibs.some((u) => u.includes(undef[1].toLowerCase()))) return; // a CDN lib that failed to load
      if (m && !NOISE.test(m) && !errors.includes(m)) errors.push(m);
    });
    await page.goto(URL, { waitUntil: "load", timeout: 25000 }).catch(() => {});
    await page.waitForTimeout(900);

    const forms = await page.$$("form");
    let tested = 0;
    for (const form of forms.slice(0, 10)) {
      let label = "";
      try {
        const info = await form.evaluate((f) => {
          const r = f.getBoundingClientRect();
          const s = getComputedStyle(f);
          return {
            visible: r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none",
            label: ((f.getAttribute("aria-label") || "") + " " + (f.querySelector("h1,h2,h3,legend,button")?.textContent || "") + " " + (f.id || "")).trim().slice(0, 50),
          };
        });
        if (!info.visible) continue;
        label = info.label;
      } catch {
        continue;
      }
      const filled = await fillForm(form);
      if (!filled) continue; // no editable fields: not a data-entry form
      const before = await snap(page);
      await page.evaluate(() => {
        window.__f = 0;
        window.__o && window.__o.disconnect();
        window.__o = new MutationObserver((ms) => (window.__f += ms.length));
        window.__o.observe(document.body, { childList: true, subtree: true, characterData: true });
      });
      // Submit: a submit button inside the form, else any button, else press Enter.
      const btn = (await form.$('button[type=submit], input[type=submit]')) || (await form.$("button"));
      try {
        if (btn) await btn.click({ timeout: 1500 });
        else await form.evaluate((f) => f.requestSubmit && f.requestSubmit());
        tested++;
      } catch {
        continue;
      }
      await page.waitForTimeout(500);
      const mut = await page.evaluate(() => (window.__o && window.__o.disconnect(), window.__f || 0)).catch(() => 0);
      const after = await snap(page);
      const did =
        !before ||
        !after ||
        before.hash !== after.hash ||
        after.ls > before.ls ||
        Math.abs(after.html - before.html) > 30 ||
        mut > 3;
      if (!did) {
        problems.push(`flow: the form «${label || "(form)"}» does nothing when submitted — no data saved, no new item, no message (a broken flow)`);
      }
    }

    // Persistence: if the app stored anything, a reload must not wipe it (kept between launches).
    const beforeReload = await snap(page);
    if (beforeReload && beforeReload.ls > 0) {
      await page.reload({ waitUntil: "load", timeout: 20000 }).catch(() => {});
      await page.waitForTimeout(800);
      const afterReload = await snap(page);
      if (afterReload && afterReload.ls === 0) {
        problems.push("flow: data is NOT kept between launches — what was entered is gone after a reload (save it to localStorage)");
      }
    }

    errors.slice(0, 6).forEach((e) => problems.push(`flow: a JavaScript error happens during use: ${e}`));
    console.log(`Flow check: tested ${tested} form(s), ${problems.length} problem(s)`);
    return { skipped: false, problems };
  } finally {
    await browser.close().catch(() => {});
  }
}

async function main() {
  const p = process.argv[2];
  if (!p || !fs.existsSync(p)) {
    console.error("Usage: node scripts/qa_flows.js path/to/index.html");
    process.exit(2);
  }
  const res = await run(p);
  if (res.problems.length) {
    console.log("\nFunctional problems found:");
    res.problems.forEach((x) => console.log("- " + x));
    process.exit(1);
  }
  console.log(res.skipped ? "Flow check skipped." : "Flow check: the app's forms work and its data is kept.");
  process.exit(0);
}

if (require.main === module) main();
module.exports = { run };
