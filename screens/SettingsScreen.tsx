import React, { useCallback, useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable, Linking, Alert, ScrollView } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as SecureStore from "expo-secure-store";
import { Ionicons } from "../components/icons";
import {
  Card,
  ListRow,
  Sheet,
  Button,
  KeyInput,
  Field,
  StatusLine,
  Status,
  Banner,
  IconName,
  Timeline,
  useSteps,
} from "../components/ui";
import { setupVault, vaultStatus, listVaultApps, VaultStatus, VaultApp } from "../services/vault";
import { testGithubConnection } from "../services/github";
import { testSupabaseConnection, testEmailCode, EmailCodeTest, applySmtpSettings } from "../services/supabase";
import { testGeminiConnection, testClaudeConnection, listGeminiModels, GeminiModel } from "../services/ai";
import { buildTool, listToolBuilds, ToolRun } from "../services/appActions";
import { REPO } from "../services/config";
import DbProjectsPanel from "../components/DbProjectsPanel";
import { privacyStatus, setupUpdatesRepo, makeRepoPrivate, appsWithInstalls, PrivacyStatus, monthMinutes, FREE_MINUTES, BILLING_URL } from "../services/privacy";
import { parseServiceAccount } from "../services/pair";
import { colors, space, radius, type } from "../theme";

type FieldDef = { key: string; label: string; placeholder?: string; secret?: boolean };
type Service = {
  id: string;
  title: string;
  icon: IconName;
  tint: string;
  hint?: string;
  fields: FieldDef[];
  test: () => Promise<string>;
};

const GEMINI_MODEL_KEY = "GEMINI_MODEL";
const OFF = colors.glassBorder;

