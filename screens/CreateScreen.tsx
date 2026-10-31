import React, { useState } from "react";
import {
  View, TextInput, Text, TouchableOpacity, StyleSheet,
  ScrollView, ActivityIndicator, Modal, Image, Alert,
} from "react-native";
import { WebView } from "react-native-webview";
import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import * as SecureStore from "expo-secure-store";
import { pushFile, pushBase64File, listWorkflowRuns, latestRunId, getFileText, getFailureLog } from "../services/github";
import { REPO } from "../services/config";
import { linkAppsViaSupabase } from "../services/link";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { Card, Button } from "../components/ui";
import { colors, langColors, space, radius, type } from "../theme";

type IconName = React.ComponentProps<typeof Ionicons>["name"];

const LANG_ICONS: Record<Lang, IconName> = {
  html: "logo-html5",
  flutter: "layers-outline",
  python: "logo-python",
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function cleanName(n: string) {
  return n.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
}

async function waitForRun(prevId: number, workflow: string = "generate.yml") {
  const started = Date.now();
  while (Date.now() - started < 6 * 60 * 1000) {
    await sleep(5000);
    const runs = await listWorkflowRuns(REPO, workflow);
    const run = runs.find((r: any) => r.id > prevId);
    if (run && run.status === "completed") return run;
  }
  return null;
}

type Kind = "create" | "edit";

function LogBox({ lines }: { lines: string[] }) {
  if (lines.length === 0) return null;
  return (
    <View style={styles.logBox}>
      {lines.map((line, i) => (
        <Text key={i} style={styles.logLine}>{line}</Text>
      ))}
    </View>
  );
}

function RowButton({
  label,
  icon,
  onPress,
  disabled,
  dim,
  left,
  right,
}: {
  label: string;
  icon?: IconName;
  onPress: () => void;
  disabled?: boolean;
  dim?: boolean;
  left?: React.ReactNode;
  right?: React.ReactNode;
}) {
  return (
    <TouchableOpacity
      style={[styles.rowBtn, dim && styles.disabled]}
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
    >
      {left ?? (icon ? (
        <View style={styles.rowIcon}>
          <Ionicons name={icon} size={18} color={colors.infoText} />
        </View>
      ) : null)}
      <Text style={styles.rowBtnText}>{label}</Text>
      {right}
    </TouchableOpacity>
  );
}

function Chevron({ open }: { open: boolean }) {
  return <Ionicons name={open ? "chevron-up" : "chevron-down"} size={18} color={colors.textMuted} />;
}

function LangPicker({ value, onChange, disabled }: { value: Lang; onChange: (l: Lang) => void; disabled: boolean }) {
  return (
    <View>
      <View style={styles.langRow} accessibilityRole="radiogroup">
        {LANG_ORDER.map((l) => {
          const active = value === l;
          const tint = langColors[l];
          return (
            <TouchableOpacity
              key={l}
              style={[styles.langCard, active && { borderColor: tint, backgroundColor: colors.surfaceAlt }]}
              onPress={() => onChange(l)}
              disabled={disabled}
              accessibilityRole="radio"
              accessibilityState={{ selected: active, disabled }}
              accessibilityLabel={LANGS[l].label}
            >
              <Ionicons name={LANG_ICONS[l]} size={24} color={active ? tint : colors.textMuted} />
              <Text style={[styles.langText, active && { color: colors.text }]}>{LANGS[l].label}</Text>
            </TouchableOpacity>
          );
        })}
      </View>
      <View style={styles.toolsLine}>
        <Ionicons name="code-slash-outline" size={14} color={langColors[value]} />
        <Text style={styles.toolsText}>{LANGS[value].tools}</Text>
      </View>
      {LANGS[value].hasAiPreview && (
        <View style={styles.toolsLine}>
          <Ionicons name="sparkles-outline" size={14} color={colors.accent} />
          <Text style={styles.toolsText}>معاينة حيّة بالذكاء الاصطناعي قبل بناء الـ APK</Text>
        </View>
      )}
    </View>
  );
}

type BoxProps = {
  title: string;
  busy: boolean;
  setBusy: (b: boolean) => void;
  onPreview: (name: string) => void;
  onNameChange?: (name: string) => void;
  isSecond?: boolean;
  relatedName?: string;
};

function AppBox({ title, busy, setBusy, onPreview, onNameChange, isSecond, relatedName }: BoxProps) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [editOpen, setEditOpen] = useState(false);
  const [editText, setEditText] = useState("");
  const [pasteOpen, setPasteOpen] = useState(false);
  const [pasteText, setPasteText] = useState("");
  const [iconUri, setIconUri] = useState<string | null>(null);
  const [useRelated, setUseRelated] = useState(true);
  const [lang, setLang] = useState<Lang>("html");
  const [loading, setLoading] = useState<Kind | "paste" | "icon" | "preview" | null>(null);
  const [log, setLog] = useState<string[]>([]);

  function addLog(line: string) {
    setLog((prev) => [...prev, line]);
  }

  async function pickIcon() {
    if (busy) return;
    const n = cleanName(name);
    if (!n) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي الأول، وبعدين اختار الأيقونة."]);
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
      base64: true,
    });
    if (result.canceled || !result.assets || !result.assets[0]) return;
    const asset = result.assets[0];
    if (!asset.base64) {
      setLog(["❌ ما قدرت أقرأ الصورة. جرّب صورة تانية."]);
      return;
    }

    setLog([]);
    setBusy(true);
    setLoading("icon");
    try {
      addLog("⏳ بتترفع الأيقونة على GitHub...");
      await pushBase64File(REPO, `apps/${n}/icon.png`, asset.base64, `Set icon: ${n}`);
      setIconUri(asset.uri);
      addLog(`✅ ارتفعت الأيقونة: apps/${n}/icon.png`);
      addLog("🎉 المرة الجاية تبني APK للتطبيق ده، بتظهر الأيقونة دي.");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(null);
      setBusy(false);
    }
  }

  // Ask the generate workflow to (re)build preview.html from the app's current code.
  async function makeAiPreview(n: string) {
    const info = LANGS[lang];
    const prevId = await latestRunId(REPO, info.generateWorkflow);
    addLog("✨ الذكاء الاصطناعي بيجهّز معاينة حيّة للكود...");
    await pushFile(REPO, info.requestFile, `${n}\n@preview\n\n(request id: ${Date.now()})\n`, `Preview: ${n}`);
    const r = await waitForRun(prevId, info.generateWorkflow);
    if (!r) {
      addLog("⚠️ المعاينة أخذت وقت طويل. جرّب زر معاينة بعد شوية.");
      return;
    }
    if (r.conclusion !== "success") {
      addLog("❌ فشل تجهيز المعاينة.");
      const tail = await getFailureLog(REPO, r.id);
      if (tail) addLog(tail);
      return;
    }
    addLog("✅ المعاينة جاهزة. اضغط معاينة تشوفها.");
  }

  async function regeneratePreview() {
    if (busy) return;
    const n = cleanName(name);
    if (!n) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي الأول."]);
      return;
    }
    setLog([]);
    setBusy(true);
    setLoading("preview");
    try {
      if (!(await getFileText(REPO, LANGS[lang].mainFile(n)))) {
        addLog(`❌ ما لقيت كود ${LANGS[lang].label} للتطبيق ده. اعمل إنشاء أو الصق الكود الأول.`);
        return;
      }
      await makeAiPreview(n);
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(null);
      setBusy(false);
    }
  }

  async function uploadPastedCode() {
    if (busy) return;
    const n = cleanName(name);
    const code = pasteText.trim();
    if (!n) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي (حروف وأرقام بدون مسافات)."]);
      return;
    }
    if (!code) {
      setLog(["❌ الصق الكود الأول."]);
      return;
    }

    setLog([]);
    setBusy(true);
    setLoading("paste");
    try {
      addLog("⏳ بيترفع الكود على GitHub...");
      const target = LANGS[lang].mainFile(n);
      await pushFile(REPO, target, code + "\n", `Upload code: ${n}`);
      addLog(`✅ ارتفع الكود: ${target}`);
      setPasteText("");
      if (LANGS[lang].hasAiPreview) await makeAiPreview(n);
      else addLog("🎉 اضغط معاينة تشوفه.");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(null);
      setBusy(false);
    }
  }

  async function run(kind: Kind) {
    if (busy) return;
    const n = cleanName(name);
    const text = (kind === "create" ? description : editText).trim();
    if (!n) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي (حروف وأرقام بدون مسافات)."]);
      return;
    }
    if (!text) {
      setLog([kind === "create" ? "❌ اكتب الوصف." : "❌ اكتب وصف التعديل."]);
      return;
    }

    const info = LANGS[lang];
    const isNative = lang !== "html";
    const workflow = info.generateWorkflow;
    const requestFile = info.requestFile;
    const mainFile = info.mainFile(n);

    setLog([]);
    setBusy(true);
    setLoading(kind);
    try {
      if (kind === "edit") {
        const existing = await getFileText(REPO, mainFile);
        if (!existing) {
          addLog("❌ التطبيق ده مش موجود. اعمل إنشاء الأول.");
          return;
        }
      }

      const rel = relatedName && useRelated && relatedName !== n ? relatedName : "";
      if (rel) {
        let relExists = false;
        for (const l of LANG_ORDER) {
          if (await getFileText(REPO, LANGS[l].mainFile(rel))) {
            relExists = true;
            break;
          }
        }
        if (relExists) {
          addLog(`🔗 الذكاء الاصطناعي بيقرأ التطبيق الأول (${rel}) قبل ما يبني.`);
        } else {
          addLog(`⚠️ التطبيق الأول (${rel}) ما لقيتو في GitHub، فبيتبني التطبيق ده براهو.`);
        }
      }

      const prevId = await latestRunId(REPO, workflow);

      addLog("⏳ بيتم إرسال الطلب...");
      const relLine = rel ? `@related: ${rel}\n` : "";
      const model = isNative ? (await SecureStore.getItemAsync("GEMINI_MODEL")) ?? "" : "";
      const modelLine = model ? `@model: ${model}\n` : "";
      const content = `${n}\n${relLine}${modelLine}${text}\n\n(request id: ${Date.now()})\n`;
      await pushFile(REPO, requestFile, content, `${kind === "edit" ? "Edit" : "Create"}: ${n}`);
      addLog("✅ تم إرسال الطلب.");
      addLog(kind === "edit" ? "⏳ بيتعدّل الكود... (من نصف دقيقة لأربع دقايق)" : "⏳ بيتولّد الكود... (من نصف دقيقة لأربع دقايق)");
      if (isNative) addLog("✨ ومعاه معاينة حيّة بالذكاء الاصطناعي.");

      const r = await waitForRun(prevId, workflow);
      if (!r) {
        addLog("⚠️ أخذ وقت طويل. جرّب المعاينة بعد شوية.");
        return;
      }
      if (r.conclusion !== "success") {
        addLog("❌ فشل.");
        const tail = await getFailureLog(REPO, r.id);
        if (tail) addLog(tail);
        return;
      }

      const code = await getFileText(REPO, mainFile);
      if (!code) {
        addLog("⚠️ نجح لكن الملف ما ظهر. جرّب المعاينة بعد شوية.");
        return;
      }
      addLog(kind === "edit" ? `✅ اتعدّل وارتفع: ${mainFile}` : `✅ اتولّد وارتفع: ${mainFile}`);
      addLog(isNative ? "🎉 اضغط معاينة تشوف المعاينة الحيّة." : "🎉 اضغط معاينة تشوفه.");
      if (kind === "edit") setEditText("");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(null);
      setBusy(false);
    }
  }

  const hasName = !!cleanName(name);

  return (
    <Card style={styles.box}>
      <Text style={styles.boxTitle}>{title}</Text>

      <Text style={styles.label}>اسم التطبيق (إنجليزي)</Text>
      <TextInput
        style={styles.input}
        value={name}
        onChangeText={(t) => {
          setName(t);
          setIconUri(null);
          if (onNameChange) onNameChange(t);
        }}
        placeholder="مثال: shop"
        placeholderTextColor={colors.textMuted}
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Text style={styles.hint}>للإنشاء استخدم اسم جديد. للتعديل على تطبيق موجود استخدم زر تعديل الكود.</Text>

      {isSecond && (
        <TouchableOpacity style={styles.relatedBtn} onPress={() => setUseRelated(!useRelated)}>
          <Text style={styles.relatedText}>
            {useRelated ? "✅" : "⬜"} اقرأ التطبيق الأول قبل ما تبني ده (مشروع واحد)
          </Text>
          {useRelated && !relatedName && (
            <Text style={styles.relatedWarn}>اكتب اسم التطبيق الأول في صندوقو فوق عشان يشتغل الربط.</Text>
          )}
          {useRelated && !!relatedName && (
            <Text style={styles.hint}>التطبيق المرتبط: {relatedName}</Text>
          )}
        </TouchableOpacity>
      )}

      <Text style={styles.label}>لغة الكود</Text>
      <LangPicker value={lang} onChange={setLang} disabled={busy} />

      <Text style={styles.label}>الوصف</Text>
      <TextInput
        style={styles.textarea}
        value={description}
        onChangeText={setDescription}
        placeholder="مثال: متجر ملابس فيه سلة مشتريات وقائمة أسعار"
        placeholderTextColor={colors.textMuted}
        multiline
      />

      <Button
        title="إنشاء ورفع"
        onPress={() => run("create")}
        disabled={busy}
        loading={loading === "create"}
        style={{ marginTop: space.lg }}
      />

      <Button
        title="معاينة"
        variant="secondary"
        onPress={() => onPreview(cleanName(name))}
        disabled={!hasName}
        style={{ marginTop: space.md }}
      />

      <View style={styles.tools}>
        <RowButton
          label={iconUri ? "تغيير الأيقونة" : "اختيار أيقونة من المعرض"}
          icon="image-outline"
          onPress={pickIcon}
          disabled={busy}
          dim={busy && loading !== "icon"}
          left={iconUri ? <Image source={{ uri: iconUri }} style={styles.iconThumb} /> : undefined}
          right={loading === "icon" ? <ActivityIndicator color={colors.accent} /> : undefined}
        />

        {LANGS[lang].hasAiPreview && (
          <RowButton
            label="معاينة جديدة بالذكاء الاصطناعي"
            icon="sparkles-outline"
            onPress={regeneratePreview}
            disabled={busy}
            dim={busy && loading !== "preview"}
            right={loading === "preview" ? <ActivityIndicator color={colors.accent} /> : undefined}
          />
        )}

        <RowButton
          label="تعديل الكود"
          icon="create-outline"
          onPress={() => setEditOpen(!editOpen)}
          right={<Chevron open={editOpen} />}
        />

        {editOpen && (
          <View style={styles.editBox}>
            <Text style={styles.label}>وصف التعديل</Text>
            <TextInput
              style={styles.textarea}
              value={editText}
              onChangeText={setEditText}
              placeholder="مثال: غيّر الألوان للأخضر وأضف زر واتساب"
              placeholderTextColor={colors.textMuted}
              multiline
            />
            <Button
              title="عدّل وارفع"
              onPress={() => run("edit")}
              disabled={busy}
              loading={loading === "edit"}
              style={{ marginTop: space.md }}
            />
          </View>
        )}

        <RowButton
          label="لصق كود جاهز"
          icon="cloud-upload-outline"
          onPress={() => setPasteOpen(!pasteOpen)}
          right={<Chevron open={pasteOpen} />}
        />

        {pasteOpen && (
          <View style={styles.editBox}>
            <Text style={styles.label}>{LANGS[lang].pasteLabel}</Text>
            <TextInput
              style={[styles.textarea, styles.codeArea]}
              value={pasteText}
              onChangeText={setPasteText}
              placeholder="الصق الكود هنا"
              placeholderTextColor={colors.textMuted}
              multiline
              autoCapitalize="none"
              autoCorrect={false}
            />
            <Button
              title="ارفع الكود"
              onPress={uploadPastedCode}
              disabled={busy}
              loading={loading === "paste"}
              style={{ marginTop: space.md }}
            />
          </View>
        )}
      </View>

      <LogBox lines={log} />
    </Card>
  );
}

