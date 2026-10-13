import React, { useCallback, useState } from "react";
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator, Linking } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import * as FileSystem from "expo-file-system";
import * as IntentLauncher from "expo-intent-launcher";
import {
  triggerWorkflow,
  listWorkflowRuns,
  listDir,
  latestRunId,
  getFailureLog,
  findAppApkAsset,
  getAssetDownloadInfo,
} from "../services/github";
import { REPO } from "../services/config";

type Run = { id: number; status: string; conclusion: string | null; createdAt: string; htmlUrl: string };

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function statusLabel(run: Run) {
  if (run.status !== "completed") return "⏳ شغّال دلوقتي...";
  if (run.conclusion === "success") return "✅ نجح";
  if (run.conclusion === "failure") return "❌ فشل";
  return `ℹ️ ${run.conclusion}`;
}

export default function BuildScreen() {
  const [apps, setApps] = useState<string[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [runs, setRuns] = useState<Run[]>([]);

  const loadApps = useCallback(async () => {
    try {
      setApps(await listDir(REPO, "apps"));
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadApps();
    }, [loadApps])
  );

  async function triggerWithRetry(name: string) {
    for (let i = 0; i < 5; i++) {
      try {
        await triggerWorkflow(REPO, "build-app.yml", { app: name });
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
      setStatus("⏳ تجهيز...");
      const prevId = await latestRunId(REPO, "build-app.yml");
      await triggerWithRetry(name);
      setStatus("⏳ بيتبني التطبيق على GitHub... (من 5 إلى 15 دقيقة، خلّي الأداة مفتوحة)");

      const started = Date.now();
      let run: any = null;
      while (Date.now() - started < 40 * 60 * 1000) {
        await sleep(15000);
        const list = await listWorkflowRuns(REPO, "build-app.yml");
        const r = list.find((x: any) => x.id > prevId);
        if (r && r.status === "completed") {
          run = r;
          break;
        }
      }
      if (!run) throw new Error("البناء أخذ وقت طويل. جرّب تضغط تاني بعد شوية.");
      if (run.conclusion !== "success") {
        const tail = await getFailureLog(REPO, run.id);
        throw new Error("فشل البناء." + (tail ? "\n" + tail : ""));
      }

      setStatus("⏳ بيتنزّل الملف...");
      const asset = await findAppApkAsset(REPO, name);
      if (!asset) throw new Error("ما لقيت ملف APK في الإصدارات.");
      const info = await getAssetDownloadInfo(REPO, asset.id);
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

  async function refreshRuns() {
    try {
      setRuns(await listWorkflowRuns(REPO, "main.yml"));
    } catch (e: any) {
      setError(e.message);
    }
  }

  async function buildTool() {
    if (busy) return;
    setBusy("tool");
    setError(null);
    try {
      await triggerWorkflow(REPO, "main.yml", { platform: "android" });
      await refreshRuns();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.headRow}>
        <Text style={styles.section}>تطبيقاتك</Text>
        <TouchableOpacity onPress={loadApps}>
          <Text style={styles.refreshText}>تحديث ↻</Text>
        </TouchableOpacity>
      </View>

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
  headRow: { flexDirection: "row", alignItems: "center", marginBottom: 8 },
  section: { fontWeight: "700", fontSize: 16, flex: 1 },
  refreshText: { color: "#2563eb", padding: 6 },
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