const SERVICES: Service[] = [
  {
    id: "github",
    title: "GitHub",
    icon: "logo-github",
    tint: colors.softText,
    hint: "مكان حفظ تطبيقاتك وبنائها.",
    fields: [
      { key: "GITHUB_TOKEN", label: "Personal Access Token", placeholder: "ghp_...", secret: true },
      { key: "GITHUB_REPO_1", label: "مستودع التطبيق الأول", placeholder: "username/app-one" },
      { key: "GITHUB_REPO_2", label: "مستودع التطبيق الثاني", placeholder: "username/app-two" },
    ],
    test: async () => `متصل باسم: ${(await testGithubConnection()).login}`,
  },
  {
    id: "gemini",
    title: "Gemini",
    icon: "sparkles",
    tint: "#60A5FA",
    hint: "الذكاء الاصطناعي اللي يكتب ويصلّح الكود. تقدر تضيف لحد ثلاثة مفاتيح.",
    fields: [
      { key: "GEMINI_API_KEY", label: "المفتاح الأول", placeholder: "AIza...", secret: true },
      { key: "GEMINI_API_KEY_2", label: "المفتاح الثاني", placeholder: "AIza...", secret: true },
      { key: "GEMINI_API_KEY_3", label: "المفتاح الثالث", placeholder: "AIza...", secret: true },
    ],
    test: async () => `متصل، ${(await testGeminiConnection()).modelCount} نموذج متاح`,
  },
  {
    id: "supabase",
    title: "Supabase",
    icon: "server-outline",
    tint: "#34D399",
    hint:
      "قاعدة البيانات وتسجيل الدخول للتطبيقين المتصلين. بريد الرموز (SMTP) اختياري، لكن بدونه Supabase يرسل رموز " +
      "قليلة في الساعة ولعناوين فريقك فقط (مثلاً Gmail: smtp.gmail.com، المنفذ 587، وكلمة مرور تطبيق).",
    fields: [
      { key: "SUPABASE_ACCESS_TOKEN", label: "Personal Access Token (من الحساب)", placeholder: "sbp_...", secret: true },
      { key: "SUPABASE_PROJECT_REF", label: "Project Ref (من رابط المشروع)", placeholder: "abcdefghijklmnop" },
      {
        key: "SUPABASE_PUBLISHABLE_KEY",
        label: "Publishable key (اختياري، من API Keys)",
        placeholder: "sb_publishable_... أو مفتاح anon",
        secret: true,
      },
      { key: "SMTP_HOST", label: "SMTP: الخادم (اختياري)", placeholder: "smtp.gmail.com" },
      { key: "SMTP_PORT", label: "SMTP: المنفذ", placeholder: "587" },
      { key: "SMTP_USER", label: "SMTP: المستخدم", placeholder: "you@gmail.com" },
      { key: "SMTP_PASS", label: "SMTP: كلمة المرور", placeholder: "••••", secret: true },
      { key: "SMTP_FROM", label: "SMTP: عنوان المرسل", placeholder: "you@gmail.com" },
    ],
    test: async () => {
      const r = await testSupabaseConnection();
      const smtp = await applySmtpSettings();
      return `متصل بمشروع: ${r.name} (${r.status})` + (smtp ? ` · إعدادات البريد اتطبّقت على المشروع (${smtp})` : "");
    },
  },
  {
    id: "firebase",
    title: "Firebase (الإشعارات)",
    icon: "notifications-outline",
    tint: "#FBBF24",
    hint:
      "للإشعارات والتطبيق مقفول. مرة واحدة: افتح console.firebase.google.com وأنشئ مشروع، ثم إعدادات المشروع > " +
      "حسابات الخدمة > إنشاء مفتاح خاص جديد، وانسخ محتوى ملف JSON كامل هنا. التطبيقات بتتسجل في المشروع تلقائياً.",
    fields: [{ key: "FIREBASE_SERVICE_ACCOUNT", label: "مفتاح حساب الخدمة (JSON)", placeholder: '{"type": "service_account", ...}', secret: true }],
    test: async () => {
      const raw = (await SecureStore.getItemAsync("FIREBASE_SERVICE_ACCOUNT")) ?? "";
      return `مفتاح صالح لمشروع: ${parseServiceAccount(raw)}`;
    },
  },
  {
    id: "claude",
    title: "Claude",
    icon: "chatbubble-ellipses-outline",
    tint: "#FB923C",
    hint: "اختياري.",
    fields: [{ key: "CLAUDE_API_KEY", label: "API Key", placeholder: "sk-ant-...", secret: true }],
    test: async () => {
      await testClaudeConnection();
      return "متصل بنجاح";
    },
  },
];

function ServiceForm({ service, onSaved }: { service: Service; onSaved: () => void }) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [saved, setSaved] = useState<Record<string, string>>({});
  const [status, setStatus] = useState<Status>({ kind: "idle" });

  useEffect(() => {
    Promise.all(service.fields.map(async (f) => [f.key, (await SecureStore.getItemAsync(f.key)) ?? ""] as const)).then(
      (entries) => {
        const loaded = Object.fromEntries(entries);
        setValues(loaded);
        setSaved(loaded);
      }
    );
  }, [service]);

  const dirty = service.fields.some((f) => (values[f.key] ?? "") !== (saved[f.key] ?? ""));

  async function saveAndTest() {
    setStatus({ kind: "loading" });
    try {
      if (dirty) {
        for (const f of service.fields) {
          const v = (values[f.key] ?? "").trim();
          if (v) await SecureStore.setItemAsync(f.key, v);
          else await SecureStore.deleteItemAsync(f.key);
        }
        setSaved({ ...values });
        onSaved();
      }
      setStatus({ kind: "ok", message: await service.test() });
    } catch (e: any) {
      setStatus({ kind: "error", message: e?.message ?? "تعذّر الاتصال" });
    }
  }

  return (
    <View>
      {service.hint ? <Text style={styles.sheetText}>{service.hint}</Text> : null}
      {service.fields.map((f) => (
        <KeyInput
          key={f.key}
          label={f.label}
          placeholder={f.placeholder}
          secret={f.secret}
          value={values[f.key] ?? ""}
          onChangeText={(t) => setValues((p) => ({ ...p, [f.key]: t }))}
        />
      ))}
      <Button
        title={dirty ? "حفظ واختبار الاتصال" : "اختبار الاتصال"}
        icon="flash-outline"
        onPress={saveAndTest}
        loading={status.kind === "loading"}
      />
      <StatusLine status={status} />
    </View>
  );
}

