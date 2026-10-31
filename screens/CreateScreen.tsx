// New app wizard: start -> language -> details -> review, then a live progress timeline.
import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable, ScrollView, KeyboardAvoidingView, Platform } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import {
  Button,
  Card,
  Chip,
  Field,
  IconButton,
  ListRow,
  Stepper,
  Timeline,
  Banner,
  useSteps,
  IconName,
} from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import { TEMPLATES, Template } from "../services/templates";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { appExists, cleanName, generateApp, listApps, uploadCode, AppInfo } from "../services/appActions";
import { colors, langColors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";

type Start = "blank" | "template" | "paste";

const STEPS = ["البداية", "اللغة", "التفاصيل", "المراجعة"];

const LANG_PITCH: Record<Lang, string> = {
  html: "الأسرع في البناء. ممتاز للمتاجر والمنيو والصفحات التعريفية.",
  flutter: "أداء أصلي وتصميم Material 3 وحركات ناعمة. الأنسب للتطبيقات الكاملة.",
  python: "منطق قوي وحسابات وبيانات بلغة Python عبر Flet.",
};

// One tap adds (or removes) a feature sentence in the description.
const IDEAS: { label: string; icon: IconName; text: string }[] = [
  { label: "وضع ليلي", icon: "moon-outline", text: "زر للتبديل بين الوضع الفاتح والليلي." },
  { label: "بحث", icon: "search-outline", text: "بحث فوري في كل البيانات." },
  { label: "مفضلة", icon: "heart-outline", text: "إضافة العناصر للمفضلة وصفحة للمفضلة." },
  { label: "تسجيل دخول", icon: "person-outline", text: "شاشة تسجيل دخول وإنشاء حساب بسيطة." },
  { label: "إحصائيات", icon: "stats-chart-outline", text: "شاشة إحصائيات برسوم بيانية بسيطة." },
  { label: "واتساب", icon: "logo-whatsapp", text: "زر تواصل عبر واتساب." },
  { label: "تنبيهات", icon: "notifications-outline", text: "رسائل تنبيه داخل التطبيق بعد كل عملية." },
  { label: "مشاركة", icon: "share-social-outline", text: "زر لمشاركة العنصر مع الآخرين." },
];

function toggleIdea(text: string, idea: string) {
  return text.includes(idea) ? text.replace(idea, "").replace(/\s{2,}/g, " ").trim() : `${text.trim()} ${idea}`.trim();
}

export default function CreateScreen({ navigation, route }: RootScreenProps<"Create">) {
  const insets = useSafeAreaInsets();
  const preset = TEMPLATES.find((t) => t.id === route.params?.templateId);

  const [step, setStep] = useState(preset ? 2 : 0);
  const [start, setStart] = useState<Start>(preset ? "template" : "blank");
  const [template, setTemplate] = useState<Template | undefined>(preset);
  const [lang, setLang] = useState<Lang>(preset?.lang ?? "html");
  const [name, setName] = useState(preset?.name ?? "");
  const [text, setText] = useState(preset?.description ?? "");
  const [code, setCode] = useState("");
  const [related, setRelated] = useState("");
  const [apps, setApps] = useState<AppInfo[]>([]);
  const [nameTaken, setNameTaken] = useState<Lang | null>(null);
  const [phase, setPhase] = useState<"form" | "running" | "done" | "failed">("form");
  const [error, setError] = useState<string | null>(null);
  const [genSteps, genReport, genReset] = useSteps([
    ["send", "إرسال الطلب"],
    ["ai", "الذكاء الاصطناعي يكتب الكود ويفحص الأخطاء ويصلحها"],
    ["save", "حفظ التطبيق"],
  ]);
  const [pasteSteps, pasteReport, pasteReset] = useSteps([
    ["upload", "رفع الكود إلى GitHub"],
    ["send", "طلب معاينة بالذكاء الاصطناعي"],
    ["ai", "الذكاء الاصطناعي يجهّز المعاينة"],
  ]);

  useEffect(() => {
    listApps().then(setApps).catch(() => setApps([]));
  }, []);

  const clean = cleanName(name);
  useEffect(() => {
    setNameTaken(null);
    if (!clean) return;
    const t = setTimeout(() => appExists(clean).then(setNameTaken).catch(() => {}), 500);
    return () => clearTimeout(t);
  }, [clean]);

  function pickTemplate(t: Template) {
    setTemplate(t);
    setLang(t.lang);
    setName(t.name);
    setText(t.description);
  }

  const nameError = !name.trim()
    ? null
    : !clean
    ? "استخدم حروف إنجليزية وأرقام فقط"
    : nameTaken
    ? "الاسم مستخدم لتطبيق موجود. اختر اسم جديد، أو عدّل التطبيق من صفحته."
    : null;

  const canNext =
    step === 0
      ? start !== "template" || !!template
      : step === 2
      ? !!clean && !nameTaken && (start === "paste" ? code.trim().length > 20 : text.trim().length > 10)
      : true;

  async function submit() {
    setPhase("running");
    setError(null);
    try {
      if (start === "paste") {
        pasteReset();
        await uploadCode(clean, lang, code, pasteReport);
        if (!LANGS[lang].hasAiPreview) {
          pasteReport("send", "done", "تطبيقات HTML تُعرض كما هي");
          pasteReport("ai", "done");
        }
      } else {
        genReset();
        await generateApp({ name: clean, lang, text: text.trim(), kind: "create", related: related || undefined }, genReport);
      }
      setPhase("done");
    } catch (e: any) {
      setError(e.message);
      setPhase("failed");
    }
  }

  const footerPad = { paddingBottom: insets.bottom + space.md };
  let footer: React.ReactNode = null;
  if (phase === "form") {
    footer = (
      <View style={[styles.footer, footerPad]}>
        {step > 0 ? <Button title="رجوع" variant="secondary" onPress={() => setStep(step - 1)} style={{ flex: 1 }} /> : null}
        {step < 3 ? (
          <Button title="التالي" icon="arrow-back" onPress={() => setStep(step + 1)} disabled={!canNext} style={{ flex: 2 }} />
        ) : (
          <Button title="أنشئ التطبيق" icon="sparkles" onPress={submit} style={{ flex: 2 }} />
        )}
      </View>
    );
  } else if (phase === "failed") {
    footer = (
      <View style={[styles.footer, footerPad]}>
        <Button title="تعديل" variant="secondary" onPress={() => setPhase("form")} style={{ flex: 1 }} />
        <Button title="إعادة المحاولة" icon="refresh" onPress={submit} style={{ flex: 2 }} />
      </View>
    );
  } else if (phase === "done") {
    footer = (
      <View style={[styles.footer, footerPad]}>
        <Button title="معاينة" variant="secondary" icon="eye-outline" onPress={() => navigation.navigate("Preview", { name: clean })} style={{ flex: 1 }} />
        <Button title="افتح التطبيق" icon="arrow-back" onPress={() => navigation.replace("AppDetail", { name: clean, lang })} style={{ flex: 2 }} />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={styles.root} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <View style={[styles.top, { paddingTop: insets.top + space.md }]}>
        <View style={styles.topRow}>
          <Text style={styles.topTitle}>{phase === "form" ? "تطبيق جديد" : clean}</Text>
          <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        </View>
        {phase === "form" ? <Stepper steps={STEPS} current={step} /> : null}
      </View>

      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        {phase !== "form" ? (
          <>
            <Card style={styles.summary}>
              <AppAvatar name={clean} lang={lang} size={56} />
              <View style={{ flex: 1 }}>
                <Text style={styles.summaryName}>{clean}</Text>
                <LangBadge lang={lang} />
              </View>
            </Card>
            <Card>
              <Timeline steps={start === "paste" ? pasteSteps : genSteps} />
            </Card>
            {phase === "running" ? (
              <Banner kind="info" text="خليك هنا. الإنشاء بياخد من نصف دقيقة لأربع دقائق، والكود بيتفحص ويتصلّح تلقائياً." />
            ) : null}
            {phase === "done" ? <Banner kind="ok" text="التطبيق جاهز! شوف المعاينة أو افتح صفحته عشان تبنيه وتثبّته." /> : null}
            {phase === "failed" && error ? <Banner kind="error" text={error} /> : null}
          </>
        ) : step === 0 ? (
          <>
            <Text style={styles.q}>كيف تحب تبدأ؟</Text>
            <Card style={{ padding: 0, overflow: "hidden" }}>
              {(
                [
                  ["blank", "من الصفر", "صف فكرتك بكلماتك", "sparkles-outline"],
                  ["template", "من قالب", `${TEMPLATES.length} فكرة جاهزة تقدر تعدّلها`, "grid-outline"],
                  ["paste", "عندي كود جاهز", "الصق الكود ونجهّز له معاينة", "code-slash-outline"],
                ] as [Start, string, string, IconName][]
              ).map(([key, title, sub, icon], i) => (
                <ListRow
                  key={key}
                  icon={icon}
                  title={title}
                  subtitle={sub}
                  chevron={false}
                  last={i === 2}
                  right={
                    <Ionicons
                      name={start === key ? "radio-button-on" : "radio-button-off"}
                      size={22}
                      color={start === key ? colors.primary : colors.textMuted}
                    />
                  }
                  onPress={() => setStart(key)}
                />
              ))}
            </Card>
            {start === "template" ? (
              <View style={[styles.grid, { marginTop: space.md }]}>
                {TEMPLATES.map((t) => {
                  const sel = template?.id === t.id;
                  return (
                    <Pressable
                      key={t.id}
                      onPress={() => pickTemplate(t)}
                      style={[styles.tpl, sel && { borderColor: t.color, backgroundColor: t.color + "14" }]}
                      accessibilityRole="radio"
                      accessibilityState={{ selected: sel }}
                    >
                      <View style={[styles.tplIcon, { backgroundColor: t.color + "24" }]}>
                        <Ionicons name={t.icon} size={22} color={t.color} />
                      </View>
                      <Text style={styles.tplTitle} numberOfLines={1}>
                        {t.title}
                      </Text>
<View style={styles.tplFoot}>
                        <LangBadge lang={t.lang} />
                        <Pressable
                          onPress={() => navigation.navigate("InstantPreview", { templateId: t.id, fromWizard: true })}
                          hitSlop={8}
                          style={({ pressed }) => [styles.eye, pressed && { opacity: 0.7 }]}
                          accessibilityRole="button"
                          accessibilityLabel={`معاينة ${t.title}`}
                        >
                          <Ionicons name={t.lang === "html" ? "flash" : "eye-outline"} size={15} color={colors.infoText} />
                        </Pressable>
                      </View>
                      {sel ? (
                        <View style={styles.tplCheck}>
                          <Ionicons name="checkmark" size={14} color={colors.bg} />
                        </View>
                      ) : null}
                    </Pressable>
                  );
                })}
              </View>
            ) : null}
          </>
        ) : step === 1 ? (
          <>
            <Text style={styles.q}>بأي لغة نكتب التطبيق؟</Text>
            {LANG_ORDER.map((l) => {
              const sel = lang === l;
              return (
                <Pressable
                  key={l}
                  onPress={() => setLang(l)}
                  style={[styles.langCard, sel && { borderColor: langColors[l], backgroundColor: langColors[l] + "12" }]}
                  accessibilityRole="radio"
                  accessibilityState={{ selected: sel }}
                >
                  <View style={[styles.langIcon, { backgroundColor: langColors[l] + "22" }]}>
                    <Ionicons name={LANG_ICONS[l]} size={28} color={langColors[l]} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.langName}>{LANGS[l].label}</Text>
                    <Text style={styles.langPitch}>{LANG_PITCH[l]}</Text>
                    <Text style={styles.langTools}>{LANGS[l].tools}</Text>
                  </View>
                  <Ionicons name={sel ? "checkmark-circle" : "ellipse-outline"} size={24} color={sel ? langColors[l] : colors.border} />
                </Pressable>
              );
            })}
            {template && template.lang !== lang ? (
              <Banner kind="info" text={`القالب مصمم لـ ${LANGS[template.lang].label}، لكن تقدر تبنيه بـ ${LANGS[lang].label}.`} />
            ) : null}
          </>
        ) : step === 2 ? (
          <>
            <Field
              label="اسم التطبيق"
              icon="at-outline"
              value={name}
              onChangeText={setName}
              placeholder="مثال: myshop"
              ltr
              autoCapitalize="none"
              autoCorrect={false}
              error={nameError}
              helper={clean ? `بيتحفظ باسم apps/${clean}` : "حروف إنجليزية صغيرة وأرقام، بدون مسافات"}
              right={clean && !nameError ? <Ionicons name="checkmark-circle" size={18} color={colors.okText} /> : null}
            />
            {start === "paste" ? (
              <Field
                label={LANGS[lang].pasteLabel}
                icon="code-slash-outline"
                value={code}
                onChangeText={setCode}
                placeholder="الصق الكود هنا"
                multiline
                ltr
                autoCapitalize="none"
                autoCorrect={false}
                style={{ fontFamily: "monospace", fontSize: 12, minHeight: 220 }}
                helper={LANGS[lang].hasAiPreview ? "بعد الرفع بنجهّز معاينة حيّة بالذكاء الاصطناعي" : undefined}
              />
            ) : (
              <>
                <Field
                  label="وصف التطبيق"
                  icon="document-text-outline"
                  value={text}
                  onChangeText={setText}
                  placeholder="الشاشات، المميزات، الألوان، الجمهور… كل ما زادت التفاصيل، كان التطبيق أحسن"
                  multiline
                  maxLength={2000}
                  counter
                />
                <Button
                  title="معاينة فورية قبل الإنشاء"
                  icon={lang === "html" ? "flash-outline" : "sparkles-outline"}
                  variant="secondary"
                  disabled={text.trim().length < 10}
                  onPress={() =>
                    navigation.navigate("InstantPreview", {
                      lang,
                      description: text.trim(),
                      templateId: template && text === template.description ? template.id : undefined,
                      title: clean || "معاينة فورية",
                      fromWizard: true,
                    })
                  }
                />
                <Text style={styles.subq}>أضف ميزة بضغطة</Text>
                <View style={styles.chips}>
                  {IDEAS.map((idea) => (
                    <Chip
                      key={idea.label}
                      label={idea.label}
                      icon={idea.icon}
                      selected={text.includes(idea.text)}
                      onPress={() => setText((t) => toggleIdea(t, idea.text))}
                    />
                  ))}
                </View>
                {apps.length > 0 ? (
                  <>
                    <Text style={styles.subq}>جزء من مشروع؟ (اختياري)</Text>
                    <Text style={styles.subhint}>الذكاء الاصطناعي بيقرأ التطبيق المختار ويخلي الاثنين متناسقين.</Text>
                    <View style={styles.chips}>
                      <Chip label="لا" selected={!related} onPress={() => setRelated("")} />
                      {apps.map((a) => (
                        <Chip
                          key={a.name}
                          label={a.name}
                          icon={LANG_ICONS[a.lang]}
                          tint={langColors[a.lang]}
                          selected={related === a.name}
                          onPress={() => setRelated(a.name)}
                        />
                      ))}
                    </View>
                  </>
                ) : null}
              </>
            )}
          </>
        ) : (
          <>
            <Card style={styles.summary}>
              <AppAvatar name={clean} lang={lang} size={64} />
              <View style={{ flex: 1 }}>
                <Text style={styles.summaryName}>{clean}</Text>
                <LangBadge lang={lang} />
              </View>
            </Card>
            <Card style={{ padding: 0, overflow: "hidden" }}>
              <ListRow
                icon="flag-outline"
                title="البداية"
                value={start === "paste" ? "كود جاهز" : start === "template" ? template?.title ?? "قالب" : "من الصفر"}
              />
              <ListRow icon={LANG_ICONS[lang]} tint={langColors[lang]} title="اللغة" value={LANGS[lang].label} />
              {related ? <ListRow icon="link-outline" title="مرتبط بـ" value={related} /> : null}
              <ListRow
                icon={start === "paste" ? "code-slash-outline" : "document-text-outline"}
                title={start === "paste" ? "الكود" : "الوصف"}
                subtitle={start === "paste" ? `${code.split("\n").length} سطر` : text}
                onPress={() => setStep(2)}
                last
              />
            </Card>
            <Banner kind="info" text="بعد الإنشاء: الكود بيتفحص، والأخطاء المعروفة بتتصلّح تلقائياً، والجديدة بالذكاء الاصطناعي." />
          </>
        )}
      </ScrollView>
      {footer}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  top: { paddingHorizontal: space.lg },
  topRow: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: space.lg },
  topTitle: { ...type.screenTitle, fontSize: 24, fontWeight: "800", color: colors.text },
  body: { paddingHorizontal: space.lg, paddingBottom: space.xxl, gap: space.md },
  q: { ...type.sectionTitle, fontSize: 20, color: colors.text, textAlign: "right", marginBottom: space.sm },
  subq: { ...type.label, color: colors.text, textAlign: "right", marginTop: space.sm },
  subhint: { ...type.hint, color: colors.textMuted, textAlign: "right" },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginTop: space.sm, marginBottom: space.md },
  grid: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.md },
  tpl: {
    width: "47.8%",
    padding: space.md,
    gap: space.sm,
    borderRadius: radius.card,
    backgroundColor: colors.surface,
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  tplIcon: { width: 44, height: 44, borderRadius: 14, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" },
  tplTitle: { color: colors.text, fontWeight: "800", fontSize: 14, textAlign: "right" },
  tplFoot: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  eye: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.primarySoft,
  },
  tplCheck: {
    position: "absolute",
    top: space.sm,
    left: space.sm,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  langCard: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    padding: space.lg,
    borderRadius: radius.card,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  langIcon: { width: 54, height: 54, borderRadius: 18, alignItems: "center", justifyContent: "center" },
  langName: { fontSize: 18, fontWeight: "900", color: colors.text, textAlign: "right" },
  langPitch: { ...type.hint, color: colors.text, textAlign: "right", marginTop: 2 },
  langTools: { fontSize: 11.5, color: colors.textMuted, textAlign: "right", marginTop: 4 },
  summary: { flexDirection: "row-reverse", alignItems: "center", gap: space.lg },
  summaryName: { fontSize: 20, fontWeight: "900", color: colors.text, textAlign: "right", marginBottom: 6 },
  footer: {
    flexDirection: "row-reverse",
    gap: space.md,
    paddingHorizontal: space.lg,
    paddingTop: space.md,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
