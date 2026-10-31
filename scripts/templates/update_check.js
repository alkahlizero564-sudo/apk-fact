// In-app updates (added by APK Fact at build time; not part of the app's own code).
(function () {
  var VERSION = __APKFACT_VERSION__;
  var MANIFEST = "__APKFACT_MANIFEST__";
  var shown = false;
  var later = 0;

  function show(m) {
    if (shown || document.getElementById("apkfact-update")) return;
    shown = true;
    var css =
      "#apkfact-update{position:fixed;left:12px;right:12px;bottom:max(16px,env(safe-area-inset-bottom));z-index:2147483647;" +
      "direction:rtl;font-family:system-ui,-apple-system,'Segoe UI',Tahoma,sans-serif;background:#111827;color:#fff;" +
      "border-radius:18px;padding:14px 16px;box-shadow:0 12px 40px rgba(0,0,0,.35);display:flex;gap:12px;align-items:center;" +
      "animation:apkfactIn .35s ease-out}" +
      "@keyframes apkfactIn{from{transform:translateY(30px);opacity:0}to{transform:none;opacity:1}}" +
      "#apkfact-update .t{font-weight:800;font-size:15px;margin:0 0 2px}" +
      "#apkfact-update .n{font-size:13px;opacity:.8;margin:0;max-height:3.6em;overflow:hidden}" +
      "#apkfact-update button{border:0;border-radius:999px;font:inherit;font-weight:800;padding:10px 16px;cursor:pointer}" +
      "#apkfact-update .go{background:#6E4BFF;color:#fff}#apkfact-update .x{background:transparent;color:#cbd5e1;padding:10px 8px}";
    var style = document.createElement("style");
    style.textContent = css;
    document.head.appendChild(style);
    var box = document.createElement("div");
    box.id = "apkfact-update";
    box.setAttribute("role", "alertdialog");
    var text = document.createElement("div");
    text.style.flex = "1";
    var t = document.createElement("p");
    t.className = "t";
    t.textContent = "تحديث جديد متوفر (" + (m.versionName || m.version) + ")";
    var n = document.createElement("p");
    n.className = "n";
    n.textContent = m.notes || "اضغط تحديث لتنزيل النسخة الجديدة وتثبيتها.";
    text.appendChild(t);
    text.appendChild(n);
    var go = document.createElement("button");
    go.className = "go";
    go.textContent = "تحديث";
    go.onclick = function () {
      go.textContent = "جارٍ التنزيل…";
      window.location.href = m.apk; // opens the browser, which downloads the APK and offers to install it
    };
    var x = document.createElement("button");
    x.className = "x";
    x.textContent = "لاحقاً";
    x.onclick = function () {
      box.remove();
      shown = false;
      later = Date.now();
    };
    box.appendChild(text);
    box.appendChild(go);
    box.appendChild(x);
    document.body.appendChild(box);
  }

  function check() {
    if (shown || Date.now() - later < 30 * 60 * 1000) return;
    fetch(MANIFEST + "?t=" + Date.now(), { cache: "no-store" })
      .then(function (r) {
        return r.ok ? r.json() : null;
      })
      .then(function (m) {
        if (m && typeof m.version === "number" && m.version > VERSION && m.apk) show(m);
      })
      .catch(function () {});
  }

  window.APKFACT_VERSION = VERSION;
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", check);
  else check();
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "visible") check();
  });
})();