/** Sends a real sign-in code and shows Supabase's answer, to find out why codes do not arrive. */
function EmailCodeTester() {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<EmailCodeTest | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setBusy(true);
    setResult(null);
    setError(null);
    try {
      setResult(await testEmailCode(email.trim()));
    } catch (e: any) {
      setError(e?.message ?? "تعذّر الإرسال");
    } finally {
      setBusy(false);
    }
  }

  const reason = !result || result.ok
    ? ""
    : /rate limit/i.test(result.reply)
    ? "وصلت حد الرسائل في الساعة. استنى شوية أو زوّد الحد."
    : /sending|smtp|mail/i.test(result.reply)
    ? "Supabase ما قدر يرسل عبر خادم البريد: راجع بيانات SMTP (لـ Gmail لازم «كلمة مرور تطبيق» من 16 حرف، والمنفذ 587)."
    : "";

  return (
    <View style={{ marginTop: space.xl }}>
      <Text style={styles.sheetTitle}>تجربة رمز الدخول بالبريد</Text>
      <Text style={styles.sheetText}>بنرسل رمز حقيقي لبريدك بنفس طريقة التطبيقات، ونعرض رد Supabase وإعدادات البريد.</Text>
      <KeyInput label="البريد" placeholder="you@gmail.com" value={email} onChangeText={setEmail} />
      <Button title="أرسل رمز تجريبي" icon="mail-outline" onPress={run} loading={busy} disabled={!/.+@.+\..+/.test(email.trim())} variant="secondary" />
      {error ? <Banner kind="error" text={error} /> : null}
      {result ? (
        <View style={{ marginTop: space.md, gap: space.sm }}>
          <Banner
            kind={result.ok ? "ok" : "error"}
            text={
              result.ok
                ? "Supabase قبل الطلب وسلّم الرسالة لخادم البريد. لو ما وصلت خلال دقيقتين: شوف مجلد Spam/الرسائل غير المرغوبة، وتأكد إن عنوان المرسل هو نفس حساب SMTP."
                : `رفض Supabase الإرسال (${result.status}). ${reason}`
            }
          />
          {!result.ok ? <Text style={styles.code}>{result.reply}</Text> : null}
          {result.settings.map((l) => (
            <Text key={l} style={styles.sheetText}>
              • {l}
            </Text>
          ))}
        </View>
      ) : null}
    </View>
  );
}

function ModelPicker({ onChange }: { onChange: (id: string) => void }) {
  const [models, setModels] = useState<GeminiModel[]>([]);
  const [selected, setSelected] = useState("");
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<Status>({ kind: "idle" });

  useEffect(() => {
    SecureStore.getItemAsync(GEMINI_MODEL_KEY).then((v) => setSelected(v ?? ""));
  }, []);

  async function fetchModels() {
    setStatus({ kind: "loading" });
    try {
      const list = await listGeminiModels();
      setModels(list);
      setStatus({ kind: "ok", message: `تم جلب ${list.length} نموذج` });
    } catch (e: any) {
      setStatus({ kind: "error", message: e?.message ?? "تعذّر جلب النماذج" });
    }
  }

  async function choose(id: string) {
    setSelected(id);
    await SecureStore.setItemAsync(GEMINI_MODEL_KEY, id);
    onChange(id);
  }

  const q = query.trim().toLowerCase();
  const shown = models.filter((m) => (m.id + " " + m.displayName).toLowerCase().includes(q)).slice(0, 20);

  return (
    <View>
      <Text style={styles.sheetText}>
        {selected ? `المختار: ${selected}` : "ما اخترت نموذج، والافتراضي هو gemini-3.8-flash مع بدائل تلقائية."}
      </Text>
      <Button title="جلب النماذج المتاحة" icon="cloud-download-outline" variant="secondary" onPress={fetchModels} loading={status.kind === "loading"} />
      <StatusLine status={status} />
      {models.length > 0 ? (
        <View style={{ marginTop: space.lg }}>
          <Field label="بحث" icon="search-outline" value={query} onChangeText={setQuery} placeholder="مثال: flash" ltr autoCapitalize="none" />
          <Card style={{ padding: 0, overflow: "hidden" }}>
            {shown.map((m, i) => (
              <ListRow
                key={m.id}
                title={m.id}
                subtitle={m.displayName}
                chevron={false}
                last={i === shown.length - 1}
                right={
                  <Ionicons
                    name={m.id === selected ? "radio-button-on" : "radio-button-off"}
                    size={20}
                    color={m.id === selected ? colors.accent : colors.textMuted}
                  />
                }
                onPress={() => choose(m.id)}
              />
            ))}
          </Card>
        </View>
      ) : null}
    </View>
  );
}

