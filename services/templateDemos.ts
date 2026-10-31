// Ready-made interactive demos for the HTML templates, bundled in the app so their preview is instant
// and works offline. Each is a complete, self-contained page following the design brief.

function page(title: string, primary: string, accent: string, body: string, script: string) {
  return `<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>${title}</title><style>
:root{--p:${primary};--a:${accent};--bg:#f7f7fb;--s:#fff;--t:#16161d;--m:#6b6b7b;--b:#ececf3;--r:18px}
@media (prefers-color-scheme:dark){:root{--bg:#0e0f15;--s:#171923;--t:#f2f3f8;--m:#9a9cb0;--b:#262838}}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
body{font-family:system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif;background:var(--bg);color:var(--t);min-height:100vh;padding-bottom:84px}
header{position:sticky;top:0;z-index:5;background:var(--bg);padding:18px 18px 10px;display:flex;align-items:center;justify-content:space-between}
h1{font-size:22px;font-weight:800}h2{font-size:17px;font-weight:800;margin:18px 18px 10px}
.muted{color:var(--m);font-size:13px}
.card{background:var(--s);border:1px solid var(--b);border-radius:var(--r);padding:14px}
.btn{border:0;border-radius:14px;padding:12px 16px;font:inherit;font-weight:800;background:var(--p);color:#fff;cursor:pointer;transition:transform .15s}
.btn:active{transform:scale(.97)}.btn.ghost{background:transparent;color:var(--p);border:1.5px solid var(--p)}
.chips{display:flex;gap:8px;overflow-x:auto;padding:0 18px 4px;scrollbar-width:none}
.chip{flex:none;border:1px solid var(--b);background:var(--s);color:var(--m);border-radius:999px;padding:8px 14px;font-weight:700;font-size:13px}
.chip.on{background:var(--p);border-color:var(--p);color:#fff}
.icon{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;font-size:20px;background:color-mix(in srgb,var(--p) 14%,transparent)}
nav{position:fixed;bottom:0;left:0;right:0;background:var(--s);border-top:1px solid var(--b);display:flex;justify-content:space-around;padding:8px 0 12px}
nav button{background:none;border:0;color:var(--m);font:inherit;font-size:11px;font-weight:700;display:flex;flex-direction:column;align-items:center;gap:2px;min-width:64px}
nav button b{font-size:20px}nav button.on{color:var(--p)}
.toast{position:fixed;bottom:96px;left:50%;transform:translateX(-50%) translateY(20px);opacity:0;background:var(--t);color:var(--bg);padding:10px 16px;border-radius:12px;font-weight:700;transition:.25s;pointer-events:none}
.toast.show{opacity:1;transform:translateX(-50%)}
.empty{text-align:center;padding:40px 20px;color:var(--m)}.empty div{font-size:40px;margin-bottom:8px}
.screen{display:none;animation:in .25s ease}.screen.on{display:block}@keyframes in{from{opacity:0;transform:translateY(6px)}}
${""}</style></head><body>${body}<div class="toast" id="toast"></div><script>
const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
function toast(t){const e=$("#toast");e.textContent=t;e.classList.add("show");clearTimeout(e._t);e._t=setTimeout(()=>e.classList.remove("show"),1600)}
function show(id){$$(".screen").forEach(s=>s.classList.toggle("on",s.id===id));$$("nav button").forEach(b=>b.classList.toggle("on",b.dataset.go===id));scrollTo(0,0)}
$$("nav button").forEach(b=>b.onclick=()=>show(b.dataset.go));
const store={get:(k,d)=>{try{return JSON.parse(localStorage.getItem(k))??d}catch{return d}},set:(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v))}catch{}}};
const money=n=>n.toLocaleString("ar-EG")+" ج";
${script}
</script></body></html>`;
}

