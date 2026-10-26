import React, { useEffect, useState } from "react";
import { ScrollView, Text, View, TextInput, TouchableOpacity, StyleSheet } from "react-native";
import * as SecureStore from "expo-secure-store";
import { testGithubConnection } from "../services/github";
import { testSupabaseConnection } from "../services/supabase";
import { testGeminiConnection, testClaudeConnection, listGeminiModels, GeminiModel } from "../services/ai";
import { Card, Button, KeyInput, StatusLine, Status } from "../components/ui";
import { colors, space, radius, type } from "../theme";

type FieldDef = { key: string; label: string; placeholder?: string; secret?: boolean };

const GEMINI_MODEL_KEY = "GEMINI_MODEL";

const GITHUB_FIELDS: FieldDef[] = [
  { key: "GITHUB_TOKEN", label: "Personal Access Token", placeholder: "ghp_...", secret: true },
  { key: "GITHUB_REPO_1", label: "مستودع التطبيق الأول", placeholder: "username/app-one" },
  { key: "GITHUB_REPO_2", label: "مستودع التطبيق الثاني", placeholder: "username/app-two" },
];

const SUPABASE_FIELDS: FieldDef[] = [
  {
    key: "SUPABASE_ACCESS_TOKEN",
    label: "Personal Access Token (من الحساب، مش من المشروع)",
    placeholder: "sbp_...",
    secret: true,
  },
  { key: "SUPABASE_PROJECT_REF", label: "Project Ref (من رابط المشروع)", placeholder: "abcdefghijklmnop" },
];

const GEMINI_FIELDS: FieldDef[] = [
  { key: "GEMINI_API_KEY", label: "المفتاح الأول", placeholder: "AIza...", secret: true },
  { key: "GEMINI_API_KEY_2", label: "المفتاح الثاني", placeholder: "AIza...", secret: true },
  { key: "GEMINI_API_KEY_3", label: "المفتاح الثالث", placeholder: "AIza...", secret: true },
];

const CLAUDE_FIELDS: FieldDef[] = [
  { key: "CLAUDE_API_KEY", label: "API Key", placeholder: "sk-ant-...", secret: true },
];

function useSecureFields(fields: FieldDef[]) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [saved, setSaved] = useState<Record<string, string>>({});

  useEffect(() => {
    let alive = true;
    (async () => {
      const entries = await Promise.all(
        fields.map(async (f) => [f.key, (await SecureStore.getItemAsync(f.key)) ?? ""] as const)
      );
      if (!alive) return;
      const loaded = Object.fromEntries(entries);
      setValues(loaded);
      setSaved(loaded);
    })();
    return () => {
      alive = false;
    };
  }, [fields]);

  const dirty = fields.some((f) => (values[f.key] ?? "") !== (saved[f.key] ?? ""));

  async function save() {
    const next: Record<string, string> = {};
    for (const f of fields) {
      const v = (values[f.key] ?? "").trim();
      next[f.key] = v;
      if (v) await SecureStore.setItemAsync(f.key, v);
      else await SecureStore.deleteItemAsync(f.key);
    }
    setValues(next);
    setSaved(next);
  }

  return { values, setValue: (key: string, v: string) => setValues((p) => ({ ...p, [key]: v })), dirty, save };
}

function ConnectionSection({
  title,
  hint,
  fields,
  testLabel,
  onTest,
}: {
  title: string;
  hint?: string;
  fields: FieldDef[];
  testLabel: string;
  onTest: () => Promise<string>;
}) {
  const { values, setValue, dirty, save } = useSecureFields(fields);
  const [status, setStatus] = useState<Status>({ kind: "idle" });

  async function run() {
    setStatus({ kind: "loading" });
    try {
      if (dirty) await save();
      const message = await onTest();
      setStatus({ kind: "ok", message });
    } catch (e: any) {
      setStatus({ kind: "error", message: e?.message ?? "تعذّر الاتصال" });
    }
  }

  return (
    <Card style={{ marginBottom: space.lg }}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {hint ? <Text style={styles.hint}>{hint}</Text> : <View style={{ height: space.md }} />}

      {fields.map((f) => (
        <KeyInput
          key={f.key}
          label={f.label}
          placeholder={f.placeholder}
          secret={f.secret}
          value={values[f.key] ?? ""}
          onChangeText={(t) => setValue(f.key, t)}
        />
      ))}

      <Button
        title={dirty ? `حفظ و${testLabel}` : testLabel}
        onPress={run}
        loading={status.kind === "loading"}
      />
      <StatusLine status={status} />
    </Card>
  );
}