function runLabel(r: ToolRun) {
  if (r.status !== "completed") return { text: "شغّال الآن", color: colors.infoText, icon: "time-outline" as IconName };
  if (r.conclusion === "success") return { text: "نجح", color: colors.okText, icon: "checkmark-circle" as IconName };
  return { text: "فشل", color: colors.errorText, icon: "close-circle" as IconName };
}

function ToolUpdate() {
  const [runs, setRuns] = useState<ToolRun[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      setRuns(await listToolBuilds());
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function start() {
    setBusy(true);
    setError(null);
    try {
      await buildTool();
      setTimeout(refresh, 3000);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <View>
      <Text style={styles.sheetText}>يبني نسخة جديدة من APK Fact نفسه (مش من تطبيقاتك). تحتاجه بس لما يتغيّر كود الأداة.</Text>
      <Button title="ابدأ بناء نسخة جديدة" icon="rocket-outline" onPress={start} loading={busy} />
      {error ? <Banner kind="error" text={error} /> : null}
      <View style={styles.runsHead}>
        <Text style={styles.runsTitle}>آخر عمليات البناء</Text>
        <Pressable onPress={refresh} hitSlop={8}>
          <Ionicons name="refresh" size={18} color={colors.infoText} />
        </Pressable>
      </View>
      <Card style={{ padding: 0, overflow: "hidden" }}>
        {(runs ?? []).map((r, i, arr) => {
          const l = runLabel(r);
          return (
            <ListRow
              key={r.id}
              icon={l.icon}
              tint={l.color}
              title={l.text}
              subtitle={new Date(r.createdAt).toLocaleString("ar-EG")}
              onPress={() => Linking.openURL(r.htmlUrl)}
              last={i === arr.length - 1}
            />
          );
        })}
      </Card>
    </View>
  );
}

function VaultPanel({ status, onReady }: { status: VaultStatus | null; onReady: () => void }) {
  const [steps, report, reset] = useSteps([
    ["repo", "إنشاء مستودع خاص apk-fact-vault"],
    ["secret", "حفظ مفتاح الوصول كسرّ مشفّر"],
    ["variable", "ربط الخزنة بعمليات البناء"],
  ]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [apps, setApps] = useState<VaultApp[] | null>(null);

  useEffect(() => {
    if (status?.ready && status.repo) listVaultApps(status.repo).then(setApps).catch(() => setApps([]));
  }, [status]);

  async function setup() {
    setBusy(true);
    setError(null);
    reset();
    try {
      await setupVault(report);
      onReady();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <View>
      <Text style={styles.sheetText}>
        مستودع خاص على حسابك يحفظ لكل تطبيق: مفتاح التوقيع الدائم، الكود كامل، والوصف وسجل التعديلات. كل APK بيتوقّع
        بنفس مفتاح تطبيقه، فالتحديثات بتتثبّت فوق النسخة القديمة بدون مشاكل.
      </Text>
      {status?.ready ? (
        <>
          <Banner kind="ok" text={`الخزنة جاهزة: ${status.repo} (خاص)`} />
          <View style={styles.runsHead}>
            <Text style={styles.runsTitle}>المحفوظ في الخزنة</Text>
            <Text style={styles.sheetSmall}>{apps ? `${apps.length} تطبيق` : "…"}</Text>
          </View>
          <Card style={{ padding: 0, overflow: "hidden" }}>
            {(apps ?? []).length === 0 ? (
              <ListRow icon="file-tray-outline" title="لسه ما في تطبيقات محفوظة" subtitle="احفظ تطبيق من صفحته، أو ابنِه وبيتحفظ تلقائياً" chevron={false} last />
            ) : (
              (apps ?? []).map((a, i, arr) => (
                <ListRow
                  key={a.name}
                  icon="shield-checkmark-outline"
                  tint={colors.okText}
                  title={a.name}
                  subtitle={`${a.packageId ?? ""}\n${(a.sha256 ?? "").slice(0, 23)}…`}
                  value={a.savedAt ? new Date(a.savedAt).toLocaleDateString("ar-EG") : undefined}
                  chevron={false}
                  last={i === arr.length - 1}
                />
              ))
            )}
          </Card>
          <Button title="إعادة الربط" icon="refresh" variant="secondary" onPress={setup} loading={busy} style={{ marginTop: space.lg }} />
        </>
      ) : (
        <Button title="إنشاء الخزنة وربطها" icon="shield-checkmark-outline" onPress={setup} loading={busy} />
      )}
      {busy || error || steps.some((st) => st.state !== "pending") ? (
        <Card style={{ marginTop: space.lg }}>
          <Timeline steps={steps} />
        </Card>
      ) : null}
      {error ? <Banner kind="error" text={error} /> : null}
    </View>
  );
}

function MinutesPanel({ repoPrivate }: { repoPrivate: boolean }) {
  const [used, setUsed] = useState<number | null>(null);
  useEffect(() => {
    monthMinutes().then(setUsed).catch(() => setUsed(null));
  }, []);
  const pct = used === null ? 0 : Math.min(100, Math.round((used / FREE_MINUTES) * 100));
  return (
    <View>
      <Text style={styles.sheetText}>
        {repoPrivate
          ? `المستودع خاص، فـ GitHub بيدي ${FREE_MINUTES} دقيقة بناء مجانية كل شهر. لما تخلص، البناء بيقيف لحد أول الشهر، إلا لو فعّلت الدفع.`
          : "المستودع لسه عام، فالبناء مجاني بلا حد. الحد ده بيبدأ لما تخلّيه خاص من «الخصوصية»."}
      </Text>
      <Card style={{ marginBottom: space.md }}>
        <Text style={styles.minutesBig}>{used === null ? "…" : `${used} دقيقة`}</Text>
        <Text style={styles.sheetSmall}>
          استهلاك الشهر ده (تقريبي){repoPrivate ? ` من ${FREE_MINUTES} مجانية` : ""}
        </Text>
        {repoPrivate ? (
          <View style={styles.bar}>
            <View style={[styles.barFill, { width: `${pct}%`, backgroundColor: pct >= 80 ? colors.warnText : colors.okText }]} />
          </View>
        ) : null}
      </Card>
      {repoPrivate && pct >= 80 ? <Banner kind="error" text="قرّبت تخلّص الدقايق المجانية. زوّدها عشان البناء ما يوقف." /> : null}
      <Banner
        kind="info"
        text={
          "في صفحة الفواتير اللي بتفتح: 1) أضف طريقة دفع (Payment information). 2) في Budgets and alerts عدّل حد صرف Actions " +
          "لمبلغ يناسبك (مثلاً 5 أو 10 دولار). البناء بعد الدقايق المجانية بيتحسب من المبلغ ده بس، وما بيعدّيه أبداً."
        }
      />
      <Button title="زيادة الدقايق (صفحة الدفع)" icon="card-outline" onPress={() => Linking.openURL(BILLING_URL)} style={{ marginTop: space.md }} />
    </View>
  );
}

function PrivacyPanel({ status, onChange }: { status: PrivacyStatus | null; onChange: () => void }) {
  const [steps, report, reset] = useSteps([
    ["repo", "إنشاء مستودع عام للتحديثات apk-fact-updates (بدون كود)"],
    ["secret", "حفظ مفتاح الوصول كسرّ مشفّر"],
    ["variable", "ربطه بعمليات البناء"],
  ]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function setup() {
    setBusy(true);
    setError(null);
    reset();
    try {
      await setupUpdatesRepo(report);
      onChange();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function goPrivate() {
    setBusy(true);
    setError(null);
    let installed: string[] = [];
    try {
      installed = await appsWithInstalls();
    } catch {}
    setBusy(false);
    Alert.alert(
      "تخلّي apk-fact خاص؟",
      "• كود كل التطبيقات ووصفها وسجلات البناء بتبقى مخفية، ما يشوفها غيرك.\n" +
        "• GitHub بيدي المستودعات الخاصة حوالي 2000 دقيقة بناء مجانية في الشهر (تقريباً 50 تطبيق بإنشائه وبنائه)، والزيادة بفلوس قليلة على كل دقيقة.\n" +
        (installed.length
          ? `• التطبيقات المثبّتة حالياً (${installed.join("، ")}) محتاجة بناء جديد وتثبيته مرة واحدة يدوياً، وبعدها التحديثات بتوصلها عادي.\n`
          : "") +
        "• تقدر ترجّعه عام من GitHub في أي وقت.",
      [
        { text: "إلغاء", style: "cancel" },
        {
          text: "خلّيه خاص",
          style: "destructive",
          onPress: async () => {
            setBusy(true);
            try {
              await makeRepoPrivate();
              onChange();
            } catch (e: any) {
              setError(e.message);
            } finally {
              setBusy(false);
            }
          },
        },
      ]
    );
  }

  return (
    <View>
      <Text style={styles.sheetText}>
        مستودع apk-fact فيه كود تطبيقات زباينك ووصفها وسجلات بنائها. لما يبقى خاص، ما يشوفها غيرك. التطبيقات المثبّتة
        بتاخد تحديثاتها من مستودع عام صغير اسمه apk-fact-updates، وده فيه ملفات APK/AAB ورقم الإصدار بس، بدون أي كود.
      </Text>
      {!status ? (
        <Banner kind="info" text="بنقرأ الحالة…" />
      ) : (
        <>
          <Banner
            kind={status.updatesReady ? "ok" : "info"}
            text={status.updatesReady ? `1. مستودع التحديثات جاهز: ${status.updatesRepo}` : "1. مستودع التحديثات لسه ما اتجهّز"}
          />
          <Banner
            kind={status.repoPrivate ? "ok" : "info"}
            text={status.repoPrivate ? "2. apk-fact خاص: كود الزباين مخفي ✔" : "2. apk-fact لسه عام: أي حد يقدر يشوف الكود"}
          />
          {!status.updatesReady ? (
            <Button title="جهّز مستودع التحديثات" icon="cloud-upload-outline" onPress={setup} loading={busy} style={{ marginTop: space.md }} />
          ) : !status.repoPrivate ? (
            <Button title="خلّي apk-fact خاص" icon="lock-closed-outline" onPress={goPrivate} loading={busy} style={{ marginTop: space.md }} />
          ) : null}
        </>
      )}
      {steps.some((st) => st.state !== "pending") ? (
        <Card style={{ marginTop: space.lg }}>
          <Timeline steps={steps} />
        </Card>
      ) : null}
      {error ? <Banner kind="error" text={error} /> : null}
    </View>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.groupWrap}>
      <Text style={styles.groupLabel}>{title}</Text>
      <View style={styles.group}>{children}</View>
    </View>
  );
}

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const [configured, setConfigured] = useState<Record<string, boolean>>({});
  const [model, setModel] = useState("");
  const [open, setOpen] = useState<string | null>(null);
  const [vault, setVault] = useState<VaultStatus | null>(null);
  const [privacy, setPrivacy] = useState<PrivacyStatus | null>(null);

  const loadStatus = useCallback(async () => {
    const entries = await Promise.all(
      SERVICES.map(async (s) => [s.id, !!(await SecureStore.getItemAsync(s.fields[0].key))] as const)
    );
    setConfigured(Object.fromEntries(entries));
    setModel((await SecureStore.getItemAsync(GEMINI_MODEL_KEY)) ?? "");
    vaultStatus().then(setVault).catch(() => setVault({ ready: false, repo: null }));
    privacyStatus().then(setPrivacy).catch(() => setPrivacy(null));
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadStatus().catch(() => {});
    }, [loadStatus])
  );

  const service = SERVICES.find((s) => s.id === open);
  const ready = SERVICES.filter((s) => configured[s.id]).length;
  const pct = Math.round((ready / SERVICES.length) * 100);

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView
        contentContainerStyle={{ paddingTop: insets.top + space.lg, paddingHorizontal: space.lg, paddingBottom: 140 }}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.title}>الإعدادات</Text>

        <View style={styles.summary}>
          <View style={{ flex: 1 }}>
            <Text style={styles.summaryNum}>
              {ready} من {SERVICES.length}
            </Text>
            <Text style={styles.summaryText}>خدمات مضبوطة</Text>
          </View>
          <View style={styles.track}>
            <View style={[styles.fill, { width: `${pct}%` }]} />
          </View>
        </View>

        <Group title="الخدمات">
          {SERVICES.map((s, i) => (
            <ListRow
              key={s.id}
              icon={s.icon}
              tint={s.tint}
              title={s.title}
              subtitle={configured[s.id] ? "مضبوط" : "غير مضبوط"}
              right={<View style={[styles.dot, { backgroundColor: configured[s.id] ? colors.okText : OFF }]} />}
              onPress={() => setOpen(s.id)}
              last={i === SERVICES.length - 1}
            />
          ))}
        </Group>

        <Group title="الأمان والبيانات">
          <ListRow
            icon="shield-checkmark-outline"
            tint={vault?.ready ? colors.okText : colors.warnText}
            title="الخزنة الخاصة"
            subtitle={vault?.ready ? `جاهزة · ${vault.repo}` : "مفاتيح التوقيع وتفاصيل كل تطبيق"}
            right={<View style={[styles.dot, { backgroundColor: vault?.ready ? colors.okText : OFF }]} />}
            onPress={() => setOpen("vault")}
          />
          <ListRow
            icon="server-outline"
            tint={colors.accent}
            title="مشاريع Supabase للزباين"
            subtitle="مشروع منفصل لكل زبون"
            onPress={() => setOpen("projects")}
          />
          <ListRow
            icon="lock-closed-outline"
            tint={privacy?.repoPrivate ? colors.okText : colors.warnText}
            title="خصوصية أكواد الزباين"
            subtitle={privacy?.repoPrivate ? "apk-fact خاص" : "apk-fact عام حالياً"}
            right={<View style={[styles.dot, { backgroundColor: privacy?.repoPrivate ? colors.okText : OFF }]} />}
            onPress={() => setOpen("privacy")}
          />
          <ListRow
            icon="timer-outline"
            tint={colors.accent}
            title="دقايق البناء"
            subtitle={privacy?.repoPrivate ? `${FREE_MINUTES} دقيقة مجانية في الشهر` : "مجانية بلا حد"}
            onPress={() => setOpen("minutes")}
            last
          />
        </Group>

        <Group title="الذكاء الاصطناعي">
          <ListRow
            icon="hardware-chip-outline"
            tint={colors.accent}
            title="نموذج Gemini"
            value={model || "تلقائي"}
            onPress={() => setOpen("model")}
            last
          />
        </Group>

        <Group title="الأداة">
          <ListRow icon="rocket-outline" title="تحديث APK Fact" subtitle="بناء نسخة جديدة من الأداة" onPress={() => setOpen("tool")} />
          <ListRow icon="logo-github" tint={colors.softText} title="المستودع" value={REPO.split("/")[1]} chevron={false} />
          <ListRow icon="information-circle-outline" title="الإصدار" value="2.0" chevron={false} last />
        </Group>
      </ScrollView>

      <Sheet visible={!!service} title={service?.title ?? ""} onClose={() => setOpen(null)}>
        {service ? <ServiceForm service={service} onSaved={loadStatus} /> : null}
        {service?.id === "supabase" ? <EmailCodeTester /> : null}
      </Sheet>
      <Sheet visible={open === "vault"} title="الخزنة الخاصة" onClose={() => setOpen(null)}>
        <VaultPanel status={vault} onReady={loadStatus} />
      </Sheet>
      <Sheet visible={open === "projects"} title="قواعد بيانات الزباين" onClose={() => setOpen(null)}>
        <DbProjectsPanel />
      </Sheet>
      <Sheet visible={open === "minutes"} title="دقايق البناء" onClose={() => setOpen(null)}>
        <MinutesPanel repoPrivate={!!privacy?.repoPrivate} />
      </Sheet>
      <Sheet visible={open === "privacy"} title="الخصوصية" onClose={() => setOpen(null)}>
        <PrivacyPanel status={privacy} onChange={loadStatus} />
      </Sheet>
      <Sheet visible={open === "model"} title="نموذج Gemini" onClose={() => setOpen(null)}>
        <ModelPicker onChange={setModel} />
      </Sheet>
      <Sheet visible={open === "tool"} title="تحديث APK Fact" onClose={() => setOpen(null)}>
        <ToolUpdate />
      </Sheet>
    </View>
  );
}

const styles = StyleSheet.create({
  title: { color: colors.text, fontSize: 32, fontWeight: "700", textAlign: "right", marginBottom: space.lg },

  summary: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.lg,
    backgroundColor: colors.glass,
    borderRadius: 24,
    padding: space.lg,
    marginBottom: space.xl,
  },
  summaryNum: { color: colors.text, fontSize: 22, fontWeight: "700", textAlign: "right" },
  summaryText: { color: colors.textMuted, fontSize: 13, textAlign: "right", marginTop: 2 },
  track: { width: 110, height: 8, borderRadius: 4, backgroundColor: colors.glassBorder, overflow: "hidden" },
  fill: { height: 8, borderRadius: 4, backgroundColor: colors.primary },

  groupWrap: { marginBottom: space.xl },
  groupLabel: { color: colors.textMuted, fontSize: 13, fontWeight: "600", textAlign: "right", marginBottom: space.sm, marginRight: space.sm },
  group: { backgroundColor: colors.glass, borderRadius: 24, overflow: "hidden" },
  dot: { width: 8, height: 8, borderRadius: 4 },

  minutesBig: { fontSize: 28, fontWeight: "800", color: colors.text, textAlign: "right" },
  bar: { height: 8, borderRadius: 4, backgroundColor: colors.border, marginTop: space.sm, overflow: "hidden" },
  barFill: { height: 8, borderRadius: 4 },
  sheetText: { ...type.body, color: colors.textMuted, textAlign: "right", marginBottom: space.lg },
  runsHead: { flexDirection: "row-reverse", justifyContent: "space-between", alignItems: "center", marginTop: space.xl, marginBottom: space.md },
  runsTitle: { ...type.label, color: colors.text },
  sheetSmall: { ...type.hint, color: colors.textMuted },
  sheetTitle: { ...type.label, color: colors.text, textAlign: "right", marginBottom: space.sm },
  code: { fontFamily: "monospace", fontSize: 12, color: colors.text, textAlign: "left", backgroundColor: colors.field, padding: space.md, borderRadius: radius.field },
}); 