const store = page(
  "متجر الأناقة",
  "#E11D74",
  "#F59E0B",
  `<header><div><h1>متجر الأناقة</h1><div class="muted">أحدث صيحات الموسم</div></div><div class="icon">🛍️</div></header>
<section class="screen on" id="home">
 <div style="margin:0 18px 6px;border-radius:22px;padding:20px;color:#fff;background:linear-gradient(135deg,var(--p),var(--a))">
  <div style="font-size:13px;opacity:.9">عرض الأسبوع</div><div style="font-size:24px;font-weight:900;margin:4px 0">خصم ٣٠٪ على الجديد</div>
  <button class="btn" style="background:#fff;color:var(--p);margin-top:8px" onclick="filter('all')">تسوّق الآن</button></div>
 <h2>التصنيفات</h2><div class="chips" id="cats"></div>
 <h2>منتجات مميزة</h2><div id="grid" style="display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:0 18px"></div>
</section>
<section class="screen" id="fav"><h2>المفضلة</h2><div id="favList" style="padding:0 18px;display:grid;gap:10px"></div></section>
<section class="screen" id="cart"><h2>سلة المشتريات</h2><div id="cartList" style="padding:0 18px;display:grid;gap:10px"></div>
 <div class="card" style="margin:14px 18px"><div style="display:flex;justify-content:space-between;font-weight:800"><span>الإجمالي</span><span id="total"></span></div>
 <button class="btn" style="width:100%;margin-top:12px" onclick="checkout()">إتمام الطلب</button></div></section>
<nav><button data-go="home" class="on"><b>🏠</b>الرئيسية</button><button data-go="fav"><b>♡</b>المفضلة</button><button data-go="cart"><b>🛒</b>السلة <span id="badge"></span></button></nav>`,
  `const P=[{id:1,n:"قميص كتان",c:"رجالي",p:450,e:"👔"},{id:2,n:"فستان صيفي",c:"نسائي",p:780,e:"👗"},{id:3,n:"حذاء رياضي",c:"رجالي",p:990,e:"👟"},{id:4,n:"حقيبة يد",c:"نسائي",p:620,e:"👜"},{id:5,n:"تيشيرت أطفال",c:"أطفال",p:210,e:"👕"},{id:6,n:"نظارة شمسية",c:"إكسسوارات",p:340,e:"🕶️"}];
let cat="all",fav=store.get("fav",[]),cart=store.get("cart",{});
function filter(c){cat=c;render();show("home")}
function render(){
 $("#cats").innerHTML=["all","رجالي","نسائي","أطفال","إكسسوارات"].map(c=>'<button class="chip '+(c===cat?"on":"")+'" onclick="filter(\\''+c+'\\')">'+(c==="all"?"الكل":c)+'</button>').join("");
 $("#grid").innerHTML=P.filter(p=>cat==="all"||p.c===cat).map(p=>'<div class="card" style="padding:10px"><div style="height:110px;border-radius:14px;display:grid;place-items:center;font-size:52px;background:var(--bg)">'+p.e+'</div><div style="font-weight:800;margin:8px 0 2px">'+p.n+'</div><div class="muted">'+p.c+'</div><div style="display:flex;justify-content:space-between;align-items:center;margin-top:8px"><b style="color:var(--p)">'+money(p.p)+'</b><span><button class="chip" onclick="toggleFav('+p.id+')">'+(fav.includes(p.id)?"❤️":"♡")+'</button> <button class="chip on" onclick="add('+p.id+')">+</button></span></div></div>').join("");
 const fl=P.filter(p=>fav.includes(p.id));
 $("#favList").innerHTML=fl.length?fl.map(p=>'<div class="card" style="display:flex;gap:12px;align-items:center"><span style="font-size:30px">'+p.e+'</span><div style="flex:1"><b>'+p.n+'</b><div class="muted">'+money(p.p)+'</div></div><button class="btn" onclick="add('+p.id+')">أضف</button></div>').join(""):'<div class="empty"><div>💝</div>ما في مفضلة لسه</div>';
 const items=Object.entries(cart).filter(([,q])=>q>0);let t=0;
 $("#cartList").innerHTML=items.length?items.map(([id,q])=>{const p=P.find(x=>x.id==id);t+=p.p*q;return '<div class="card" style="display:flex;gap:12px;align-items:center"><span style="font-size:30px">'+p.e+'</span><div style="flex:1"><b>'+p.n+'</b><div class="muted">'+money(p.p)+'</div></div><button class="chip" onclick="qty('+id+',-1)">−</button><b>'+q+'</b><button class="chip" onclick="qty('+id+',1)">+</button></div>'}).join(""):'<div class="empty"><div>🛒</div>السلة فاضية</div>';
 $("#total").textContent=money(t);const n=items.reduce((a,[,q])=>a+q,0);$("#badge").textContent=n?"("+n+")":"";
 store.set("fav",fav);store.set("cart",cart)}
function toggleFav(id){fav=fav.includes(id)?fav.filter(x=>x!==id):[...fav,id];render()}
function add(id){cart[id]=(cart[id]||0)+1;render();toast("أُضيف للسلة ✓")}
function qty(id,d){cart[id]=Math.max(0,(cart[id]||0)+d);render()}
function checkout(){if(!Object.values(cart).some(q=>q)){toast("السلة فاضية");return}cart={};render();toast("تم استلام طلبك 🎉")}
render();`
);

