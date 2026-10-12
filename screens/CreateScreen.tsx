import React, { useState } from "react";
import { View, TextInput, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator } from "react-native";
import * as SecureStore from "expo-secure-store";
import { generateCode, editCode } from "../services/generate";
import { pushFiles } from "../services/github";
import { runSql } from "../services/supabase";
import { saveGeneration, loadGeneration, AppSlot } from "../services/store";

type Kind = "app" | "website";
type Provider = "claude" | "gemini";
type Mode = "new" | "edit";

export default function CreateScreen({ navigation }: any) {
  const [appSlot, setAppSlot] = useState<AppSlot>("1");
  const [mode, setMode] = useState<Mode>("new");
  const [description, setDescription] = useState("");
  const [kind, setKind] = useState<Kind>("website");
  const [provider, setProvider] = useState<Provider>("claude");
  const [loading, setLoading] = useState(false);
  const [log, setLog] = useState<string[]>([]);

  function addLog(line: string) {
    setLog((prev) => [...prev, line]);
  }

  async function handleCreate() {
    if (!description.trim() || loading) return;
    setLog([]);
    setLoading(true);
    try {
      let result;
      if (mode === "edit") {
        const current = await loadGeneration(appSlot);
        if (!current) {
          addLog("❌ مفيش كود موجود للتعديل عليه. اعمل إنشاء جديد الأول.");
          setLoading(false);
          return;
        }
        addLog("⏳ بيتعدّل الكود...");
        result = await editCode(current.files, description.trim(), provider);
      } else {
        addLog("⏳ بيتولّد الكود...");
        result = await generateCode(description.trim(), kind, provider);
      }
      addLog(`✅ ${mode === "edit" ? "اتعدّل" : "اتولّد"}: ${result.summary} (${result.files.length} ملف)`);

      await saveGeneration(appSlot, result);
      addLog(`✅ اتحفظ محليًا للمعاينة (التطبيق ${appSlot === "1" ? "الأول" : "الثاني"})`);

      const repo = await SecureStore.getItemAsync(appSlot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
      if (repo) {
        addLog("⏳ بيترفع على GitHub...");
        await pushFiles(repo, result.files, `Generate: ${description.slice(0, 60)}`);
        addLog(`✅ اترفع على ${repo}`);
      } else {
        addLog("⚠️ مفيش مستودع GitHub محفوظ — اتخطى الرفع (حطه في تبويب المفاتيح)");
      }

      if (result.sql) {
        const ref = await SecureStore.getItemAsync("SUPABASE_PROJECT_REF");
        if (ref) {
          addLog("⏳ بينفّذ SQL على Supabase...");
          await runSql(result.sql);
          addLog("✅ اتنفّذ SQL بنجاح");
        } else {
          addLog("⚠️ مفيش Supabase Project Ref محفوظ — اتخطى تنفيذ SQL");
        }
      }

      addLog("🎉 خلصنا! روح لتبويب المعاينة تشوف الناتج.");
    } catch (e: any) {
      addLog(`❌ ${e.message}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>التطبيق</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.pill, appSlot === "1" && styles.pillActive]}
          onPress={() => setAppSlot("1")}
        >
          <Text style={appSlot === "1" ? styles.pillTextActive : styles.pillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pill, appSlot === "2" && styles.pillActive]}
          onPress={() => setAppSlot("2")}
        >
          <Text style={appSlot === "2" ? styles.pillTextActive : styles.pillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>الوضع</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.pill, mode === "new" && styles.pillActive]}
          onPress={() => setMode("new")}
        >
          <Text style={mode === "new" ? styles.pillTextActive : styles.pillText}>إنشاء جديد</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pill, mode === "edit" && styles.pillActive]}
          onPress={() => setMode("edit")}
        >
          <Text style={mode === "edit" ? styles.pillTextActive : styles.pillText}>تعديل الموجود</Text>
        </TouchableOpacity>
      </View>

      {mode === "new" && (
        <>
          <Text style={styles.label}>النوع</Text>
          <View style={styles.row}>
            <TouchableOpacity
              style={[styles.pill, kind === "website" && styles.pillActive]}
              onPress={() => setKind("website")}
            >
              <Text style={kind === "website" ? styles.pillTextActive : styles.pillText}>موقع</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.pill, kind === "app" && styles.pillActive]}
              onPress={() => setKind("app")}
            >
              <Text style={kind === "app" ? styles.pillTextActive : styles.pillText}>تطبيق</Text>
            </TouchableOpacity>
          </View>
        </>
      )}

      <Text style={styles.label}>الذكاء الاصطناعي</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.pill, provider === "claude" && styles.pillActive]}
          onPress={() => setProvider("claude")}
        >
          <Text style={provider === "claude" ? styles.pillTextActive : styles.pillText}>Claude</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pill, provider === "gemini" && styles.pillActive]}
          onPress={() => setProvider("gemini")}
        >
          <Text style={provider === "gemini" ? styles.pillTextActive : styles.pillText}>Gemini</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>{mode === "edit" ? "وصف التعديل" : "الوصف"}</Text>
      <TextInput
        style={styles.textarea}
        value={description}
        onChangeText={setDescription}
        placeholder={
          mode === "edit"
            ? "مثال: غيّر لون الخلفية للأزرق وزوّد زرار تواصل واتساب"
            : "مثال: صفحة هبوط لمقهى فيها قائمة أسعار وفورم تواصل"
        }
        multiline
      />

      <TouchableOpacity style={styles.createBtn} onPress={handleCreate} disabled={loading}>
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
  textarea: { borderWidth: 1, borderColor: "#ccc", borderRadius: 12, padding: 12, minHeight: 100, marginTop: 4 },
  createBtn: { backgroundColor: "#111", borderRadius: 12, padding: 14, alignItems: "center", marginTop: 20 },
  createBtnText: { color: "#fff", fontWeight: "700" },
  logBox: { marginTop: 20, backgroundColor: "#f3f3f3", borderRadius: 10, padding: 12 },
  logLine: { marginBottom: 4, fontFamily: "monospace", fontSize: 13 },
});