export default function CreateScreen() {
  const [busy, setBusy] = useState(false);
  const [firstName, setFirstName] = useState("");
  const [secondName, setSecondName] = useState("");
  const [linking, setLinking] = useState(false);
  const [linkLog, setLinkLog] = useState<string[]>([]);
  const [previewOpen, setPreviewOpen] = useState(false);
  const [previewName, setPreviewName] = useState("");
  const [previewHtml, setPreviewHtml] = useState<string | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);

  async function openPreview(name: string) {
    setPreviewName(name);
    setPreviewHtml(null);
    setPreviewError(null);
    setPreviewOpen(true);
    setPreviewLoading(true);
    try {
      const text =
        (await getFileText(REPO, `apps/${name}/index.html`)) ||
        (await getFileText(REPO, `apps/${name}/preview.html`));
      if (!text) throw new Error("التطبيق ده مش موجود لسه. اعمل إنشاء الأول.");
      setPreviewHtml(text);
    } catch (e: any) {
      setPreviewError(e.message);
    } finally {
      setPreviewLoading(false);
    }
  }

  function askLink() {
    if (busy) return;
    const a = cleanName(firstName);
    const b = cleanName(secondName);
    if (!a || !b) {
      setLinkLog(["❌ اكتب اسم التطبيق الأول والتاني في صندوقيهم فوق وتحت."]);
      return;
    }
    Alert.alert(
      "ربط التطبيقين عبر Supabase",
      `بيتعمل الآتي:\n• بتتنشأ جداول وصلاحيات في مشروع Supabase بتاعك.\n• بيتعاد كتابة التطبيقين (${a} و${b}) وبيترفعوا على GitHub.\n\nالتطبيقين القدام بيتغيروا. تكمّل؟`,
      [
        { text: "إلغاء", style: "cancel" },
        { text: "ربط", onPress: () => doLink(a, b) },
      ]
    );
  }

  async function doLink(a: string, b: string) {
    setLinkLog([]);
    setBusy(true);
    setLinking(true);
    const add = (s: string) => setLinkLog((prev) => [...prev, s]);
    try {
      const r = await linkAppsViaSupabase(a, b, add);
      add("✅ اتعاد كتابة التطبيقين وارتفعوا.");
      if (r.summary) add(`📝 ${r.summary}`);
      if (r.tables.length) add(`🗄️ الجداول: ${r.tables.join("، ")}`);
      add("🎉 اضغط معاينة في كل تطبيق تشوفو.");
    } catch (e: any) {
      add(`❌ ${e.message}`);
    } finally {
      setLinking(false);
      setBusy(false);
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
        <View style={styles.hero}>
          <Text style={styles.heroTitle}>APK Fact</Text>
          <Text style={styles.heroText}>
            صف تطبيقك، والذكاء الاصطناعي يكتب الكود ويعرض لك معاينة حيّة ويبني لك APK.
          </Text>
          <View style={styles.heroLangs}>
            {LANG_ORDER.map((l) => (
              <View key={l} style={[styles.heroPill, { borderColor: langColors[l] }]}>
                <Ionicons name={LANG_ICONS[l]} size={14} color={langColors[l]} />
                <Text style={styles.heroPillText}>{LANGS[l].label}</Text>
              </View>
            ))}
          </View>
        </View>

        <AppBox
          title="إنشاء التطبيق الأول"
          busy={busy}
          setBusy={setBusy}
          onPreview={openPreview}
          onNameChange={setFirstName}
        />

        <Card style={styles.linkCard}>
          <View style={styles.titleRow}>
            <Ionicons name="link-outline" size={20} color={colors.infoText} />
            <Text style={styles.boxTitle}>ربط التطبيقين</Text>
          </View>
          <Text style={styles.linkDesc}>
            يستخدم اسمي التطبيقين المكتوبين فوق وتحت، ولازم يكونوا موجودين. الربط يعيد كتابة التطبيقين.
          </Text>
          <Button
            title="ربط التطبيقين عبر Supabase"
            onPress={askLink}
            disabled={busy}
            loading={linking}
            style={{ marginTop: space.md }}
          />
          <LogBox lines={linkLog} />
        </Card>

        <AppBox
          title="إنشاء التطبيق الثاني"
          busy={busy}
          setBusy={setBusy}
          onPreview={openPreview}
          onNameChange={setSecondName}
          isSecond
          relatedName={cleanName(firstName)}
        />
      </ScrollView>

      <Modal visible={previewOpen} animationType="slide" onRequestClose={() => setPreviewOpen(false)}>
        <View style={{ flex: 1, backgroundColor: colors.bg }}>
          <View style={styles.modalHead}>
            <Text style={styles.modalTitle}>{previewName}</Text>
            <TouchableOpacity
              onPress={() => setPreviewOpen(false)}
              hitSlop={8}
              style={styles.closeBtn}
              accessibilityRole="button"
              accessibilityLabel="إغلاق المعاينة"
            >
              <Ionicons name="close" size={22} color={colors.text} />
            </TouchableOpacity>
          </View>
          {previewLoading && <ActivityIndicator style={{ marginTop: space.lg }} color={colors.accent} />}
          {previewError && (
            <View style={styles.errorBox}>
              <Text style={styles.errorText}>❌ {previewError}</Text>
            </View>
          )}
          {previewHtml && (
            <WebView originWhitelist={["*"]} source={{ html: previewHtml }} style={{ flex: 1 }} />
          )}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: space.lg, paddingBottom: 96 },
  hero: {
    backgroundColor: colors.primarySoft,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.infoBorder,
    padding: space.xl,
    marginBottom: space.xl,
  },
  heroTitle: { ...type.hero, color: colors.text },
  heroText: { ...type.body, color: colors.infoText, marginTop: space.sm },
  heroLangs: { flexDirection: "row", flexWrap: "wrap", gap: space.sm, marginTop: space.lg },
  heroPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.xs,
    borderWidth: 1,
    borderRadius: radius.pill,
    paddingVertical: space.xs,
    paddingHorizontal: space.md,
    backgroundColor: colors.bg,
  },
  heroPillText: { color: colors.text, fontWeight: "700", fontSize: 13 },
  box: { marginBottom: space.xl },
  titleRow: { flexDirection: "row", alignItems: "center", gap: space.sm },
  boxTitle: { ...type.sectionTitle, color: colors.text, marginBottom: space.xs },
  label: { ...type.label, color: colors.text, marginTop: space.lg, marginBottom: space.sm },
  hint: { ...type.hint, color: colors.textMuted, marginTop: space.sm },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.field,
    paddingHorizontal: space.md,
    minHeight: 46,
    fontSize: 15,
    color: colors.text,
    backgroundColor: colors.field,
  },
  textarea: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.field,
    padding: space.md,
    minHeight: 96,
    fontSize: 15,
    color: colors.text,
    backgroundColor: colors.field,
    textAlignVertical: "top",
  },
  codeArea: { minHeight: 180, fontFamily: "monospace", fontSize: 12, writingDirection: "ltr", textAlign: "left" },
  relatedBtn: {
    marginTop: space.lg,
    padding: space.md,
    borderRadius: radius.field,
    backgroundColor: colors.infoBg,
    borderWidth: 1,
    borderColor: colors.infoBorder,
  },
  relatedText: { fontWeight: "700", color: colors.infoText, lineHeight: 22 },
  relatedWarn: { color: colors.warnText, ...type.hint, marginTop: space.xs },
  langRow: { flexDirection: "row", gap: space.sm },
  langCard: {
    flex: 1,
    alignItems: "center",
    gap: space.xs,
    paddingVertical: space.md,
    borderRadius: radius.field,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.field,
  },
  langText: { color: colors.textMuted, fontWeight: "700", fontSize: 14 },
  toolsLine: { flexDirection: "row", alignItems: "center", gap: space.sm, marginTop: space.sm },
  toolsText: { ...type.hint, color: colors.textMuted, flex: 1 },
  linkCard: { marginBottom: space.xl, backgroundColor: colors.infoBg, borderColor: colors.infoBorder },
  linkDesc: { ...type.hint, color: colors.textMuted },
  tools: { marginTop: space.lg },
  rowBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.md,
    minHeight: 52,
    borderTopWidth: 1,
    borderColor: colors.border,
  },
  rowBtnText: { flex: 1, fontSize: 15, fontWeight: "600", color: colors.text },
  rowIcon: {
    width: 32,
    height: 32,
    borderRadius: 10,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.primarySoft,
  },
  iconThumb: { width: 32, height: 32, borderRadius: 8 },
  editBox: { paddingBottom: space.md },
  disabled: { opacity: 0.4 },
  logBox: {
    marginTop: space.lg,
    backgroundColor: colors.field,
    borderRadius: radius.field,
    borderWidth: 1,
    borderColor: colors.border,
    padding: space.md,
  },
  logLine: { marginBottom: space.xs, fontFamily: "monospace", fontSize: 13, lineHeight: 20, color: colors.text },
  modalHead: {
    flexDirection: "row",
    alignItems: "center",
    paddingTop: 40,
    paddingBottom: space.md,
    paddingHorizontal: space.lg,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  modalTitle: { flex: 1, ...type.sectionTitle, color: colors.text },
  closeBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.surfaceAlt,
  },
  errorBox: { backgroundColor: colors.errorBg, borderRadius: radius.field, padding: space.md, margin: space.lg },
  errorText: { color: colors.errorText, ...type.body },
}); 