const restaurant = page(
  "مطعم البيت",
  "#EA580C",
  "#16A34A",
  `<header><div><h1>مطعم البيت</h1><div class="muted">مفتوح الآن · توصيل ٣٠ دقيقة</div></div><div class="icon">🍽️</div></header>
<div class="chips" id="sections"></div><div id="menu" style="padding:12px 18px;display:grid;gap:10px"></div>
<div id="bar" class="card" style="position:fixed;bottom:16px;left:16px;right:16px;display:none;align-items:center;justify-content:space-between;box-shadow:0 10px 30px #0003">
 <div><b id="count"></b><div class="muted" id="sum"></div></div><button class="btn" onclick="openOrder()">عرض الطلب</button></div>
<div id="sheet" style="position:fixed;inset:0;background:#0007;display:none;align-items:flex-end" onclick="if(event.target===this)this.style.display='none'">
 <div class="card" style="width:100%;border-radius:24px 24px 0 0;padding:18px;max-height:80vh;overflow:auto"><h1 style="font-size:19px">طلبك</h1><div id="lines" style="margin:12px 0;display:grid;gap:8px"></div>
 <div class="chips" style="padding:0;margin-bottom:12px"><button class="chip on" id="d1" onclick="mode('توصيل')">🛵 توصيل</button><button class="chip" id="d2" onclick="mode('استلام')">🏃 استلام</button></div>
 <button class="btn" style="width:100%;background:#25D366" onclick="send()">إرسال الطلب عبر واتساب</button></div></div>`,
  `const M={"مقبلات":[["حمص بالطحينة",45,"🥙"],["سلطة فتوش",40,"🥗"]],"أطباق رئيسية":[["مشويات مشكلة",180,"🍢"],["كبسة دجاج",120,"🍛"],["برجر لحم",95,"🍔"]],"مشروبات":[["عصير مانجو",35,"🥭"],["شاي بالنعناع",15,"🍵"]],"حلويات":[["كنافة",60,"🍮"],["بسبوسة",40,"🍰"]]};
let sec="أطباق رئيسية",order={},how="توصيل";
function draw(){$("#sections").innerHTML=Object.keys(M).map(s=>'<button class="chip '+(s===sec?"on":"")+'" onclick="sec=\\''+s+'\\';draw()">'+s+'</button>').join("");
 $("#menu").innerHTML=M[sec].map(([n,p,e])=>'<div class="card" style="display:flex;gap:12px;align-items:center"><div style="width:64px;height:64px;border-radius:16px;background:var(--bg);display:grid;place-items:center;font-size:34px">'+e+'</div><div style="flex:1"><b>'+n+'</b><div class="muted">طازج يومياً</div><b style="color:var(--p)">'+money(p)+'</b></div><button class="btn" onclick="add(\\''+n+'\\','+p+')">'+(order[n]?"×"+order[n].q:"أضف")+'</button></div>').join("");
 const q=Object.values(order).reduce((a,o)=>a+o.q,0),s=Object.values(order).reduce((a,o)=>a+o.q*o.p,0);
 $("#bar").style.display=q?"flex":"none";$("#count").textContent=q+" صنف";$("#sum").textContent=money(s)}
function add(n,p){order[n]=order[n]||{q:0,p};order[n].q++;draw();toast("أُضيف "+n)}
function openOrder(){$("#lines").innerHTML=Object.entries(order).map(([n,o])=>'<div style="display:flex;justify-content:space-between"><span>'+n+' ×'+o.q+'</span><b>'+money(o.q*o.p)+'</b></div>').join("");$("#sheet").style.display="flex"}
function mode(m){how=m;$("#d1").classList.toggle("on",m==="توصيل");$("#d2").classList.toggle("on",m==="استلام")}
function send(){$("#sheet").style.display="none";order={};draw();toast("تم إرسال طلب "+how+" ✓")}
draw();`
);

