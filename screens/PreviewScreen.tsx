import React, { useCallback, useState } from "react";
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, ActivityIndicator } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { WebView } from "react-native-webview";
import * as SecureStore from "expo-secure-store";
import { listDir, getFileText } from "../services/github";

type Slot = "1" | "2";

export default function PreviewScreen() {
  const [slot, setSlot] = useState<Slot>("1");
  const [apps, setApps] = useState<string[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [html, setHtml] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function getRepo() {
    return SecureStore.getItemAsync(slot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
  }

  async function openApp(name: string) {
    setSelected(name);
    setHtml(null);
    setError(null);
    setLoading(true);
    try {
      const repo = await getRepo();
      if (!repo) throw new Error("حط المستودع في تبويب المفاتيح.");
      const text = await getFileText(repo, `apps/${name}/index.html`);
      if (!text) throw new Error("الملف مش موجود.");
      setHtml(text);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  const refresh = useCallback(async () => {
    setError(null);
    setLoading(true);
    try {
      const repo = await SecureStore.getItemAsync(slot === "1" ? "GITHUB_REPO_1" : "GITHUB_REPO_2");
      if (!repo) {
        setApps([]);
        setError("حط المستودع في تبويب المفاتيح.");
        return;
      }
      const list = await listDir(repo, "apps");
      setApps(list);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [slot]);

  useFocusEffect(
    useCallback(() => {
      setSelected(null);
      setHtml(null);
      refresh();
    }, [refresh])
  );

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.topRow}>
        <TouchableOpacity style={[styles.pill, slot === "1" && styles.pillActive]} onPress={() => setSlot("1")}>
          <Text style={slot === "1" ? styles.pillTextActive : styles.pillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.pill, slot === "2" && styles.pillActive]} onPress={() => setSlot("2")}>
          <Text style={slot === "2" ? styles.pillTextActive : styles.pillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.refreshBtn} onPress={refresh}>
          <Text style={styles.refreshText}>تحديث ↻</Text>
        </TouchableOpacity>
      </View>

      <ScrollView horizontal style={styles.appsBar} contentContainerStyle={{ paddingHorizontal: 8 }}>
        {apps.map((a) => (
          <TouchableOpacity
            key={a}
            style={[styles.appTab, selected === a && styles.appTabActive]}
            onPress={() => openApp(a)}
          >
            <Text style={selected === a ? styles.appTabTextActive : styles.appTabText}>{a}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {loading && <ActivityIndicator style={{ marginTop: 16 }} />}
      {error && <Text style={styles.error}>❌ {error}</Text>}

      {!loading && !error && apps.length === 0 && (
        <View style={styles.empty}>
          <Text style={styles.emptyText}>لسه مفيش تطبيقات. روح لتبويب "الإنشاء" واعمل أول تطبيق.</Text>
        </View>
      )}

      {!loading && !selected && apps.length > 0 && (
        <View style={styles.empty}>
          <Text style={styles.emptyText}>اختر تطبيق من الأعلى عشان تعاينه.</Text>
        </View>
      )}

      {html && <WebView originWhitelist={["*"]} source={{ html }} style={{ flex: 1 }} />}
    </View>
  );
}

const styles = StyleSheet.create({
  topRow: { flexDirection: "row", alignItems: "center", padding: 10, borderBottomWidth: 1, borderColor: "#eee" },
  pill: { borderWidth: 1, borderColor: "#ccc", borderRadius: 20, paddingVertical: 6, paddingHorizontal: 14, marginRight: 8 },
  pillActive: { backgroundColor: "#111", borderColor: "#111" },
  pillText: { color: "#111" },
  pillTextActive: { color: "#fff" },
  refreshBtn: { marginLeft: "auto", padding: 6 },
  refreshText: { color: "#2563eb" },
  appsBar: { maxHeight: 46, borderBottomWidth: 1, borderColor: "#eee" },
  appTab: { paddingVertical: 12, paddingHorizontal: 14, marginRight: 4 },
  appTabActive: { borderBottomWidth: 2, borderColor: "#111" },
  appTabText: { color: "#888" },
  appTabTextActive: { color: "#111", fontWeight: "700" },
  error: { color: "#c0392b", margin: 16 },
  empty: { alignItems: "center", justifyContent: "center", padding: 24 },
  emptyText: { textAlign: "center", color: "#666", lineHeight: 22 },
});