function GeminiModelPicker() {
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
  }

  const q = query.trim().toLowerCase();
  const filtered = models.filter((m) => (m.id + " " + m.displayName).toLowerCase().includes(q));
  const shown = filtered.slice(0, 15);

  return (
    <Card style={{ marginBottom: space.lg }}>
      <Text style={styles.sectionTitle}>نموذج Gemini</Text>
      <Text style={styles.hint}>
        {selected ? `النموذج المختار: ${selected}` : "ما اخترت نموذج لسه."}
      </Text>

      <Button
        title="جلب النماذج المتاحة"
        variant="secondary"
        onPress={fetchModels}
        loading={status.kind === "loading"}
      />
      <StatusLine status={status} />

      {models.length > 0 && (
        <View style={{ marginTop: space.lg }}>
          <TextInput
            style={styles.search}
            value={query}
            onChangeText={setQuery}
            placeholder="ابحث، مثال: flash"
            placeholderTextColor={colors.textMuted}
            autoCapitalize="none"
            autoCorrect={false}
            textAlign="left"
            writingDirection="ltr"
          />

          {shown.map((m) => {
            const active = m.id === selected;
            return (
              <TouchableOpacity
                key={m.id}
                style={[styles.modelRow, active && styles.modelRowActive]}
                onPress={() => choose(m.id)}
                accessibilityRole="radio"
                accessibilityState={{ selected: active }}
              >
                <Text style={[styles.radio, active && { color: colors.primary }]}>{active ? "◉" : "○"}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.modelId}>{m.id}</Text>
                  <Text style={styles.modelName}>{m.displayName}</Text>
                </View>
              </TouchableOpacity>
            );
          })}

          {filtered.length > shown.length && (
            <Text style={[styles.hint, { marginTop: space.md }]}>
              عرض {shown.length} من {filtered.length}. اكتب في البحث لتضييق القائمة.
            </Text>
          )}
          {filtered.length === 0 && <Text style={[styles.hint, { marginTop: space.md }]}>ما في نتائج.</Text>}
        </View>
      )}
    </Card>
  );
}

export default function ConnectionsScreen() {
  return (
    <ScrollView
      style={{ backgroundColor: colors.bg }}
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <ConnectionSection
        title="GitHub"
        fields={GITHUB_FIELDS}
        testLabel="اختبار الاتصال"
        onTest={async () => {
          const r = await testGithubConnection();
          return `متصل بنجاح باسم: ${r.login}`;
        }}
      />

      <ConnectionSection
        title="Supabase"
        hint="مشروع Supabase ده بيتشارك بين التطبيق الأول والتاني، وهو اللي بيربطهم ببعض."
        fields={SUPABASE_FIELDS}
        testLabel="اختبار الاتصال"
        onTest={async () => {
          const r = await testSupabaseConnection();
          return `متصل بمشروع: ${r.name} (${r.status})`;
        }}
      />

      <ConnectionSection
        title="Gemini"
        hint="تقدر تضيف لحد ثلاثة مفاتيح."
        fields={GEMINI_FIELDS}
        testLabel="اختبار الاتصال"
        onTest={async () => {
          const r = await testGeminiConnection();
          return `متصل، عدد النماذج المتاحة: ${r.modelCount}`;
        }}
      />

      <GeminiModelPicker />

      <ConnectionSection
        title="Claude"
        fields={CLAUDE_FIELDS}
        testLabel="اختبار الاتصال"
        onTest={async () => {
          await testClaudeConnection();
          return "متصل بنجاح";
        }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: space.lg, paddingBottom: 96 },
  sectionTitle: { ...type.sectionTitle, color: colors.text },
  hint: { ...type.hint, color: colors.textMuted, marginTop: space.xs, marginBottom: space.lg },
  search: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.field,
    paddingHorizontal: space.md,
    minHeight: 46,
    fontSize: 15,
    color: colors.text,
    marginBottom: space.sm,
  },
  modelRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.md,
    minHeight: 52,
    paddingHorizontal: space.sm,
    borderTopWidth: 1,
    borderColor: colors.border,
  },
  modelRowActive: { backgroundColor: colors.infoBg, borderRadius: radius.field },
  radio: { fontSize: 18, color: colors.textMuted },
  modelId: { fontSize: 14, fontWeight: "600", color: colors.text, textAlign: "left", writingDirection: "ltr" },
  modelName: { fontSize: 12, color: colors.textMuted, textAlign: "left", writingDirection: "ltr" },
});
