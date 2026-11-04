// The owner decides sign-in in the description. Same rules in scripts/pair.py.
//  - Whether there is email sign-in: words like «تسجيل دخول» / «دخول بالبريد» / «إنشاء حساب» / login turn it on;
//    «بدون تسجيل دخول» or saying nothing means no sign-in.
//  - How: «كلمة مرور» / password -> a password; «رمز تحقق» / «كود» / OTP -> a 6-digit code from the email;
//    both -> password + a code to confirm the email; neither -> a code (no password).
// For a pair, the owner then picks which app gets it (customer, admin or both); that choice is written in the
// description as "LOGIN: customer=<mode> admin=<mode>" and wins over the words.
// The three ways the owner picks in the sign-in sheet (the others are kept for apps made before):
//  phone_password   الاسم + رقم الهاتف + كلمة مرور (no email; the account is made by the pair's <p>-auth function)
//  phone_email_code الاسم + رقم الهاتف + البريد + رمز تأكيد للبريد + كلمة مرور
//  email_password   الاسم + البريد + كلمة مرور (no code)
export type LoginMode =
  | "none"
  | "phone_password"
  | "phone_email_code"
  | "email_password"
  | "code"
  | "password"
  | "password_code";
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
  phone_password: "الاسم + رقم الهاتف + كلمة مرور (بدون بريد)",
  phone_email_code: "الاسم + رقم الهاتف + البريد + رمز تأكيد للبريد + كلمة مرور",
  email_password: "الاسم + البريد + كلمة مرور",
};

/** What the sign-in sheet offers. */
export const LOGIN_CHOICES: LoginMode[] = ["phone_password", "phone_email_code", "email_password", "none"];

/** Sign-in that uses an email (the admin app then makes admins from the emails the owner writes). */
export const usesEmail = (m: LoginMode) => m !== "none" && m !== "phone_password";

/** Sign-in that sends emails (needs working SMTP). */
export const sendsEmail = (m: LoginMode) => m === "code" || m === "password_code" || m === "phone_email_code";

/** The choice the sheet starts with, from the description: none when it asks for no sign-in, else unset. */
export function suggestedChoice(text: string): LoginMode | "" {
  const t = String(text);
  if (loginFromText(t) === "none") return "none";
  const phone = /(رقم\s*(ال)?(هاتف|جوال|موبايل|تلفون)|phone)/i.test(t);
  const code = CODE.test(t);
  if (phone && code) return "phone_email_code";
  if (phone) return "phone_password";
  if (PASSWORD.test(t) && !code) return "email_password";
  return "";
}

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
