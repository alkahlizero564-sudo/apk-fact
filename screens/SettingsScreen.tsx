import React, { useCallback, useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable, Linking } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import * as SecureStore from "expo-secure-store";
import { Ionicons } from "@expo/vector-icons";
import {
  Screen,
  Section,
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
import { testSupabaseConnection } from "../services/supabase";
import { testGeminiConnection, testClaudeConnection, listGeminiModels, GeminiModel } from "../services/ai";
import { buildTool, listToolBuilds, ToolRun } from "../services/appActions";
import { REPO } from "../services/config";
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

const SERVICES: Service[] = [
  {
    id: "github",
    title: "GitHub",
    icon: "logo-github",
    tint: "#E5E7EB",
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
    hint: "قاعدة البيانات المشتركة لربط تطبيقين.",
    fields: [
      { key: "SUPABASE_ACCESS_TOKEN", label: "Personal Access Token (من الحساب)", placeholder: "sbp_...", secret: true },
      { key: "SUPABASE_PROJECT_REF", label: "Project Ref (من رابط المشروع)", placeholder: "abcdefghijklmnop" },
    ],
    test: async () => {
      const r = await testSupabaseConnection();
      return `متصل بمشروع: ${r.name} (${r.status})`;
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
                    color={m.id === selected ? colors.primary : colors.textMuted}
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
                  subtitle={`${a.packageId ?? ""}
${(a.sha256 ?? "").slice(0, 23)}…`}
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

export default function SettingsScreen() {
  const [configured, setConfigured] = useState<Record<string, boolean>>({});
  const [model, setModel] = useState("");
  const [open, setOpen] = useState<string | null>(null);
  const [vault, setVault] = useState<VaultStatus | null>(null);

  const loadStatus = useCallback(async () => {
    const entries = await Promise.all(
      SERVICES.map(async (s) => [s.id, !!(await SecureStore.getItemAsync(s.fields[0].key))] as const)
    );
    setConfigured(Object.fromEntries(entries));
    setModel((await SecureStore.getItemAsync(GEMINI_MODEL_KEY)) ?? "");
    vaultStatus().then(setVault).catch(() => setVault({ ready: false, repo: null }));
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadStatus().catch(() => {});
    }, [loadStatus])
  );

  const service = SERVICES.find((s) => s.id === open);
  const ready = SERVICES.filter((s) => configured[s.id]).length;

  return (
    <Screen title="الإعدادات" subtitle={`${ready} من ${SERVICES.length} خدمات مضبوطة`}>
      <Section title="الخدمات">
        <Card style={styles.list}>
          {SERVICES.map((s, i) => (
            <ListRow
              key={s.id}
              icon={s.icon}
              tint={s.tint}
              title={s.title}
              subtitle={configured[s.id] ? "مضبوط" : "غير مضبوط"}
              right={<View style={[styles.dot, { backgroundColor: configured[s.id] ? colors.okText : colors.border }]} />}
              onPress={() => setOpen(s.id)}
              last={i === SERVICES.length - 1}
            />
          ))}
        </Card>
      </Section>

      <Section title="الخزنة الخاصة">
        <Card style={styles.list}>
          <ListRow
            icon="shield-checkmark-outline"
            tint={vault?.ready ? colors.okText : colors.warnText}
            title="الخزنة الخاصة"
            subtitle={vault?.ready ? `جاهزة · ${vault.repo}` : "مفاتيح التوقيع وتفاصيل كل تطبيق في مستودع خاص"}
            right={<View style={[styles.dot, { backgroundColor: vault?.ready ? colors.okText : colors.border }]} />}
            onPress={() => setOpen("vault")}
            last
          />
        </Card>
      </Section>

      <Section title="الذكاء الاصطناعي">
        <Card style={styles.list}>
          <ListRow icon="hardware-chip-outline" tint={colors.accent} title="نموذج Gemini" value={model || "تلقائي"} onPress={() => setOpen("model")} last />
        </Card>
      </Section>

      <Section title="الأداة">
        <Card style={styles.list}>
          <ListRow icon="rocket-outline" title="تحديث APK Fact" subtitle="بناء نسخة جديدة من الأداة" onPress={() => setOpen("tool")} />
          <ListRow icon="logo-github" tint="#E5E7EB" title="المستودع" value={REPO.split("/")[1]} chevron={false} />
          <ListRow icon="information-circle-outline" title="الإصدار" value="2.0" chevron={false} last />
        </Card>
      </Section>

      <Sheet visible={!!service} title={service?.title ?? ""} onClose={() => setOpen(null)}>
        {service ? <ServiceForm service={service} onSaved={loadStatus} /> : null}
      </Sheet>
      <Sheet visible={open === "vault"} title="الخزنة الخاصة" onClose={() => setOpen(null)}>
        <VaultPanel status={vault} onReady={loadStatus} />
      </Sheet>
      <Sheet visible={open === "model"} title="نموذج Gemini" onClose={() => setOpen(null)}>
        <ModelPicker onChange={setModel} />
      </Sheet>
      <Sheet visible={open === "tool"} title="تحديث APK Fact" onClose={() => setOpen(null)}>
        <ToolUpdate />
      </Sheet>
    </Screen>
  );
}

const styles = StyleSheet.create({
  list: { padding: 0, overflow: "hidden" },
  dot: { width: 8, height: 8, borderRadius: 4 },
  sheetText: { ...type.body, color: colors.textMuted, textAlign: "right", marginBottom: space.lg },
  runsHead: { flexDirection: "row-reverse", justifyContent: "space-between", alignItems: "center", marginTop: space.xl, marginBottom: space.md },
  runsTitle: { ...type.label, color: colors.text },
  sheetSmall: { ...type.hint, color: colors.textMuted },
});
