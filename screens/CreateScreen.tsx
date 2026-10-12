import React, { useState } from "react";
import { View, TextInput, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator } from "react-native";
import * as SecureStore from "expo-secure-store";
import { pushFile, listWorkflowRuns, latestRunId, getFileText, getFailureLog } from "../services/github";

type Slot = "1" | "2";
type Mode = "new" | "edit";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export default function CreateScreen() {
  const [appSlot, setAppSlot] = useState<Slot>("1");
  const [mode, setMode] = useState<Mode>("new");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [log, setLog] = useState<string[]>([]);

  function addLog(line: string) {
    setLog((prev) => [...prev, line]);
  }

  async function waitForRun(repo: string, prevId: number) {
    const started = Date.now();
    while (Date.now() - started < 4 * 60 * 1000) {
      await sleep(5000);
      const runs = await listWorkflowRuns(repo, "generate.yml");
      const run = runs.find((r: any) => r.id > prevId);
      if (run && run.status === "completed") return run;
    }
    return null;
  }

  async function handleSend() {
    if (loading) return;
    const cleanName = name.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
    if (!cleanName) {
      setLog(["❌ اكتب اسم التطبيق بالإنجليزي (حروف وأرقام بدون مسافات)."]);
      return;
    }
    if (!description.trim()) {
      setLog(["❌ اكتب الوصف."]);
      return;
    }

    setLog([]);
    setLoading(true);
    try {
      const repo = await SecureStore.getItemAsync(appSlot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
      if (!repo) {
        addLog("❌ مفيش مستودع محفوظ. حطه في تبويب المفاتيح.");
        return;
      }

      const prevId = await latestRunId(repo, "generate.yml");

      addLog("⏳ بيتم إرسال الطلب...");
      const content = `${cleanName}\n${description.trim()}\n\n(request id: ${Date.now()})\n`;
      await pushFile(repo, "request.txt", content, `${mode === "edit" ? "Edit" : "Create"}: ${cleanName}`);
      addLog("✅ تم إرسال الطلب.");
      addLog("⏳ بيتولّد الكود... (من نصف دقيقة لدقيقتين)");

      const run = await waitForRun(repo, prevId);
      if (!run) {
        addLog("⚠️ التوليد أخذ وقت طويل. جرّب تبويب المعاينة بعد شوية.");
        return;
      }

      if (run.conclusion !== "success") {
        addLog("❌ فشل التوليد.");
        const tail = await getFailureLog(repo, run.id);
        if (tail) addLog(tail);
        return;
      }

      const html = await getFileText(repo, `apps/${cleanName}/index.html`);
      if (!html) {
        addLog("⚠️ التوليد نجح لكن الملف ما ظهر. حدّث المعاينة بعد شوية.");
        return;
      }
      addLog(`✅ اتولّد وارتفع: apps/${cleanName}/index.html`);
      addLog("🎉 روح لتبويب المعاينة تشوفه.");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>المستودع</Text>
      <View style={styles.row}>
        <TouchableOpacity style={[styles.pill, appSlot === "1" && styles.pillActive]} onPress={() => setAppSlot("1")}>
          <Text style={appSlot === "1" ? styles.pillTextActive : styles.pillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.pill, appSlot === "2" && styles.pillActive]} onPress={() => setAppSlot("2")}>
          <Text style={appSlot === "2" ? styles.pillTextActive : styles.pillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>الوضع</Text>
      <View style={styles.row}>
        <TouchableOpacity style={[styles.pill, mode === "new" && styles.pillActive]} onPress={() => setMode("new")}>
          <Text style={mode === "new" ? styles.pillTextActive : styles.pillText}>إنشاء جديد</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.pill, mode === "edit" && styles.pillActive]} onPress={() => setMode("edit")}>
          <Text style={mode === "edit" ? styles.pillTextActive : styles.pillText}>تعديل الموجود</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>
        {mode === "edit" ? "اسم التطبيق اللي تبغى تعدّله" : "اسم التطبيق (إنجليزي)"}
      </Text>
      <TextInput
        style={styles.input}
        value={name}
        onChangeText={setName}
        placeholder="مثال: shop"
        autoCapitalize="none"
        autoCorrect={false}
      />

      <Text style={styles.label}>{mode === "edit" ? "وصف التعديل" : "الوصف"}</Text>
      <TextInput
        style={styles.textarea}
        value={description}
        onChangeText={setDescription}
        placeholder={
          mode === "edit"
            ? "مثال: غيّر الألوان للأخضر وأضف زر واتساب"
            : "مثال: متجر ملابس فيه سلة مشتريات وقائمة أسعار"
        }
        multiline
      />

      <TouchableOpacity style={styles.createBtn} onPress={handleSend} disabled={loading}>
        {loading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.createBtnText}>{mode === "edit" ? "عدّل وارفع" : "إنشاء ورفع"}</Text>
        )}
      </TouchableOpacity>

      {log.length > 0 && (
        <View style={styles.logBox}>
          {log.map((line, i) => (
            <Text key={i} style={styles.logLine}>{line}</Text>
          ))}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  label: { fontWeight: "700", marginTop: 12, marginBottom: 6 },
  row: { flexDirection: "row", gap: 8 },
  pill: { borderWidth: 1, borderColor: "#ccc", borderRadius: 20, paddingVertical: 8, paddingHorizontal: 16, marginRight: 8 },
  pillActive: { backgroundColor: "#111", borderColor: "#111" },
  pillText: { color: "#111" },
  pillTextActive: { color: "#fff" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 12, padding: 12, marginTop: 4 },
  textarea: { borderWidth: 1, borderColor: "#ccc", borderRadius: 12, padding: 12, minHeight: 100, marginTop: 4 },
  createBtn: { backgroundColor: "#111", borderRadius: 12, padding: 14, alignItems: "center", marginTop: 20 },
  createBtnText: { color: "#fff", fontWeight: "700" },
  logBox: { marginTop: 20, backgroundColor: "#f3f3f3", borderRadius: 10, padding: 12 },
  logLine: { marginBottom: 4, fontFamily: "monospace", fontSize: 13 },
}); 
