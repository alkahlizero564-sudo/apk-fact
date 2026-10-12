import React, { useState } from "react";
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator, Linking } from "react-native";
import * as SecureStore from "expo-secure-store";
import { triggerWorkflow, listWorkflowRuns } from "../services/github";

type Run = { id: number; status: string; conclusion: string | null; createdAt: string; htmlUrl: string };

function statusLabel(run: Run) {
  if (run.status !== "completed") return "⏳ شغّال دلوقتي...";
  if (run.conclusion === "success") return "✅ نجح";
  if (run.conclusion === "failure") return "❌ فشل";
  return `ℹ️ ${run.conclusion}`;
}

type AppSlot = "1" | "2";

export default function BuildScreen() {
  const [appSlot, setAppSlot] = useState<AppSlot>("1");
  const [loading, setLoading] = useState(false);
  const [runs, setRuns] = useState<Run[]>([]);
  const [error, setError] = useState<string | null>(null);

  function repoKey() {
    return appSlot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2";
  }

  async function handleBuild() {
    setLoading(true);
    setError(null);
    try {
      const repo = await SecureStore.getItemAsync(repoKey());
      if (!repo) throw new Error("حط اسم المستودع في تبويب المفاتيح الأول.");
      await triggerWorkflow(repo, "main.yml", { platform: "android" });
      await refreshRuns();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function refreshRuns() {
    try {
      const repo = await SecureStore.getItemAsync(repoKey());
      if (!repo) return;
      const r = await listWorkflowRuns(repo, "main.yml");
      setRuns(r);
    } catch (e: any) {
      setError(e.message);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>التطبيق</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.pill, appSlot === "1" && styles.pillActive]}
          onPress={() => { setAppSlot("1"); setRuns([]); }}
        >
          <Text style={appSlot === "1" ? styles.pillTextActive : styles.pillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pill, appSlot === "2" && styles.pillActive]}
          onPress={() => { setAppSlot("2"); setRuns([]); }}
        >
          <Text style={appSlot === "2" ? styles.pillTextActive : styles.pillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.note}>
        ده بيشغّل نفس الـ workflow بتاع EAS Build اللي عندك على GitHub. لازم يكون المستودع فيه ملف
        .github/workflows/main.yml وeas.json جاهزين، وEXPO_TOKEN متحط في Secrets.
      </Text>

      <TouchableOpacity style={styles.buildBtn} onPress={handleBuild} disabled={loading}>
        {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.buildBtnText}>ابدأ بناء APK (أندرويد)</Text>}
      </TouchableOpacity>

      <TouchableOpacity style={styles.refreshBtn} onPress={refreshRuns}>
        <Text style={styles.refreshBtnText}>تحديث الحالة</Text>
      </TouchableOpacity>

      {error && <Text style={styles.error}>❌ {error}</Text>}

      {runs.map((run) => (
        <TouchableOpacity key={run.id} style={styles.runCard} onPress={() => Linking.openURL(run.htmlUrl)}>
          <Text style={styles.runStatus}>{statusLabel(run)}</Text>
          <Text style={styles.runDate}>{new Date(run.createdAt).toLocaleString("ar-EG")}</Text>
          <Text style={styles.runLink}>افتح في GitHub ↗</Text>
        </TouchableOpacity>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  label: { fontWeight: "700", marginTop: 4, marginBottom: 6 },
  row: { flexDirection: "row", gap: 8, marginBottom: 12 },
  pill: { borderWidth: 1, borderColor: "#ccc", borderRadius: 20, paddingVertical: 8, paddingHorizontal: 16, marginRight: 8 },
  pillActive: { backgroundColor: "#111", borderColor: "#111" },
  pillText: { color: "#111" },
  pillTextActive: { color: "#fff" },
  note: { color: "#666", lineHeight: 20, marginBottom: 16, fontSize: 13 },
  buildBtn: { backgroundColor: "#111", borderRadius: 12, padding: 14, alignItems: "center" },
  buildBtnText: { color: "#fff", fontWeight: "700" },
  refreshBtn: { marginTop: 10, alignItems: "center", padding: 8 },
  refreshBtnText: { color: "#444" },
  error: { color: "#c0392b", marginTop: 12 },
  runCard: { borderWidth: 1, borderColor: "#eee", borderRadius: 10, padding: 12, marginTop: 12 },
  runStatus: { fontWeight: "700", marginBottom: 4 },
  runDate: { color: "#888", fontSize: 12, marginBottom: 4 },
  runLink: { color: "#2563eb" },
});
