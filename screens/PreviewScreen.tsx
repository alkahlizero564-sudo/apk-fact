import React, { useCallback, useState } from "react";
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, ActivityIndicator, Alert } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { WebView } from "react-native-webview";
import { listDir, getFileText, deleteFolder } from "../services/github";
import { REPO } from "../services/config";

export default function PreviewScreen() {
  const [apps, setApps] = useState<string[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [html, setHtml] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setError(null);
    setLoading(true);
    try {
      setApps(await listDir(REPO, "apps"));
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      setSelected(null);
      setHtml(null);
      refresh();
    }, [refresh])
  );

  async function openApp(name: string) {
    setSelected(name);
    setHtml(null);
    setError(null);
    setLoading(true);
    try {
      const text = await getFileText(REPO, `apps/${name}/index.html`);
      if (!text) throw new Error("الملف مش موجود.");
      setHtml(text);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  function confirmDelete(name: string) {
    Alert.alert("حذف التطبيق", `متأكد تبغى تحذف "${name}"؟ ما يمكن التراجع.`, [
      { text: "إلغاء", style: "cancel" },
      { text: "حذف", style: "destructive", onPress: () => doDelete(name) },
    ]);
  }

  async function doDelete(name: string) {
    setError(null);
    setLoading(true);
    try {
      await deleteFolder(REPO, `apps/${name}`);
      setSelected(null);
      setHtml(null);
      setApps(await listDir(REPO, "apps"));
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.topRow}>
        <Text style={styles.title}>تطبيقاتك</Text>
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

      {selected && (
        <View style={styles.actionRow}>
          <Text style={styles.selectedName}>{selected}</Text>
          <TouchableOpacity style={styles.deleteBtn} onPress={() => confirmDelete(selected)} disabled={loading}>
            <Text style={styles.deleteText}>🗑 حذف</Text>
          </TouchableOpacity>
        </View>
      )}

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
  topRow: { flexDirection: "row", alignItems: "center", padding: 12, borderBottomWidth: 1, borderColor: "#eee" },
  title: { fontWeight: "700", fontSize: 16 },
  refreshBtn: { marginLeft: "auto", padding: 6 },
  refreshText: { color: "#2563eb" },
  appsBar: { maxHeight: 46, borderBottomWidth: 1, borderColor: "#eee" },
  appTab: { paddingVertical: 12, paddingHorizontal: 14, marginRight: 4 },
  appTabActive: { borderBottomWidth: 2, borderColor: "#111" },
  appTabText: { color: "#888" },
  appTabTextActive: { color: "#111", fontWeight: "700" },
  actionRow: { flexDirection: "row", alignItems: "center", padding: 10, borderBottomWidth: 1, borderColor: "#eee" },
  selectedName: { flex: 1, fontWeight: "700" },
  deleteBtn: { borderWidth: 1, borderColor: "#c0392b", borderRadius: 10, paddingVertical: 6, paddingHorizontal: 14 },
  deleteText: { color: "#c0392b", fontWeight: "700" },
  error: { color: "#c0392b", margin: 16 },
  empty: { alignItems: "center", justifyContent: "center", padding: 24 },
  emptyText: { textAlign: "center", color: "#666", lineHeight: 22 },
});