const booking = page(
  "صالون لمسة",
  "#7C3AED",
  "#EC4899",
  `<header><div><h1>صالون لمسة</h1><div class="muted">احجز موعدك في أقل من دقيقة</div></div><div class="icon">💇</div></header>
<section class="screen on" id="book">
 <h2>١. اختر الخدمة</h2><div id="services" style="padding:0 18px;display:grid;gap:10px"></div>
 <h2>٢. اختر اليوم</h2><div class="chips" id="days"></div>
 <h2>٣. اختر الوقت</h2><div id="times" style="padding:0 18px;display:grid;grid-template-columns:repeat(4,1fr);gap:8px"></div>
 <div style="padding:18px;display:grid;gap:10px"><input id="nm" placeholder="الاسم" class="card" style="font:inherit;color:var(--t)"><input id="ph" placeholder="رقم الهاتف" inputmode="tel" class="card" style="font:inherit;color:var(--t)">
 <button class="btn" onclick="confirmB()">تأكيد الحجز</button></div></section>
<section class="screen" id="mine"><h2>حجوزاتي</h2><div id="list" style="padding:0 18px;display:grid;gap:10px"></div></section>
<nav><button data-go="book" class="on"><b>📅</b>حجز جديد</button><button data-go="mine"><b>🗂️</b>حجوزاتي</button></nav>`,
  `const S=[["قص وتصفيف",150,"٤٥ دقيقة","✂️"],["صبغة شعر",400,"ساعتان","🎨"],["عناية بالبشرة",250,"ساعة","🧴"]];
let sv=0,day=0,time="",mine=store.get("bookings",[]);
const D=[...Array(7)].map((_,i)=>{const d=new Date();d.setDate(d.getDate()+i);return d});
function draw(){$("#services").innerHTML=S.map((s,i)=>'<div class="card" onclick="sv='+i+';draw()" style="display:flex;gap:12px;align-items:center;'+(i===sv?"border-color:var(--p);box-shadow:0 0 0 2px var(--p) inset":"")+'"><div class="icon">'+s[3]+'</div><div style="flex:1"><b>'+s[0]+'</b><div class="muted">'+s[2]+'</div></div><b style="color:var(--p)">'+money(s[1])+'</b></div>').join("");
 $("#days").innerHTML=D.map((d,i)=>'<button class="chip '+(i===day?"on":"")+'" onclick="day='+i+';time=\\'\\';draw()">'+d.toLocaleDateString("ar-EG",{weekday:"short",day:"numeric"})+'</button>').join("");
 $("#times").innerHTML=["10:00","11:00","12:00","2:00","3:00","4:00","5:00","6:00"].map((t,i)=>{const busy=(i+day)%3===0;return '<button class="chip '+(t===time?"on":"")+'" '+(busy?'disabled style="opacity:.35;text-decoration:line-through"':'onclick="time=\\''+t+'\\';draw()"')+'>'+t+'</button>'}).join("");
 $("#list").innerHTML=mine.length?mine.map((b,i)=>'<div class="card"><b>'+b.s+'</b><div class="muted">'+b.d+' · '+b.t+' · '+b.n+'</div><button class="btn ghost" style="margin-top:10px" onclick="cancelB('+i+')">إلغاء الحجز</button></div>').join(""):'<div class="empty"><div>📭</div>ما عندك حجوزات</div>'}
function confirmB(){const n=$("#nm").value.trim(),p=$("#ph").value.trim();if(!time){toast("اختر الوقت");return}if(!n||p.length<8){toast("اكتب الاسم ورقم صحيح");return}
 mine.unshift({s:S[sv][0],d:D[day].toLocaleDateString("ar-EG",{weekday:"long",day:"numeric",month:"long"}),t:time,n});store.set("bookings",mine);time="";draw();toast("تم الحجز ✓");show("mine")}
function cancelB(i){if(confirm("إلغاء هذا الحجز؟")){mine.splice(i,1);store.set("bookings",mine);draw();toast("تم الإلغاء")}}
draw();`
);

