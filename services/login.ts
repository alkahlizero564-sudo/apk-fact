// The owner decides in the description whether the app has email sign-in. Same rule in scripts/pair.py.
// An explicit "LOGIN: email|none" line wins; otherwise words like «تسجيل دخول» / «إنشاء حساب» / login turn it
// on, and «بدون تسجيل دخول» turns it off. Nothing said = no sign-in.
const NO = /(بدون|بلا|من غير|ما في|مافي|ما يحتاج|لا يحتاج|مش محتاج|ما فيه|without|no)\s+(أي\s+|اي\s+)?(تسجيل|login|log in|sign)/i;
const YES =
  /تسجيل\s*(ال)?دخول|دخول\s*(بال)?(بريد|ايميل|إيميل)|login|log ?in|sign ?in|sign ?up|إنشاء حساب|انشاء حساب|حساب جديد|كلمة\s*(ال)?(مرور|سر)|password|رمز\s*(ال)?تحقق|\botp\b/i;

export function emailLoginWanted(text: string): boolean {
  const m = String(text).match(/^LOGIN:\s*(email|none)\s*$/m);
  if (m) return m[1] === "email";
  if (NO.test(text)) return false;
  return YES.test(text);
}
