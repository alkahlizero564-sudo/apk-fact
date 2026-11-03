// Database projects for clients (services/projects.ts): add a project from a client's own Supabase account, or
// let APK Fact create a new project in the owner's account. Used in Settings and in the pair form.
import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Alert } from "react-native";
import { Button, Card, Chip, Field, Banner, ListRow, Segmented, Timeline, useSteps } from "./ui";
import { DbProject, REGIONS, listProjects, addClientProject, createProject, removeProject, validRef } from "../services/projects";
import { colors, space, type } from "../theme";

type Props = { onAdded?: (p: DbProject) => void; showList?: boolean };

export default function DbProjectsPanel({ onAdded, showList = true }: Props) {
  const [mode, setMode] = useState<"client" | "create">("client");
  const [projects, setProjects] = useState<DbProject[]>([]);
  const [label, setLabel] = useState("");
  const [ref, setRef] = useState("");
  const [token, setToken] = useState("");
  const [region, setRegion] = useState(REGIONS[0].code);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [steps, report, reset] = useSteps([
    ["org", "قراءة حسابك في Supabase"],
    ["create", "إنشاء المشروع الجديد"],
    ["ready", "تجهيز قاعدة البيانات (دقيقتين تقريباً)"],
  ]);

  const load = () => listProjects().then(setProjects);
  useEffect(() => {
    load();
  }, []);

  async function run(fn: () => Promise<DbProject>) {
    setBusy(true);
    setError(null);
    setOk(null);
    try {
      const p = await fn();
      setOk(`تمت إضافة «${p.label}» (${p.ref})`);
      setLabel("");
      setRef("");
      setToken("");
      await load();
      onAdded?.(p);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  function confirmRemove(p: DbProject) {
    Alert.alert("إزالة من القائمة؟", `«${p.label}» بيتشال من APK Fact بس. المشروع وبياناته في Supabase ما بيتأثروا.`, [
      { text: "إلغاء", style: "cancel" },
      { text: "إزالة", style: "destructive", onPress: () => removeProject(p.ref).then(load) },
    ]);
  }

  return (
    <View>
      {showList ? (
        <Card style={{ padding: 0, overflow: "hidden", marginBottom: space.lg }}>
          {projects.length === 0 ? (
            <ListRow icon="server-outline" title="لسه ما في مشاريع زباين" subtitle="أضف مشروع من حساب زبون أو اعمل مشروع جديد" chevron={false} last />
          ) : (
            projects.map((p, i) => (
              <ListRow
                key={p.ref}
                icon={p.kind === "client" ? "person-outline" : "server-outline"}
                tint={colors.accent}
                title={p.label}
                subtitle={`${p.kind === "client" ? "حساب الزبون" : "حسابك"} · ${p.ref}`}
                onPress={() => confirmRemove(p)}
                last={i === projects.length - 1}
              />
            ))
          )}
        </Card>
      ) : null}

      <Segmented
        value={mode}
        onChange={(v) => setMode(v as "client" | "create")}
        options={[
          { value: "client", label: "مشروع في حساب الزبون" },
          { value: "create", label: "مشروع جديد في حسابي" },
        ]}
      />

      <Field label="اسم يميّزه" icon="pricetag-outline" value={label} onChangeText={setLabel} placeholder="مثال: محل الورد" maxLength={40} />

      {mode === "client" ? (
        <>
          <Text style={styles.hint}>
            الزبون يعمل حساب في supabase.com ومشروع جديد، ويديك: رمز المشروع (من رابط المشروع) ومفتاح وصول من Account →
            Access Tokens. البيانات والفواتير بتبقى في حسابه.
          </Text>
          <Field
            label="رمز المشروع (Project Ref)"
            icon="key-outline"
            value={ref}
            onChangeText={setRef}
            placeholder="abcdefghijklmnopqrst"
            ltr
            autoCapitalize="none"
            autoCorrect={false}
            error={ref.trim() && !validRef(ref.trim().toLowerCase()) ? "20 حرف إنجليزي صغير" : null}
          />
          <Field label="مفتاح الوصول (sbp_…)" icon="lock-closed-outline" value={token} onChangeText={setToken} placeholder="sbp_…" ltr secret autoCapitalize="none" />
          <Button
            title="تحقّق وأضف المشروع"
            icon="checkmark-circle-outline"
            onPress={() => run(() => addClientProject(label, ref, token))}
            loading={busy}
            disabled={!validRef(ref.trim().toLowerCase()) || token.trim().length < 10}
          />
        </>
      ) : (
        <>
          <Text style={styles.hint}>
            APK Fact بيعمل مشروع Supabase جديد في حسابك (المفتاح اللي في الإعدادات). الخطة المجانية تسمح بمشروعين نشطين، وبتوقف
            المشروع لو ما اتستخدم أسبوع؛ لزباين حقيقيين الأحسن خطة مدفوعة أو حساب الزبون.
          </Text>
          <Text style={styles.label}>المكان</Text>
          <View style={styles.chips}>
            {REGIONS.map((r) => (
              <Chip key={r.code} label={r.label} selected={region === r.code} onPress={() => setRegion(r.code)} />
            ))}
          </View>
          <Button
            title="اعمل المشروع"
            icon="add-circle-outline"
            onPress={() => {
              reset();
              run(() => createProject(label, region, report));
            }}
            loading={busy}
            disabled={!label.trim()}
          />
          {steps.some((st) => st.state !== "pending") ? (
            <Card style={{ marginTop: space.md }}>
              <Timeline steps={steps} />
            </Card>
          ) : null}
        </>
      )}
      {ok ? <Banner kind="ok" text={ok} /> : null}
      {error ? <Banner kind="error" text={error} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  hint: { ...type.hint, color: colors.textMuted, textAlign: "right", marginVertical: space.sm },
  label: { ...type.label, color: colors.text, textAlign: "right", marginTop: space.sm },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginVertical: space.sm },
});
