// services/link.ts
import { REPO } from "./config";
import { getFileText, pushFile } from "./github";
import { generateApp, askText } from "./generate2";

export type LinkResult = {
  summary: string;
  tables: string[];
  sql: string | null;
};

const SQL_SYSTEM =
  "You are a database designer for Supabase (PostgreSQL). " +
  "Reply with ONLY the complete SQL inside a single ```sql code block. No explanations. " +
  "Use CREATE TABLE IF NOT EXISTS, enable row level security on every table, " +
  "and add policies that allow the anon role to select, insert and update.";

function extractSql(text: string): string {
  const m = text.match(/```(?:sql)?\s*([\s\S]*?)```/i);
  const sql = (m ? m[1] : text).trim();
  if (!/create\s+table/i.test(sql)) {
    throw new Error("النموذج ما رجّع SQL صالح. جرّب مرة ثانية.");
  }
  return sql;
}

function extractTables(sql: string): string[] {
  const re = /create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?"?([a-z0-9_]+)"?/gi;
  const out: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(sql)) !== null) {
    if (!out.includes(m[1])) out.push(m[1]);
  }
  return out;
}

function updatePrompt(me: string, other: string, sql: string) {
  return (
    `Link this app (${me}) with the app "${other}" so both share data through ONE Supabase project.\n` +
    `Use EXACTLY this database schema (do not change it):\n${sql}\n\n` +
    `Update the app to read and write these tables using fetch() against the Supabase REST API. ` +
    `Put SUPABASE_URL and SUPABASE_ANON_KEY as JS constants at the top of the file ` +
    `(keep their existing values if already set). Keep every existing feature working.`
  );
}

export async function linkAppsViaSupabase(
  appA: string,
  appB: string,
  log: (line: string) => void
): Promise<LinkResult> {
  log("⏳ بقرأ التطبيقين من GitHub...");
  const htmlA = await getFileText(REPO, `apps/${appA}/index.html`);
  const htmlB = await getFileText(REPO, `apps/${appB}/index.html`);
  if (!htmlA) throw new Error(`التطبيق ${appA} غير موجود.`);
  if (!htmlB) throw new Error(`التطبيق ${appB} غير موجود.`);

  // 1) تصميم الجداول المشتركة
  log("⏳ بيتم تصميم الجداول المشتركة...");
  const sqlPrompt =
    `Design ONE shared Supabase schema that fits both apps below.\n\n` +
    `--- app "${appA}" ---\n${htmlA.slice(0, 40000)}\n\n` +
    `--- app "${appB}" ---\n${htmlB.slice(0, 40000)}`;
  const sqlRes = await askText(SQL_SYSTEM, sqlPrompt, log);
  const sql = extractSql(sqlRes.text);
  const tables = extractTables(sql);
  log(`✅ الجداول: ${tables.join("، ")}`);

  // 2) تعديل التطبيق الأول
  log(`⏳ بيتم تعديل ${appA}...`);
  const resA = await generateApp(updatePrompt(appA, appB, sql), htmlA, log);

  // 3) تعديل التطبيق الثاني
  log(`⏳ بيتم تعديل ${appB}...`);
  const resB = await generateApp(updatePrompt(appB, appA, sql), htmlB, log);

  // 4) الرفع
  log("⏳ بيترفع كل شيء على GitHub...");
  await pushFile(REPO, `apps/${appA}/index.html`, resA.html + "\n", `Link: ${appA}`);
  await pushFile(REPO, `apps/${appB}/index.html`, resB.html + "\n", `Link: ${appB}`);

  const sqlPath = `supabase/link-${appA}-${appB}.sql`;
  await pushFile(REPO, sqlPath, sql + "\n", `SQL: ${appA} + ${appB}`);

  log(`📄 ملف SQL: ${sqlPath}`);
  log("👉 افتحه على GitHub وانسخه والصقه في Supabase ← SQL Editor ← Run.");
  log("👉 ثم ضع SUPABASE_URL و SUPABASE_ANON_KEY في أعلى كود التطبيقين.");

  return {
    summary: `تم ربط ${appA} و${appB} عبر ${tables.length} جداول`,
    tables,
    sql,
  };
                                }
