// The "did I understand you?" stage: shows the requirements the AI understood from the owner's idea and its
// questions. The owner removes what is wrong, answers, writes corrections, and approves. The parent calls
// approve() (through the ref) from its footer button; it applies pending answers first.
import { refImages } from "../services/attachment";
import React, { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { View, Text, StyleSheet, ActivityIndicator } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Ionicons } from "@expo/vector-icons";
import { Button, Card, Chip, Field, Banner, IconButton } from "./ui";
import { Spec, ListKey, LIST_TITLES, understandIdea, refineSpec, permLabel, IdeaTarget } from "../services/understand";
import { colors, space, radius, type } from "../theme";

type Target = IdeaTarget;
export type UnderstandHandle = { approve: () => Promise<Spec | null> };

function hash(s: string) {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}
// The list survives closing APK Fact; it belongs to one name + language + description.
const cacheKey = (t: Target) => `understand:${hash(`${t.lang}|${t.pair ? "pair|" : ""}${t.title}|${t.description}`)}`;

const ICONS: Record<ListKey, React.ComponentProps<typeof Ionicons>["name"]> = {
  screens: "phone-portrait-outline",
  features: "checkmark-done-outline",
  data: "server-outline",
  texts: "text-outline",
};

const UnderstandStudio = forwardRef<UnderstandHandle, { target: Target; onBusy?: (busy: boolean) => void }>(
  function UnderstandStudio({ target, onBusy }, ref) {
    const [spec, setSpec] = useState<Spec | null>(null);
    const [answers, setAnswers] = useState<Record<number, string>>({});
    const [notes, setNotes] = useState("");
    const [busy, setBusy] = useState(false);
    const [status, setStatus] = useState("");
    const [error, setError] = useState<string | null>(null);
    const started = useRef("");

    useEffect(() => onBusy?.(busy), [busy]);

    function keep(s: Spec) {
      setSpec(s);
      setAnswers({});
      setNotes("");
      AsyncStorage.setItem(cacheKey(target), JSON.stringify(s)).catch(() => {});
    }

    async function run(fn: () => Promise<Spec>) {
      setBusy(true);
      setError(null);
      try {
        const s = await fn();
        keep(s);
        return s;
      } catch (e: any) {
        setError(e.message);
        return null;
      } finally {
        setBusy(false);
        setStatus("");
      }
    }

    const understand = () => run(() => understandIdea(target, setStatus, refImages()));

    useEffect(() => {
      const k = cacheKey(target);
      if (started.current === k) return;
      started.current = k;
      AsyncStorage.getItem(k)
        .then((v) => {
          if (v) setSpec(JSON.parse(v));
          else understand();
        })
        .catch(() => understand());
    }, [target.title, target.description, target.lang, target.pair]);

    const answerList = () =>
      (spec?.questions ?? [])
        .map((q, i) => ({ q: q.q, a: (answers[i] ?? "").trim() }))
        .filter((x) => x.a);
    const pending = answerList().length > 0 || notes.trim().length > 0;

    const apply = () => (spec ? run(() => refineSpec(target, spec, answerList(), notes, setStatus)) : Promise.resolve(null));

    useImperativeHandle(ref, () => ({
      approve: async () => {
        if (!spec || busy) return null;
        const s = pending ? await apply() : spec;
        return s ? { ...s, questions: [] } : null;
      },
    }));

    function removeItem(k: ListKey, i: number) {
      if (!spec) return;
      keep({ ...spec, [k]: spec[k].filter((_, j) => j !== i) });
    }

    if (!spec) {
      return busy || !error ? (
        <Card style={styles.center}>
          <ActivityIndicator color={colors.primary} />
          <Text style={styles.status}>{status || "الذكاء الاصطناعي بيقرأ فكرتك…"}</Text>
        </Card>
      ) : (
        <>
          <Banner kind="error" text={error} />
          <Button title="حاول تاني" icon="refresh" onPress={understand} />
        </>
      );
    }

    return (
      <View style={{ gap: space.md, opacity: busy ? 0.6 : 1 }} pointerEvents={busy ? "none" : "auto"}>
        {spec.summary ? (
          <Card style={styles.summary}>
            <Ionicons name="bulb-outline" size={22} color={colors.accent} />
            <Text style={styles.summaryText}>{spec.summary}</Text>
          </Card>
        ) : null}

        {spec.questions.length ? (
          <Card style={{ gap: space.md }}>
            <Text style={styles.cardTitle}>عندي أسئلة قصيرة</Text>
            {spec.questions.map((q, i) => (
              <View key={i} style={{ gap: space.xs }}>
                <Text style={styles.question}>{q.q}</Text>
                <View style={styles.chips}>
                  {q.options.map((o) => (
                    <Chip
                      key={o}
                      label={o}
                      selected={answers[i] === o}
                      onPress={() => setAnswers((a) => ({ ...a, [i]: a[i] === o ? "" : o }))}
                    />
                  ))}
                </View>
                <Field
                  label="أو اكتب إجابتك"
                  value={q.options.includes(answers[i] ?? "") ? "" : answers[i] ?? ""}
                  onChangeText={(v) => setAnswers((a) => ({ ...a, [i]: v }))}
                  placeholder="إجابة تانية"
                />
              </View>
            ))}
            <Text style={styles.hint}>اللي ما تجاوبه، الذكاء الاصطناعي بيختار له الأنسب لفكرتك.</Text>
          </Card>
        ) : null}

        {(Object.keys(LIST_TITLES) as ListKey[]).map((k) =>
          spec[k].length ? (
            <Card key={k} style={{ gap: space.sm }}>
              <View style={styles.titleRow}>
                <Ionicons name={ICONS[k]} size={18} color={colors.primary} />
                <Text style={styles.cardTitle}>{LIST_TITLES[k]}</Text>
              </View>
              {spec[k].map((item, i) => (
                <View key={`${k}${i}`} style={styles.item}>
                  <Text style={styles.itemText}>• {item}</Text>
                  <IconButton icon="close" label="احذف" tint={colors.textMuted} onPress={() => removeItem(k, i)} />
                </View>
              ))}
            </Card>
          ) : null
        )}

        {spec.permissions.length ? (
          <Card style={{ gap: space.sm }}>
            <View style={styles.titleRow}>
              <Ionicons name="key-outline" size={18} color={colors.primary} />
              <Text style={styles.cardTitle}>الصلاحيات</Text>
            </View>
            <View style={styles.chips}>
              {spec.permissions.map((p) => (
                <Chip
                  key={p}
                  label={permLabel(p)}
                  icon="close"
                  selected
                  onPress={() => keep({ ...spec, permissions: spec.permissions.filter((x) => x !== p) })}
                />
              ))}
            </View>
          </Card>
        ) : null}

        <Field
          label="تبغى تضيف أو تصحّح حاجة؟"
          icon="create-outline"
          value={notes}
          onChangeText={setNotes}
          placeholder="مثال: الأسعار بالجنيه، وأضف شاشة للعروض، وشيل تسجيل الدخول"
          multiline
          maxLength={1500}
        />
        {busy ? (
          <View style={styles.busyRow}>
            <ActivityIndicator color={colors.primary} />
            <Text style={styles.status}>{status}</Text>
          </View>
        ) : null}
        {error ? <Banner kind="error" text={error} /> : null}
        <View style={{ flexDirection: "row-reverse", gap: space.sm }}>
          <Button
            title="حدّث القائمة"
            icon="refresh"
            variant="secondary"
            onPress={apply}
            disabled={!pending || busy}
            style={{ flex: 2 }}
          />
          <Button title="من جديد" icon="reload" variant="secondary" onPress={understand} disabled={busy} style={{ flex: 1 }} />
        </View>
      </View>
    );
  }
);

export default UnderstandStudio;

const styles = StyleSheet.create({
  center: { alignItems: "center", gap: space.md, paddingVertical: space.xl },
  status: { ...type.hint, color: colors.textMuted, textAlign: "center" },
  busyRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm, justifyContent: "center" },
  summary: { flexDirection: "row-reverse", gap: space.md, alignItems: "flex-start", borderColor: colors.accent + "55" },
  summaryText: { ...type.body, color: colors.text, textAlign: "right", flex: 1 },
  cardTitle: { ...type.label, color: colors.text, textAlign: "right" },
  titleRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm },
  question: { ...type.body, color: colors.text, textAlign: "right", fontWeight: "600" },
  hint: { ...type.hint, color: colors.textMuted, textAlign: "right" },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm },
  item: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.field,
    paddingVertical: space.xs,
    paddingHorizontal: space.md,
  },
  itemText: { ...type.body, color: colors.text, textAlign: "right", flex: 1 },
});
