// The owner decides sign-in in the description. Same rules in scripts/pair.py.
//  - Whether there is email sign-in: words like «تسجيل دخول» / «دخول بالبريد» / «إنشاء حساب» / login turn it on;
//    «بدون تسجيل دخول» or saying nothing means no sign-in.
//  - How: «كلمة مرور» / password -> a password; «رمز تحقق» / «كود» / OTP -> a 6-digit code from the email;
//    both -> password + a code to confirm the email; neither -> a code (no password).
// For a pair, the owner then picks which app gets it (customer, admin or both); that choice is written in the
// description as "LOGIN: customer=<mode> admin=<mode>" and wins over the words.
export type LoginMode = "none" | "code" | "password" | "password_code";
export type PairLogin = { customer: LoginMode; admin: LoginMode };

const NO = /(بدون|بلا|من غير|ما في|مافي|ما يحتاج|لا يحتاج|مش محتاج|ما فيه|without|no)\s+(أي\s+|اي\s+)?(تسجيل|login|log in|sign)/i;
const YES =
  /تسجيل\s*(ال)?دخول|دخول\s*(بال)?(بريد|ايميل|إيميل)|login|log ?in|sign ?in|sign ?up|إنشاء حساب|انشاء حساب|حساب جديد|كلم[ةه]\s*(ال)?(مرور|سر)|password|رمز\s*(ال)?تحقق|\botp\b/i;
const PASSWORD = /كلم[ةه]\s*(ال)?(مرور|سر)|باسورد|password/i;
const CODE = /(رمز|كود)\s*(ال)?(تحقق|تأكيد|دخول)|(رمز|كود)\s*من\s*(6|٦|ستة|سته)|(رمز|كود)\s*(يوصل|يجي|بالبريد|على البريد)|\botp\b|verification code|one.time code/i;

export const LOGIN_LABELS: Record<LoginMode, string> = {
  none: "بدون تسجيل دخول",
  code: "البريد + رمز من 6 أرقام يوصل على البريد",
  password: "البريد + كلمة مرور",
  password_code: "البريد + كلمة مرور، ورمز من 6 أرقام لتأكيد البريد",
};

/** The sign-in the description asks for (before the owner picks the apps). */
export function loginFromText(text: string): LoginMode {
  const t = String(text);
  if (NO.test(t) || !YES.test(t)) return "none";
  const pwd = PASSWORD.test(t);
  const code = CODE.test(t);
  return pwd && code ? "password_code" : pwd ? "password" : "code";
}

export function emailLoginWanted(text: string): boolean {
  return loginFromText(text) !== "none";
}

export function loginLine(l: PairLogin) {
  return `LOGIN: customer=${l.customer} admin=${l.admin}`;
}
