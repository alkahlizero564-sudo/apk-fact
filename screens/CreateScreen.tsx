import React, { useState } from "react";
import {
  View, TextInput, Text, TouchableOpacity, StyleSheet,
  ScrollView, ActivityIndicator, Modal,
} from "react-native";
import { WebView } from "react-native-webview";
import { pushFile, listWorkflowRuns, latestRunId, getFileText, getFailureLog } from "../services/github";
import { REPO } from "../services/config";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function cleanName(n: string) {
  return n.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
}

async function waitForRun(prevId: number) {
  const started = Date.now();
  while (Date.now() - started < 4 * 60 * 1000) {
    await sleep(5000);
    const runs = await listWorkflowRuns(REPO, "generate.yml");
    const run = runs.find((r: any) => r.id > prevId);
    if (run && run.status === "completed") return run;
  }
  return null;
}

type BoxProps = {
  title: string;
  busy: boolean;
  setBusy: (b: boolean) => void;
  onPreview: (name: string) => void;
};

function AppBox({ title, busy, setBusy, onPreview }: BoxProps) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [log, setLog] = useState<string[]>([]);

  function addLog(line: string) {
    setLog((prev) => [...prev, line]);
  }

  async function handleSend() {
    if (busy) return;
    const n = cleanName(name);
    if (!n) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي (حروف وأرقام بدون مسافات)."]);
      return;
    }
    if (!description.trim()) {
      setLog(["❌ اكتب الوصف."]);
      return;
    }

    setLog([]);
    setBusy(true);
    setLoading(true);
    try {
      const prevId = await latestRunId(REPO, "generate.yml");

      addLog("⏳ بيتم إرسال الطلب...");
      const content = `${n}\n${description.trim()}\n\n(request id: ${Date.now()})\n`;
      await pushFile(REPO, "request.txt", content, `Create: ${n}`);
      addLog("✅ تم إرسال الطلب.");
      addLog("⏳ بيتولّد الكود... (من نصف دقيقة لدقيقتين)");

      const run = await waitForRun(prevId);
      if (!run) {
        addLog("⚠️ التوليد أخذ وقت طويل. جرّب المعاينة بعد شوية.");
        return;
      }
      if (run.conclusion !== "success") {
        addLog("❌ فشل التوليد.");
        const tail = await getFailureLog(REPO, run.id);
        if (tail) addLog(tail);
        return;
      }

      const html = await getFileText(REPO, `apps/${n}/index.html`);
      if (!html) {
        addLog("⚠️ التوليد نجح لكن الملف ما ظهر. جرّب المعاينة بعد شوية.");
        return;
      }
      addLog(`✅ اتولّد وارتفع: apps/${n}/index.html`);
      addLog("🎉 اضغط معاينة تشوفه.");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(false);
      setBusy(false);
    }
  }

  return (
    <View style={styles.box}>
      <Text style={styles.boxTitle}>{title}</Text>

      <Text style={styles.label}>اسم التطبيق (إنجليزي)</Text>
      <TextInput
        style={styles.input}
        value={name}
        onChangeText={setName}
        placeholder="مثال: shop"
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Text style={styles.hint}>لو الاسم موجود، يعدّل عليه بدل ما ينشئ جديد.</Text>

      <Text style={styles.label}>الوصف</Text>
      <TextInput
        style={styles.textarea}
        value={description}
        onChangeText={setDescription}
        placeholder="مثال: متجر ملابس فيه سلة مشتريات وقائمة أسعار"
        multiline
      />

      <TouchableOpacity
        style={[styles.createBtn, busy && !loading && styles.disabled]}
        onPress={handleSend}
        disabled={busy}
      >
        {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.createBtnText}>إنشاء ورفع</Text>}
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.previewBtn, !cleanName(name) && styles.disabled]}
        onPress={() => onPreview(cleanName(name))}
        disabled={!cleanName(name)}
      >
        <Text style={styles.previewBtnText}>معاينة</Text>
      </TouchableOpacity>

      {log.length > 0 && (
        <View style={styles.logBox}>
          {log.map((line, i) => (
            <Text key={i} style={styles.logLine}>{line}</Text>
          ))}
        </View>
      )}
    </View>
  );
}

export default function CreateScreen() {
  const [busy, setBusy] = useState(false);
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
      const text = await getFileText(REPO, `apps/${name}/index.html`);
      if (!text) throw new Error("التطبيق ده مش موجود لسه. اعمل إنشاء الأول.");
      setPreviewHtml(text);
    } catch (e: any) {
      setPreviewError(e.message);
    } finally {
      setPreviewLoading(false);
    }
  }

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={styles.container}>
        <AppBox title="إنشاء التطبيق الأول" busy={busy} setBusy={setBusy} onPreview={openPreview} />
        <AppBox title="إنشاء التطبيق الثاني" busy={busy} setBusy={setBusy} onPreview={openPreview} />
      </ScrollView>

      <Modal visible={previewOpen} animationType="slide" onRequestClose={() => setPreviewOpen(false)}>
        <View style={{ flex: 1, backgroundColor: "#fff" }}>
          <View style={styles.modalHead}>
            <Text style={styles.modalTitle}>{previewName}</Text>
            <TouchableOpacity onPress={() => setPreviewOpen(false)}>
              <Text style={styles.closeText}>إغلاق ✕</Text>
            </TouchableOpacity>
          </View>
          {previewLoading && <ActivityIndicator style={{ marginTop: 16 }} />}
          {previewError && <Text style={styles.error}>❌ {previewError}</Text>}
          {previewHtml && (
            <WebView originWhitelist={["*"]} source={{ html: previewHtml }} style={{ flex: 1 }} />
          )}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, paddingBottom: 48 },
  box: { borderWidth: 1, borderColor: "#ddd", borderRadius: 14, padding: 14, marginBottom: 20, backgroundColor: "#fff" },
  boxTitle: { fontWeight: "700", fontSize: 17, marginBottom: 4 },
  label: { fontWeight: "700", marginTop: 12, marginBottom: 6 },
  hint: { color: "#888", fontSize: 12, marginTop: 4 },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 12, padding: 12 },
  textarea: { borderWidth: 1, borderColor: "#ccc", borderRadius: 12, padding: 12, minHeight: 90 },
  createBtn: { backgroundColor: "#111", borderRadius: 12, padding: 14, alignItems: "center", marginTop: 16 },
  createBtnText: { color: "#fff", fontWeight: "700" },
  previewBtn: { borderWidth: 1, borderColor: "#111", borderRadius: 12, padding: 12, alignItems: "center", marginTop: 10 },
  previewBtnText: { color: "#111", fontWeight: "700" },
  disabled: { opacity: 0.4 },
  logBox: { marginTop: 16, backgroundColor: "#f3f3f3", borderRadius: 10, padding: 12 },
  logLine: { marginBottom: 4, fontFamily: "monospace", fontSize: 13 },
  modalHead: { flexDirection: "row", alignItems: "center", paddingTop: 40, paddingBottom: 12, paddingHorizontal: 16, borderBottomWidth: 1, borderColor: "#eee" },
  modalTitle: { flex: 1, fontWeight: "700", fontSize: 16 },
  closeText: { color: "#2563eb", fontWeight: "700" },
  error: { color: "#c0392b", margin: 16 },
});