const portfolio = page(
  "سارة · مصممة",
  "#0EA5E9",
  "#8B5CF6",
  `<div style="padding:26px 18px 18px;text-align:center;background:linear-gradient(160deg,var(--p),var(--a));color:#fff;border-radius:0 0 30px 30px">
 <div style="width:92px;height:92px;border-radius:50%;margin:0 auto 10px;background:#fff3;display:grid;place-items:center;font-size:44px;border:3px solid #fff8">👩‍🎨</div>
 <h1>سارة أحمد</h1><div style="opacity:.9">مصممة واجهات وتجربة مستخدم · ٦ سنوات خبرة</div>
 <div style="display:flex;gap:8px;justify-content:center;margin-top:14px"><button class="btn" style="background:#fff;color:var(--p)" onclick="toast('فتح واتساب…')">واتساب</button><button class="btn" style="background:#fff2" onclick="toast('فتح البريد…')">البريد</button></div></div>
<h2>المهارات</h2><div id="skills" style="padding:0 18px;display:grid;gap:10px"></div>
<h2>الأعمال</h2><div class="chips" id="kinds"></div><div id="works" style="padding:12px 18px;display:grid;grid-template-columns:1fr 1fr;gap:10px"></div>
<h2>الخبرات</h2><div id="xp" style="padding:0 18px 30px"></div>`,
  `const SK=[["تصميم واجهات",95],["تجربة المستخدم",90],["Figma",92],["هوية بصرية",80]];
const W=[["تطبيق بنك","تطبيقات","🏦"],["متجر عطور","مواقع","🌸"],["هوية مقهى","هوية","☕"],["تطبيق لياقة","تطبيقات","💪"],["منصة تعليم","مواقع","🎓"],["شعار عيادة","هوية","🩺"]];
const X=[["٢٠٢٣ - الآن","قائدة فريق التصميم","شركة رقمية"],["٢٠٢٠ - ٢٠٢٣","مصممة واجهات","وكالة إبداعية"],["٢٠١٩","متدربة","استوديو تصميم"]];
let k="الكل";
$("#skills").innerHTML=SK.map(([n,v])=>'<div><div style="display:flex;justify-content:space-between;font-weight:700;margin-bottom:6px"><span>'+n+'</span><span class="muted">'+v+'٪</span></div><div style="height:8px;border-radius:9px;background:var(--b)"><div style="height:100%;width:0;border-radius:9px;background:linear-gradient(90deg,var(--a),var(--p));transition:width 1s" data-w="'+v+'"></div></div></div>').join("");
setTimeout(()=>$$("[data-w]").forEach(e=>e.style.width=e.dataset.w+"%"),100);
function draw(){$("#kinds").innerHTML=["الكل","تطبيقات","مواقع","هوية"].map(x=>'<button class="chip '+(x===k?"on":"")+'" onclick="k=\\''+x+'\\';draw()">'+x+'</button>').join("");
 $("#works").innerHTML=W.filter(w=>k==="الكل"||w[1]===k).map(w=>'<div class="card" style="padding:0;overflow:hidden" onclick="toast(\\''+w[0]+'\\')"><div style="height:100px;display:grid;place-items:center;font-size:44px;background:linear-gradient(135deg,color-mix(in srgb,var(--p) 25%,transparent),color-mix(in srgb,var(--a) 25%,transparent))">'+w[2]+'</div><div style="padding:10px"><b>'+w[0]+'</b><div class="muted">'+w[1]+'</div></div></div>').join("")}
$("#xp").innerHTML=X.map(([y,r,c])=>'<div style="display:flex;gap:12px"><div style="display:flex;flex-direction:column;align-items:center"><div style="width:12px;height:12px;border-radius:50%;background:var(--p);margin-top:4px"></div><div style="flex:1;width:2px;background:var(--b)"></div></div><div style="padding-bottom:16px"><b>'+r+'</b><div class="muted">'+c+' · '+y+'</div></div></div>').join("");
draw();`
);

export const TEMPLATE_DEMOS: Record<string, string> = { store, menu: restaurant, booking, portfolio };
