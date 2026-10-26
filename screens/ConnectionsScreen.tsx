import React, { useEffect, useState } from "react";
import { ScrollView, Text, View, StyleSheet } from "react-native";
import * as SecureStore from "expo-secure-store";
import { testGithubConnection } from "../services/github";
import { testSupabaseConnection } from "../services/supabase";
import { testGeminiConnection, testClaudeConnection } from "../services/ai";
import { Card, Button, KeyInput, StatusLine, Status } from "../components/ui";
import { colors, space, type } from "../theme";

type FieldDef = { key: string; label: string; placeholder?: string; secret?: boolean };

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
});
