import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, ActivityIndicator, Alert } from "react-native";
import { WebView } from "react-native-webview";
import { Ionicons } from "@expo/vector-icons";
import {
  Screen,
  Card,
  Section,
  Button,
  Field,
  Chip,
  Segmented,
  Timeline,
  Banner,
  Badge,
  IconButton,
  TimelineStep,
  StepState,
} from "../components/ui";
import { AppAvatar, LangBadge } from "../components/appVisuals";
import { getFileText } from "../services/github";
import { REPO } from "../services/config";
import { vaultStatus } from "../services/vault";
import {
  Target,
  Snapshot,
  PublishedVersion,
  PairInfo,
  publishedVersion,
  pairInfo,
  snapshot,
  restore,
  applyUpdate,
  publishUpdate,
} from "../services/updates";
import { colors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";
import { confirmPermissions } from "../services/permissionPrompt";

type Stage = "write" | "working" | "review" | "publishing" | "done";

const IDEAS = [
  "أضف شاشة جديدة لـ…",
  "احذف القسم الخاص بـ…",
  "غيّر الألوان والخطوط",
  "أضف حقل جديد في النموذج",
  "حسّن الشاشة الرئيسية",
  "أصلح مشكلة: …",
];

function useDynamicSteps() {
  const [steps, setSteps] = useState<TimelineStep[]>([]);
  const report = (key: string, state: StepState, detail?: string) =>
    setSteps((prev) => prev.map((s) => (s.key === key ? { ...s, state, detail: detail ?? s.detail } : s)));
  const reset = (defs: [string, string][]) => setSteps(defs.map(([key, title]) => ({ key, title, state: "pending" })));
  return [steps, report, reset] as const;
}

export default function UpdateScreen({ navigation, route }: RootScreenProps<"Update">) {
  const { name, lang } = route.params;
  const [pair, setPair] = useState<PairInfo | null>(null);
  const [scope, setScope] = useState<"one" | "both">("one");
  const [version, setVersion] = useState<Record<string, PublishedVersion | null>>({});
  const [vaultReady, setVaultReady] = useState<boolean | null>(null);
  const [stage, setStage] = useState<Stage>("write");
  const [text, setText] = useState("");
  const [changes, setChanges] = useState<string[]>([]);
  const [snap, setSnap] = useState<Snapshot | null>(null);
  const [applied, setApplied] = useState<Target[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [steps, report, resetSteps] = useDynamicSteps();
  const [shown, setShown] = useState(name);
  const [preview, setPreview] = useState<{ html: string; ai: boolean } | null>(null);
  const [previewKey, setPreviewKey] = useState(0);

  useEffect(() => {
    pairInfo(name).then(setPair);
    vaultStatus()
      .then((v) => setVaultReady(v.ready))
      .catch(() => setVaultReady(false));
  }, [name]);

  const targets: Target[] =
    pair && scope === "both" ? [{ name, lang }, { name: pair.partner, lang: pair.lang ?? lang }] : [{ name, lang }];
  const locked = applied.length > 0; // after the first change the scope stays the same until done/undo
  const active = locked ? applied : targets;

  useEffect(() => {
    active.forEach((t) => publishedVersion(t.name).then((v) => setVersion((p) => ({ ...p, [t.name]: v }))));
  }, [active.map((t) => t.name).join(",")]);

  useEffect(() => {
    if (stage !== "review") return;
    const t = active.find((x) => x.name === shown) ?? active[0];
    setPreview(null);
    getFileText(REPO, t.lang === "html" ? `apps/${t.name}/index.html` : `apps/${t.name}/preview.html`)
      .then((html) => setPreview({ html: html ?? "<p>لا توجد معاينة</p>", ai: t.lang !== "html" }))
      .catch((e) => setPreview({ html: `<p>${e.message}</p>`, ai: false }));
  }, [stage, shown, previewKey]);

  const roleLabel = (n: string) =>
    !pair ? n : n === name ? (pair.role === "admin" ? "الإدارة" : "الزبون") : pair.role === "admin" ? "الزبون" : "الإدارة";

  async function apply() {
    const change = text.trim();
    if (change.length < 3) return;
    const ts = active;
    setError(null);
    setStage("working");
    resetSteps([
      ...(snap ? [] : ([["snap", "حفظ نسخة للتراجع"]] as [string, string][])),
      ...ts.map((t) => [`ai:${t.name}`, `الذكاء الاصطناعي يحدّث ${roleLabel(t.name)} ويفحص الأخطاء`] as [string, string]),
    ]);
    let saved = snap;
    try {
      if (!saved) {
        report("snap", "active");
        saved = await snapshot(ts);
        setSnap(saved);
        report("snap", "done");
      }
      setApplied(ts); // from here on the code may change, so "تراجع" must stay available
      await applyUpdate(ts, change, report);
      setChanges((c) => [...c, change]);
      setText("");
      setShown(ts[0].name);
      setPreviewKey((k) => k + 1);
      setStage("review");
    } catch (e: any) {
      setError(e.message);
      setStage(saved ? "review" : "write");
    }
  }

  function undo() {
    if (!snap) return;
    Alert.alert("تراجع عن التحديث", "نرجّع الكود زي ما كان قبل التحديث؟", [
      { text: "إلغاء", style: "cancel" },
      {
        text: "تراجع",
        style: "destructive",
        onPress: async () => {
          setStage("working");
          resetSteps([["undo", "إرجاع الكود القديم"]]);
          report("undo", "active");
          try {
            await restore(snap);
            report("undo", "done");
            setSnap(null);
            setApplied([]);
            setChanges([]);
            setStage("write");
          } catch (e: any) {
            report("undo", "error");
            setError(e.message);
            setStage("review");
          }
        },
      },
    ]);
  }

  async function publish() {
    const ts = applied;
    // A permission the code uses but the description did not mention: ask the owner first.
    if (!(await confirmPermissions(ts))) return;
    setError(null);
    setStage("publishing");
    resetSteps(ts.map((t) => [`build:${t.name}`, `بناء الإصدار الجديد من ${roleLabel(t.name)} (مع إصلاح الأخطاء تلقائياً)`]));
    try {
      await publishUpdate(ts, changes.join(" · "), report);
      const vs: Record<string, PublishedVersion | null> = {};
      for (const t of ts) vs[t.name] = await publishedVersion(t.name);
      setVersion((p) => ({ ...p, ...vs }));
      setStage("done");
    } catch (e: any) {
      setError(e.message);
      setStage("review");
    }
  }

  const busy = stage === "working" || stage === "publishing";

  return (
    <Screen title="تحديث التطبيق" subtitle={pair ? "تطبيقين متصلين" : name} onBack={busy ? undefined : () => navigation.goBack()}>
      <Card style={styles.head}>
        <AppAvatar name={name} lang={lang} size={56} />
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={styles.name}>{name}</Text>
          <View style={styles.row}>
            <LangBadge lang={lang} />
            {pair ? <Badge label={pair.role === "admin" ? "تطبيق الإدارة" : "تطبيق الزبون"} color={colors.accent} icon="git-merge-outline" /> : null}
          </View>
          {active.map((t) => (
            <Text key={t.name} style={styles.meta}>
              {active.length > 1 ? `${roleLabel(t.name)}: ` : ""}
              {version[t.name] ? `الإصدار المنشور ${version[t.name]?.versionName ?? version[t.name]?.version}` : "لسه ما في إصدار منشور"}
            </Text>
          ))}
        </View>
      </Card>

      {pair && !locked && stage === "write" ? (
        <Section title="التحديث لـ">
          <Segmented<"one" | "both">
            options={[
              { value: "one", label: `${roleLabel(name)} بس` },
              { value: "both", label: "التطبيقين" },
            ]}
            value={scope}
            onChange={setScope}
          />
          <Text style={styles.hint}>
            {scope === "both"
              ? "التغيير بيتطبّق على تطبيق الزبون وتطبيق الإدارة مع بعض، ونفس قاعدة البيانات."
              : `بنحدّث ${roleLabel(name)} بس، والاتصال بالتطبيق الثاني بيفضل زي ما هو.`}
          </Text>
        </Section>
      ) : null}

      {stage === "write" || stage === "review" ? (
        <Section title={stage === "review" ? "عدّل كمان (اختياري)" : "شنو التحديث؟"}>
          <Field
            label={stage === "review" ? "تغيير إضافي" : "اكتب التحديث"}
            icon="create-outline"
            value={text}
            onChangeText={setText}
            placeholder="مثال: أضف صفحة العروض، واحذف زر المشاركة، وخلّي السعر يظهر بالجنيه"
            multiline
            maxLength={1500}
            counter
          />
          <View style={styles.chips}>
            {IDEAS.map((i) => (
              <Chip key={i} label={i} onPress={() => setText((t) => `${t.trim()} ${i}`.trim())} />
            ))}
          </View>
          <Button
            title={stage === "review" ? "طبّق التغيير الإضافي" : "حدّث بالذكاء الاصطناعي"}
            icon="sparkles"
            variant={stage === "review" ? "secondary" : "primary"}
            onPress={apply}
            disabled={text.trim().length < 3}
          />
        </Section>
      ) : null}

      {error ? <Banner kind="error" text={error} /> : null}

      {busy ? (
        <Card>
          <Timeline steps={steps} />
          <Banner kind="info" text="خلّي APK Fact مفتوح لحد ما تخلص العملية." />
        </Card>
      ) : null}

      {stage === "review" ? (
        <>
          <Section title="المعاينة">
            {active.length > 1 ? (
              <View style={styles.chips}>
                {active.map((t) => (
                  <Chip key={t.name} label={roleLabel(t.name)} selected={shown === t.name} onPress={() => setShown(t.name)} />
                ))}
              </View>
            ) : null}
            <View style={styles.previewHead}>
              <Badge
                label={preview?.ai ? "معاينة فورية بالذكاء الاصطناعي" : "معاينة فورية من الكود الجديد"}
                color={preview?.ai ? colors.accent : colors.okText}
                icon={preview?.ai ? "sparkles" : "flash"}
              />
              <IconButton icon="expand-outline" label="ملء الشاشة" onPress={() => navigation.navigate("Preview", { name: shown })} />
            </View>
            <View style={styles.frame}>
              {preview ? (
                <WebView key={previewKey + shown} originWhitelist={["*"]} source={{ html: preview.html }} style={{ flex: 1, backgroundColor: colors.bg }} nestedScrollEnabled />
              ) : (
                <ActivityIndicator color={colors.accent} style={{ marginTop: space.xxl }} />
              )}
            </View>
          </Section>

          <Section title="التغييرات">
            <Card>
              {changes.map((c, i) => (
                <View key={i} style={styles.change}>
                  <Text style={styles.changeText}>{c}</Text>
                  <Ionicons name="checkmark-circle" size={18} color={colors.okText} />
                </View>
              ))}
            </Card>
          </Section>

          {vaultReady === false ? (
            <Banner
              kind="error"
              text="جهّز الخزنة الخاصة أولاً (الإعدادات > الخزنة الخاصة): هي اللي بتخلّي النسخة الجديدة تتثبّت فوق القديمة بدون ما تمسحها."
            />
          ) : null}
          <Button title="تم — انشر التحديث" icon="checkmark-done" onPress={publish} disabled={vaultReady !== true || !changes.length} />
          <Button title="تراجع عن التحديث" icon="arrow-undo-outline" variant="secondary" onPress={undo} style={{ marginTop: space.md }} />
        </>
      ) : null}

      {stage === "done" ? (
        <Card style={{ gap: space.md }}>
          <View style={styles.doneIcon}>
            <Ionicons name="rocket" size={34} color={colors.okText} />
          </View>
          <Text style={styles.doneTitle}>اتنشر التحديث</Text>
          {applied.map((t) => (
            <Text key={t.name} style={styles.doneText}>
              {roleLabel(t.name)}: الإصدار {version[t.name]?.versionName ?? version[t.name]?.version ?? "الجديد"}
            </Text>
          ))}
          <Text style={styles.doneText}>
            أي نسخة مثبّتة من {applied.length > 1 ? "التطبيقين" : "التطبيق"} بيظهر فيها إشعار «تحديث جديد متوفر» أول ما تتفتح، والمستخدم يضغط
            «تحديث» وتتنزّل النسخة الجديدة وتتثبّت فوق القديمة.
          </Text>
          <Banner
            kind="info"
            text="النسخ اللي اتثبّتت قبل الميزة دي ما فيها فاحص التحديثات: ثبّت الإصدار ده مرة واحدة يدوي، والتحديثات الجاية بتوصل بالإشعار."
          />
          <Button title="رجوع للمشروع" icon="arrow-forward" variant="secondary" onPress={() => navigation.goBack()} />
        </Card>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  head: { flexDirection: "row-reverse", alignItems: "center", gap: space.lg, marginBottom: space.lg },
  name: { fontSize: 20, fontWeight: "900", color: colors.text, textAlign: "right" },
  row: { flexDirection: "row-reverse", gap: 6, flexWrap: "wrap" },
  meta: { fontSize: 12, color: colors.textMuted, textAlign: "right" },
  hint: { ...type.hint, color: colors.textMuted, textAlign: "right", marginTop: space.sm },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginBottom: space.lg },
  previewHead: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: space.md },
  frame: {
    height: 520,
    borderRadius: radius.card,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  change: { flexDirection: "row-reverse", alignItems: "flex-start", gap: space.sm, paddingVertical: 6 },
  changeText: { flex: 1, color: colors.text, textAlign: "right", ...type.body },
  doneIcon: {
    alignSelf: "center",
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.okText + "22",
  },
  doneTitle: { fontSize: 22, fontWeight: "900", color: colors.text, textAlign: "center" },
  doneText: { ...type.body, color: colors.textMuted, textAlign: "right" },
});
