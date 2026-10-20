// services/link.ts
// نسخة مؤقتة: تتوافق مع استدعاء CreateScreen وتعرض رسالة واضحة بدل الانهيار

export type LinkResult = {
  summary?: string;
  tables: string[];
};

export async function linkAppsViaSupabase(
  appA: string,
  appB: string,
  log: (line: string) => void
): Promise<LinkResult> {
  log(`⚠️ ميزة الربط بين ${appA} و${appB} لم تُبرمج بعد.`);
  throw new Error("ميزة الربط عبر Supabase غير مفعّلة بعد");
    }
