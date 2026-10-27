import React, { useState } from "react";
import {
  View, TextInput, Text, TouchableOpacity, StyleSheet,
  ScrollView, ActivityIndicator, Modal, Image, Alert,
} from "react-native";
import { WebView } from "react-native-webview";
import * as ImagePicker from "expo-image-picker";
import * as SecureStore from "expo-secure-store";
import { pushFile, pushBase64File, listWorkflowRuns, latestRunId, getFileText, getFailureLog } from "../services/github";
import { REPO } from "../services/config";
import { linkAppsViaSupabase } from "../services/link";
import { Card, Button } from "../components/ui";
import { colors, space, radius, type } from "../theme";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function cleanName(n: string) {
  return n.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
}

async function waitForRun(prevId: number, workflow: string = "generate.yml") {
  const started = Date.now();
  while (Date.now() - started < 4 * 60 * 1000) {
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
  onPress,
  disabled,
  dim,
  left,
  right,
}: {
  label: string;
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
      {left}
      <Text style={styles.rowBtnText}>{label}</Text>
      {right}
    </TouchableOpacity>
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
  const [lang, setLang] = useState<"html" | "flutter">("html");
  const [loading, setLoading] = useState<Kind | "paste" | "icon" | null>(null);
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
      const target = lang === "flutter" ? `apps/${n}/lib/main.dart` : `apps/${n}/index.html`;
      await pushFile(REPO, target, code + "\n", `Upload code: ${n}`);
      addLog(`✅ ارتفع الكود: ${target}`);
      addLog("🎉 اضغط معاينة تشوفه.");
      setPasteText("");
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

    const isFlutter = lang === "flutter";
    const workflow = isFlutter ? "generate-flutter.yml" : "generate.yml";
    const requestFile = isFlutter ? "request-flutter.txt" : "request.txt";
    const mainFile = isFlutter ? `apps/${n}/lib/main.dart` : `apps/${n}/index.html`;

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
        const relExists =
          (await getFileText(REPO, `apps/${rel}/index.html`)) ||
          (await getFileText(REPO, `apps/${rel}/lib/main.dart`));
        if (relExists) {
          addLog(`🔗 الذكاء الاصطناعي بيقرأ التطبيق الأول (${rel}) قبل ما يبني.`);
        } else {
          addLog(`⚠️ التطبيق الأول (${rel}) ما لقيتو في GitHub، فبيتبني التطبيق ده براهو.`);
        }
      }

      const prevId = await latestRunId(REPO, workflow);

      addLog("⏳ بيتم إرسال الطلب...");
      const relLine = rel ? `@related: ${rel}\n` : "";
      const model = isFlutter ? (await SecureStore.getItemAsync("GEMINI_MODEL")) ?? "" : "";
      const modelLine = model ? `@model: ${model}\n` : "";
      const content = `${n}\n${relLine}${modelLine}${text}\n\n(request id: ${Date.now()})\n`;
      await pushFile(REPO, requestFile, content, `${kind === "edit" ? "Edit" : "Create"}: ${n}`);
      addLog("✅ تم إرسال الطلب.");
      addLog(kind === "edit" ? "⏳ بيتعدّل الكود... (من نصف دقيقة لدقيقتين)" : "⏳ بيتولّد الكود... (من نصف دقيقة لدقيقتين)");

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
      addLog("🎉 اضغط معاينة تشوفه.");
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
      <View style={styles.langRow}>
        {(["html", "flutter"] as const).map((l) => (
          <TouchableOpacity
            key={l}
            style={[styles.langChip, lang === l && styles.langChipActive]}
            onPress={() => setLang(l)}
            disabled={busy}
            accessibilityRole="radio"
            accessibilityState={{ selected: lang === l }}
          >
            <Text style={[styles.langText, lang === l && styles.langTextActive]}>
              {l === "html" ? "HTML" : "Flutter"}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

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
          onPress={pickIcon}
          disabled={busy}
          dim={busy && loading !== "icon"}
          left={iconUri ? <Image source={{ uri: iconUri }} style={styles.iconThumb} /> : undefined}
          right={loading === "icon" ? <ActivityIndicator color={colors.primary} /> : undefined}
        />

        <RowButton
          label="تعديل الكود"
          onPress={() => setEditOpen(!editOpen)}
          right={<Text style={styles.chevron}>{editOpen ? "▲" : "▼"}</Text>}
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
          onPress={() => setPasteOpen(!pasteOpen)}
          right={<Text style={styles.chevron}>{pasteOpen ? "▲" : "▼"}</Text>}
        />

        {pasteOpen && (
          <View style={styles.editBox}>
            <Text style={styles.label}>{lang === "flutter" ? "الكود (main.dart كامل)" : "الكود (HTML كامل)"}</Text>
            <TextInput
              style={[styles.textarea, { minHeight: 160, fontFamily: "monospace", fontSize: 12 }]}
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
        <AppBox
          title="إنشاء التطبيق الأول"
          busy={busy}
          setBusy={setBusy}
          onPreview={openPreview}
          onNameChange={setFirstName}
        />

        <Card style={styles.linkCard}>
          <Text style={styles.boxTitle}>ربط التطبيقين</Text>
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
        <View style={{ flex: 1, backgroundColor: colors.surface }}>
          <View style={styles.modalHead}>
            <Text style={styles.modalTitle}>{previewName}</Text>
            <TouchableOpacity onPress={() => setPreviewOpen(false)} hitSlop={8}>
              <Text style={styles.closeText}>إغلاق ✕</Text>
            </TouchableOpacity>
          </View>
          {previewLoading && <ActivityIndicator style={{ marginTop: space.lg }} color={colors.primary} />}
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
  box: { marginBottom: space.xl },
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
    backgroundColor: colors.surface,
  },
  textarea: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.field,
    padding: space.md,
    minHeight: 96,
    fontSize: 15,
    color: colors.text,
    backgroundColor: colors.surface,
    textAlignVertical: "top",
  },
  relatedBtn: {
    marginTop: space.lg,
    padding: space.md,
    borderRadius: radius.field,
    backgroundColor: colors.infoBg,
    borderWidth: 1,
    borderColor: "#C9D9FA",
  },
  relatedText: { fontWeight: "700", color: colors.infoText, lineHeight: 22 },
  relatedWarn: { color: "#92400E", ...type.hint, marginTop: space.xs },
  langRow: { flexDirection: "row", gap: space.sm },
  langChip: {
    paddingVertical: space.sm,
    paddingHorizontal: space.xl,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  langChipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  langText: { color: colors.textMuted, fontWeight: "600" },
  langTextActive: { color: colors.primaryText, fontWeight: "700" },
  linkCard: { marginBottom: space.xl, backgroundColor: colors.infoBg, borderColor: "#C9D9FA" },
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
  chevron: { color: colors.textMuted, fontSize: 12 },
  iconThumb: { width: 32, height: 32, borderRadius: 8 },
  editBox: { paddingBottom: space.md },
  disabled: { opacity: 0.4 },
  logBox: { marginTop: space.lg, backgroundColor: colors.bg, borderRadius: radius.field, padding: space.md },
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
  closeText: { color: colors.primary, fontWeight: "700" },
  errorBox: { backgroundColor: colors.errorBg, borderRadius: radius.field, padding: space.md, margin: space.lg },
  errorText: { color: colors.errorText, ...type.body },
}); 
