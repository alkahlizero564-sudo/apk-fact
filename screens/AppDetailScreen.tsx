import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Alert, Image } from "react-native";
import * as ImagePicker from "expo-image-picker";
import {
  Screen,
  Card,
  Section,
  ListRow,
  Button,
  Sheet,
  Field,
  Chip,
  Timeline,
  Banner,
  useSteps,
} from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import {
  generateApp,
  makeAiPreview,
  uploadCode,
  uploadIcon,
  buildAndInstall,
  deleteApp,
  listApps,
  AppInfo,
  Report,
} from "../services/appActions";
import { linkAppsViaSupabase } from "../services/link";
import { LANGS } from "../services/langs";
import { colors, langColors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";

type Op = "edit" | "aiPreview" | "paste" | "build";

const EDIT_IDEAS = [
  "غيّر الألوان لدرجات أهدأ",
  "أضف وضع ليلي",
  "حسّن الشاشة الرئيسية",
  "أضف شاشة إعدادات",
  "كبّر الخطوط والأزرار",
  "أضف أنيميشن خفيف",
];

export default function AppDetailScreen({ navigation, route }: RootScreenProps<"AppDetail">) {
  const { name, lang } = route.params;
  const info = LANGS[lang];

  const [sheet, setSheet] = useState<null | "edit" | "paste" | "link" | "progress">(null);
  const [op, setOp] = useState<Op | null>(null);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const [editText, setEditText] = useState("");
  const [pasteText, setPasteText] = useState("");
  const [iconUri, setIconUri] = useState<string | null>(null);
  const [iconBusy, setIconBusy] = useState(false);
  const [others, setOthers] = useState<AppInfo[]>([]);
  const [linkTo, setLinkTo] = useState("");
  const [linkLog, setLinkLog] = useState<string[]>([]);
  const [linking, setLinking] = useState(false);

  const [genSteps, genReport, genReset] = useSteps([
    ["send", "إرسال طلب التعديل"],
    ["ai", "الذكاء الاصطناعي يعدّل ويفحص الأخطاء ويصلحها"],
    ["save", "حفظ التعديل"],
  ]);
  const [prevSteps, prevReport, prevReset] = useSteps([
    ["upload", "رفع الكود"],
    ["send", "طلب المعاينة"],
    ["ai", "الذكاء الاصطناعي يجهّز المعاينة"],
  ]);
  const [buildSteps, buildReport, buildReset] = useSteps([
    ["start", "تجهيز البناء"],
    ["build", "البناء على GitHub (مع إصلاح الأخطاء تلقائياً)"],
    ["download", "تنزيل الـ APK"],
    ["install", "فتح شاشة التثبيت"],
  ]);

  useEffect(() => {
    listApps()
      .then((a) => setOthers(a.filter((x) => x.name !== name && x.lang === "html")))
      .catch(() => {});
  }, [name]);

  async function runOp(kind: Op, fn: (report: Report) => Promise<unknown>, done: string) {
    setOp(kind);
    setResult(null);
    setRunning(true);
    setSheet("progress");
    try {
      await fn(kind === "build" ? buildReport : kind === "edit" ? genReport : prevReport);
      setResult({ kind: "ok", text: done });
    } catch (e: any) {
      setResult({ kind: "error", text: e.message });
    } finally {
      setRunning(false);
    }
  }

  function startEdit() {
    const text = editText.trim();
    if (!text) return;
    genReset();
    runOp("edit", (r) => generateApp({ name, lang, text, kind: "edit" }, r), "اتعدّل التطبيق. افتح المعاينة تشوف التغيير.").then(() =>
      setEditText("")
    );
  }

  function startAiPreview() {
    prevReset();
    prevReport("upload", "done", "الكود موجود");
    runOp("aiPreview", (r) => makeAiPreview(name, lang, r), "المعاينة الجديدة جاهزة.");
  }

  function startPaste() {
    const code = pasteText.trim();
    if (code.length < 20) return;
    prevReset();
    runOp(
      "paste",
      async (r) => {
        await uploadCode(name, lang, code, r);
        if (!info.hasAiPreview) {
          r("send", "done");
          r("ai", "done", "تطبيقات HTML تُعرض كما هي");
        }
      },
      "ارتفع الكود."
    ).then(() => setPasteText(""));
  }

  function startBuild() {
    buildReset();
    runOp("build", (r) => buildAndInstall(name, lang, r), "اكتمل. اضغط تثبيت في شاشة أندرويد.");
  }

  async function pickIcon() {
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
      base64: true,
    });
    const asset = res.canceled ? null : res.assets?.[0];
    if (!asset?.base64) return;
    setIconBusy(true);
    try {
      await uploadIcon(name, asset.base64);
      setIconUri(asset.uri);
      Alert.alert("تم", "الأيقونة الجديدة بتظهر في البناء الجاي.");
    } catch (e: any) {
      Alert.alert("ما قدرنا نرفع الأيقونة", e.message);
    } finally {
      setIconBusy(false);
    }
  }

  function confirmDelete() {
    Alert.alert("حذف التطبيق", `متأكد تبغى تحذف "${name}"؟ ما يمكن التراجع.`, [
      { text: "إلغاء", style: "cancel" },
      {
        text: "حذف",
        style: "destructive",
        onPress: async () => {
          try {
            await deleteApp(name);
            navigation.goBack();
          } catch (e: any) {
            Alert.alert("ما قدرنا نحذف", e.message);
          }
        },
      },
    ]);
  }

  async function doLink() {
    if (!linkTo) return;
    setLinking(true);
    setLinkLog([]);
    const add = (s: string) => setLinkLog((p) => [...p, s]);
    try {
      const r = await linkAppsViaSupabase(name, linkTo, add);
      add("✅ اتعاد كتابة التطبيقين وارتفعوا.");
      if (r.tables.length) add(`🗄️ الجداول: ${r.tables.join("، ")}`);
    } catch (e: any) {
      add(`❌ ${e.message}`);
    } finally {
      setLinking(false);
    }
  }

  const progressSteps = op === "build" ? buildSteps : op === "edit" ? genSteps : prevSteps;
  const progressTitle =
    op === "build" ? "بناء وتثبيت" : op === "edit" ? "تعديل بالذكاء الاصطناعي" : op === "paste" ? "رفع الكود" : "معاينة جديدة";

  return (
    <Screen title={name} subtitle={info.tools} onBack={() => navigation.goBack()}>
      <Card style={styles.hero}>
        {iconUri ? (
          <Image source={{ uri: iconUri }} style={styles.icon} />
        ) : (
          <AppAvatar name={name} lang={lang} size={76} />
        )}
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={styles.name}>{name}</Text>
          <LangBadge lang={lang} />
          <Text style={styles.path}>apps/{name}</Text>
        </View>
      </Card>

      <View style={styles.actions}>
        <Button title="معاينة" icon="eye-outline" variant="secondary" onPress={() => navigation.navigate("Preview", { name })} style={{ flex: 1 }} />
        <Button title="ابنِ وثبّت" icon="download-outline" onPress={startBuild} disabled={running} style={{ flex: 1 }} />
      </View>

      <Section title="تطوير">
        <Card style={styles.list}>
          <ListRow
            icon="sparkles-outline"
            tint={colors.accent}
            title="تعديل بالذكاء الاصطناعي"
            subtitle="صف التغيير اللي تبغاه، والكود بيتعدّل ويتفحص"
            onPress={() => setSheet("edit")}
          />
          {info.hasAiPreview ? (
            <ListRow
              icon="color-wand-outline"
              title="معاينة جديدة بالذكاء الاصطناعي"
              subtitle="إعادة توليد المعاينة الحيّة من الكود الحالي"
              onPress={startAiPreview}
            />
          ) : null}
          <ListRow icon="code-slash-outline" title="لصق كود جاهز" subtitle={info.pasteLabel} onPress={() => setSheet("paste")} />
          <ListRow
            icon="image-outline"
            title={iconBusy ? "بيترفع…" : "أيقونة التطبيق"}
            subtitle="اختيار صورة من المعرض"
            onPress={iconBusy ? undefined : pickIcon}
            last
          />
        </Card>
      </Section>

      {lang === "html" ? (
        <Section title="مشروع">
          <Card style={styles.list}>
            <ListRow
              icon="git-merge-outline"
              tint="#34D399"
              title="ربط مع تطبيق آخر"
              subtitle="قاعدة بيانات مشتركة عبر Supabase"
              onPress={() => setSheet("link")}
              last
            />
          </Card>
        </Section>
      ) : null}

      <Section title="منطقة الخطر">
        <Card style={styles.list}>
          <ListRow icon="trash-outline" title="حذف التطبيق" subtitle="يحذف كل ملفاته من GitHub" danger onPress={confirmDelete} last />
        </Card>
      </Section>

      <Sheet visible={sheet === "edit"} title="تعديل بالذكاء الاصطناعي" onClose={() => setSheet(null)}>
        <Field
          label="شنو التغيير؟"
          icon="create-outline"
          value={editText}
          onChangeText={setEditText}
          placeholder="مثال: غيّر الألوان للأخضر وأضف زر واتساب في الصفحة الرئيسية"
          multiline
          maxLength={1500}
          counter
        />
        <View style={styles.chips}>
          {EDIT_IDEAS.map((i) => (
            <Chip key={i} label={i} onPress={() => setEditText((t) => `${t.trim()} ${i}.`.trim())} />
          ))}
        </View>
        <Button title="نفّذ التعديل" icon="sparkles" onPress={startEdit} disabled={editText.trim().length < 3} />
      </Sheet>

      <Sheet visible={sheet === "paste"} title="لصق كود جاهز" onClose={() => setSheet(null)}>
        <Field
          label={info.pasteLabel}
          icon="code-slash-outline"
          value={pasteText}
          onChangeText={setPasteText}
          placeholder="الصق الكود هنا"
          multiline
          ltr
          autoCapitalize="none"
          autoCorrect={false}
          style={{ fontFamily: "monospace", fontSize: 12, minHeight: 200 }}
          helper="الكود الحالي بيتبدّل بالكود ده"
        />
        <Button title="ارفع الكود" icon="cloud-upload-outline" onPress={startPaste} disabled={pasteText.trim().length < 20} />
      </Sheet>

      <Sheet visible={sheet === "link"} title="ربط مع تطبيق آخر" onClose={() => setSheet(null)}>
        <Text style={styles.sheetText}>
          بنصمم جداول مشتركة في Supabase ونعيد كتابة التطبيقين عشان يقروا ويكتبوا نفس البيانات. التطبيقين القدام بيتغيروا.
        </Text>
        {others.length === 0 ? (
          <Banner kind="info" text="محتاج تطبيق HTML ثاني عشان تربطه." />
        ) : (
          <View style={styles.chips}>
            {others.map((a) => (
              <Chip
                key={a.name}
                label={a.name}
                icon={LANG_ICONS[a.lang]}
                tint={langColors[a.lang]}
                selected={linkTo === a.name}
                onPress={() => setLinkTo(a.name)}
              />
            ))}
          </View>
        )}
        <Button title="اربط التطبيقين" icon="git-merge-outline" onPress={doLink} loading={linking} disabled={!linkTo} />
        {linkLog.length ? (
          <View style={styles.log}>
            {linkLog.map((l, i) => (
              <Text key={i} style={styles.logLine}>
                {l}
              </Text>
            ))}
          </View>
        ) : null}
      </Sheet>

      <Sheet visible={sheet === "progress"} title={progressTitle} onClose={() => setSheet(null)}>
        <Timeline steps={progressSteps} />
        {running ? <Banner kind="info" text="تقدر تقفل النافذة، والعملية بتكمل. خلّي التطبيق مفتوح." /> : null}
        {result ? <Banner kind={result.kind} text={result.text} /> : null}
        {result?.kind === "ok" && op !== "build" ? (
          <Button
            title="افتح المعاينة"
            icon="eye-outline"
            variant="secondary"
            onPress={() => {
              setSheet(null);
              navigation.navigate("Preview", { name });
            }}
            style={{ marginTop: space.md }}
          />
        ) : null}
      </Sheet>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { flexDirection: "row-reverse", alignItems: "center", gap: space.lg, marginBottom: space.md },
  icon: { width: 76, height: 76, borderRadius: 22 },
  name: { fontSize: 24, fontWeight: "900", color: colors.text, textAlign: "right" },
  path: { fontSize: 12, color: colors.textMuted, textAlign: "right", fontFamily: "monospace" },
  actions: { flexDirection: "row-reverse", gap: space.md, marginBottom: space.xl },
  list: { padding: 0, overflow: "hidden" },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginBottom: space.lg },
  sheetText: { ...type.body, color: colors.textMuted, textAlign: "right", marginBottom: space.lg },
  log: { marginTop: space.lg, padding: space.md, borderRadius: radius.field, backgroundColor: colors.field, gap: 4 },
  logLine: { fontSize: 13, color: colors.text, textAlign: "right" },
});
