import React, { useCallback, useState } from "react";
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator, Linking } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import * as SecureStore from "expo-secure-store";
import * as FileSystem from "expo-file-system";
import * as IntentLauncher from "expo-intent-launcher";
import {
  triggerWorkflow,
  listWorkflowRuns,
  listDir,
  latestRunId,
  getFileText,
  pushFile,
  getFailureLog,
  findAppApkAsset,
  getAssetDownloadInfo,
} from "../services/github";

type Run = { id: number; status: string; conclusion: string | null; createdAt: string; htmlUrl: string };
type Slot = "1" | "2";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function statusLabel(run: Run) {
  if (run.status !== "completed") return "⏳ شغّال دلوقتي...";
  if (run.conclusion === "success") return "✅ نجح";
  if (run.conclusion === "failure") return "❌ فشل";
  return `ℹ️ ${run.conclusion}`;
}

export default function BuildScreen() {
  const [slot, setSlot] = useState<Slot>("1");
  const [apps, setApps] = useState<string[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [runs, setRuns] = useState<Run[]>([]);

  async function repoOf(): Promise<string> {
    const r = await SecureStore.getItemAsync(slot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
    if (!r) throw new Error("حط اسم المستودع في تبويب المفاتيح الأول.");
    return r;
  }

  const loadApps = useCallback(async () => {
    try {
      const r = await SecureStore.getItemAsync(slot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
      if (!r) {
        setApps([]);
        return;
      }
      setApps(await listDir(r, "apps"));
    } catch (e: any) {
      setError(e.message);
    }
  }, [slot]);

  useFocusEffect(
    useCallback(() => {
      loadApps();
    }, [loadApps])
  );

  async function ensureBuildWorkflow(repo: string) {
    const path = ".github/workflows/build-app.yml";
    if (await getFileText(repo, path)) return;
    const template = await SecureStore.getItemAsync("GITHUB_REPO_1");
    if (!template || template === repo) throw new Error("ملف build-app.yml ناقص في المستودع.");
    const text = await getFileText(template, path);
    if (!text) throw new Error("ملف build-app.yml مش موجود في المستودع الأول.");
    await pushFile(repo, path, text, "Setup: build-app.yml");
    await sleep(6000);
  }

  async function triggerWithRetry(repo: string, name: string) {
    for (let i = 0; i < 5; i++) {
      try {
        await triggerWorkflow(repo, "build-app.yml", { app: name });
        return;
      } catch (e) {
        if (i === 4) throw e;
        await sleep(5000);
      }
    }
  }

  async function buildApp(name: string) {
    if (busy) return;
    setBusy(name);
    setError(null);
    try {
      const repo = await repoOf();
      setStatus("⏳ تجهيز...");
      await ensureBuildWorkflow(repo);
      const prevId = await latestRunId(repo, "build-app.yml");
      await triggerWithRetry(repo, name);
      setStatus("⏳ بيتبني التطبيق على GitHub... (من 5 إلى 15 دقيقة، خلّي الأداة مفتوحة)");

      const started = Date.now();
      let run: any = null;
      while (Date.now() - started < 40 * 60 * 1000) {
        await sleep(15000);
        const list = await listWorkflowRuns(repo, "build-app.yml");
        const r = list.find((x: any) => x.id > prevId);
        if (r && r.status === "completed") {
          run = r;
          break;
        }
      }
      if (!run) throw new Error("البناء أخذ وقت طويل. جرّب تضغط تاني بعد شوية.");
      if (run.conclusion !== "success") {
        const tail = await getFailureLog(repo, run.id);
        throw new Error("فشل البناء." + (tail ? "\n" + tail : ""));
      }

      setStatus("⏳ بيتنزّل الملف...");
      const asset = await findAppApkAsset(repo, name);
      if (!asset) throw new Error("ما لقيت ملف APK في الإصدارات.");
      const info = await getAssetDownloadInfo(repo, asset.id);
      const dest = FileSystem.cacheDirectory + `${name}.apk`;
      const dl = await FileSystem.downloadAsync(info.url, dest, { headers: info.headers });
      if (dl.status !== 200) throw new Error(`فشل التنزيل (${dl.status})`);

      setStatus("✅ جاهز. بتظهر شاشة التثبيت، اضغط تثبيت.");
      const contentUri = await FileSystem.getContentUriAsync(dl.uri);
      await IntentLauncher.startActivityAsync("android.intent.action.VIEW", {
        data: contentUri,
        flags: 1,
        type: "application/vnd.android.package-archive",
      });
    } catch (e: any) {
      setError(e.message);
      setStatus("");
    } finally {
      setBusy(null);
    }
  }

  async function buildTool() {
    if (busy) return;
    setBusy("tool");
    setError(null);
    try {
      const repo = await repoOf();
      await triggerWorkflow(repo, "main.yml", { platform: "android" });
      await refreshRuns();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(null);
    }
  }

  async function refreshRuns() {
    try {
      const repo = await repoOf();
      setRuns(await listWorkflowRuns(repo, "main.yml"));
    } catch (e: any) {
      setError(e.message);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>المستودع</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.pill, slot === "1" && styles.pillActive]}
          onPress={() => { setSlot("1"); setRuns([]); setError(null); }}
        >
          <Text style={slot === "1" ? styles.pillTextActive : styles.pillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pill, slot === "2" && styles.pillActive]}
          onPress={() => { setSlot("2"); setRuns([]); setError(null); }}
        >
          <Text style={slot === "2" ? styles.pillTextActive : styles.pillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.refreshLink} onPress={loadApps}>
          <Text style={styles.refreshText}>تحديث ↻</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.section}>تطبيقاتك</Text>
      {apps.length === 0 && <Text style={styles.note}>مفيش تطبيقات لسه. اعمل واحد من تبويب الإنشاء.</Text>}
      {apps.map((a) => (
        <View key={a} style={styles.appRow}>
          <Text style={styles.appName}>{a}</Text>
          <TouchableOpacity style={styles.appBtn} onPress={() => buildApp(a)} disabled={!!busy}>
            {busy === a ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.appBtnText}>ابنِ ونزّل وثبّت</Text>
            )}
          </TouchableOpacity>
        </View>
      ))}

      {status !== "" && <Text style={styles.status}>{status}</Text>}
      {error && <Text style={styles.error}>❌ {error}</Text>}

      <Text style={[styles.section, { marginTop: 32 }]}>بناء الأداة نفسها</Text>
      <Text style={styles.note}>
        ده يبني نسخة جديدة من الأداة (مو من تطبيقاتك). تحتاجه بس لما نغيّر كود الأداة.
      </Text>
      <TouchableOpacity style={styles.buildBtn} onPress={buildTool} disabled={!!busy}>
        {busy === "tool" ? <ActivityIndicator color="#fff" /> : <Text style={styles.buildBtnText}>ابدأ بناء الأداة</Text>}
      </TouchableOpacity>
      <TouchableOpacity style={styles.refreshBtn} onPress={refreshRuns}>
        <Text style={styles.refreshBtnText}>تحديث الحالة</Text>
      </TouchableOpacity>

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
  section: { fontWeight: "700", fontSize: 16, marginTop: 20, marginBottom: 8 },
  row: { flexDirection: "row", alignItems: "center", marginBottom: 8 },
  pill: { borderWidth: 1, borderColor: "#ccc", borderRadius: 20, paddingVertical: 8, paddingHorizontal: 16, marginRight: 8 },
  pillActive: { backgroundColor: "#111", borderColor: "#111" },
  pillText: { color: "#111" },
  pillTextActive: { color: "#fff" },
  refreshLink: { marginLeft: "auto", padding: 6 },
  refreshText: { color: "#2563eb" },
  note: { color: "#666", lineHeight: 20, marginBottom: 12, fontSize: 13 },
  appRow: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: "#eee", borderRadius: 10, padding: 10, marginBottom: 8 },
  appName: { flex: 1, fontWeight: "700" },
  appBtn: { backgroundColor: "#111", borderRadius: 10, paddingVertical: 10, paddingHorizontal: 14, minWidth: 120, alignItems: "center" },
  appBtnText: { color: "#fff", fontWeight: "700", fontSize: 13 },
  status: { marginTop: 12, lineHeight: 22 },
  error: { color: "#c0392b", marginTop: 12, fontFamily: "monospace", fontSize: 12 },
  buildBtn: { backgroundColor: "#444", borderRadius: 12, padding: 14, alignItems: "center" },
  buildBtnText: { color: "#fff", fontWeight: "700" },
  refreshBtn: { marginTop: 10, alignItems: "center", padding: 8 },
  refreshBtnText: { color: "#444" },
  runCard: { borderWidth: 1, borderColor: "#eee", borderRadius: 10, padding: 12, marginTop: 12 },
  runStatus: { fontWeight: "700", marginBottom: 4 },
  runDate: { color: "#888", fontSize: 12, marginBottom: 4 },
  runLink: { color: "#2563eb" },
});
