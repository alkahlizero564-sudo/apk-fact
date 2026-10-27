import React, { useCallback, useState } from "react";
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Linking } from "react-native";
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
  getFileText,
} from "../services/github";
import { REPO } from "../services/config";
import { Card, Button } from "../components/ui";
import { colors, space, radius, type } from "../theme";

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
  const [flutterApps, setFlutterApps] = useState<string[]>([]);

  const loadApps = useCallback(async () => {
    try {
      const list = await listDir(REPO, "apps");
      setApps(list);
      const flags = await Promise.all(
        list.map(async (a: string) => {
          try {
            return !!(await getFileText(REPO, `apps/${a}/lib/main.dart`));
          } catch {
            return false;
          }
        })
      );
      setFlutterApps(list.filter((_: string, i: number) => flags[i]));
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadApps();
    }, [loadApps])
  );

  async function triggerWithRetry(name: string, workflow: string) {
    for (let i = 0; i < 5; i++) {
      try {
        await triggerWorkflow(REPO, workflow, { app: name });
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
    const workflow = flutterApps.includes(name) ? "build-flutter.yml" : "build-app.yml";
    try {
      setStatus("⏳ تجهيز...");
      const prevId = await latestRunId(REPO, workflow);
      await triggerWithRetry(name, workflow);
      setStatus("⏳ بيتبني التطبيق على GitHub... (من 5 إلى 15 دقيقة، خلّي الأداة مفتوحة)");

      const started = Date.now();
      let run: any = null;
      while (Date.now() - started < 40 * 60 * 1000) {
        await sleep(15000);
        const list = await listWorkflowRuns(REPO, workflow);
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
    <ScrollView style={{ backgroundColor: colors.bg }} contentContainerStyle={styles.container}>
      <View style={styles.headRow}>
        <Text style={styles.section}>تطبيقاتك</Text>
        <TouchableOpacity onPress={loadApps} hitSlop={8}>
          <Text style={styles.refreshText}>تحديث ↻</Text>
        </TouchableOpacity>
      </View>

      {apps.length === 0 && (
        <Card style={styles.emptyCard}>
          <Text style={styles.note}>مفيش تطبيقات لسه. اعمل واحد من تبويب الإنشاء.</Text>
        </Card>
      )}

      {apps.map((a) => (
        <Card key={a} style={styles.appRow}>
          <Text style={styles.appName} numberOfLines={1}>
            {a}
            {flutterApps.includes(a) ? " · Flutter" : ""}
          </Text>
          <Button
            title="ابنِ ونزّل وثبّت"
            onPress={() => buildApp(a)}
            disabled={!!busy}
            loading={busy === a}
            style={styles.appBtn}
          />
        </Card>
      ))}

      {status !== "" && (
        <View style={[styles.notice, { backgroundColor: colors.infoBg }]}>
          <Text style={[styles.noticeText, { color: colors.infoText }]}>{status}</Text>
        </View>
      )}
      {error && (
        <View style={[styles.notice, { backgroundColor: colors.errorBg }]}>
          <Text style={[styles.errorText, { color: colors.errorText }]}>❌ {error}</Text>
        </View>
      )}

      <Card style={{ marginTop: space.xl }}>
        <Text style={styles.section}>بناء الأداة نفسها</Text>
        <Text style={[styles.note, { marginTop: space.xs, marginBottom: space.lg }]}>
          ده يبني نسخة جديدة من الأداة (مو من تطبيقاتك). تحتاجه بس لما نغيّر كود الأداة.
        </Text>
        <Button title="ابدأ بناء الأداة" onPress={buildTool} disabled={!!busy} loading={busy === "tool"} />
        <TouchableOpacity style={styles.refreshBtn} onPress={refreshRuns}>
          <Text style={styles.refreshBtnText}>تحديث الحالة</Text>
        </TouchableOpacity>
      </Card>

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
  container: { padding: space.lg, paddingBottom: 96 },
  headRow: { flexDirection: "row", alignItems: "center", marginBottom: space.md },
  section: { ...type.sectionTitle, color: colors.text, flex: 1 },
  refreshText: { color: colors.primary, fontWeight: "600", padding: space.xs },
  note: { ...type.hint, color: colors.textMuted },
  emptyCard: { alignItems: "center", paddingVertical: space.xl },
  appRow: { flexDirection: "row", alignItems: "center", gap: space.md, marginBottom: space.md, padding: space.md },
  appName: { flex: 1, fontSize: 16, fontWeight: "700", color: colors.text },
  appBtn: { minWidth: 150, minHeight: 44 },
  notice: { borderRadius: radius.field, padding: space.md, marginTop: space.md },
  noticeText: { ...type.body },
  errorText: { fontFamily: "monospace", fontSize: 12, lineHeight: 18 },
  refreshBtn: { marginTop: space.md, alignItems: "center", padding: space.sm },
  refreshBtnText: { color: colors.primary, fontWeight: "600" },
  runCard: {
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.card,
    padding: space.lg,
    marginTop: space.md,
  },
  runStatus: { fontWeight: "700", color: colors.text, marginBottom: space.xs },
  runDate: { color: colors.textMuted, fontSize: 12, marginBottom: space.xs },
  runLink: { color: colors.primary, fontWeight: "600" },
});
