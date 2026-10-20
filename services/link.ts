// services/link.ts
// نسخة آمنة مؤقتة: تسمح بنجاح البناء ولا توقف التطبيق عند الاستدعاء

export type LinkResult = {
  ok: boolean;
  message: string;
  data?: any;
};

export async function linkAppsViaSupabase(...args: any[]): Promise<LinkResult> {
  console.warn("linkAppsViaSupabase: لم يتم تنفيذها بعد", args);
  return {
    ok: false,
    message: "ميزة الربط عبر Supabase غير مفعّلة بعد",
  };
}
