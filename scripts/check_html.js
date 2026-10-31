// Fast check for a generated HTML app: finds JavaScript syntax errors in its inline
// <script> blocks. These don't fail the APK build, but they leave the app blank or broken.
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
  return problems;
}

module.exports = { checkHtml };

if (require.main === module) {
  const problems = checkHtml(fs.readFileSync(process.argv[2], "utf8"));
  if (problems.length) {
    console.log("error: HTML check failed:");
    for (const p of problems) console.log(`error: ${p}`);
    process.exit(1);
  }
  console.log("HTML check passed");
}
