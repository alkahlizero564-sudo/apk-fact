import React, { useCallback, useState } from "react";
import { View, Text, ScrollView, StyleSheet, TouchableOpacity } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { WebView } from "react-native-webview";
import { loadGeneration, AppSlot } from "../services/store";
import { GenerationResult } from "../services/generate";

export default function PreviewScreen() {
  const [appSlot, setAppSlot] = useState<AppSlot>("1");
  const [result, setResult] = useState<GenerationResult | null>(null);
  const [activeFile, setActiveFile] = useState<string | null>(null);

  useFocusEffect(
    useCallback(() => {
      loadGeneration(appSlot).then((r) => {
        setResult(r);
        if (r) {
          const html = r.files.find((f) => f.path.endsWith(".html"));
          setActiveFile(html ? html.path : r.files[0]?.path ?? null);
        } else {
          setActiveFile(null);
        }
      });
    }, [appSlot])
  );

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.appSwitch}>
        <TouchableOpacity
          style={[styles.appPill, appSlot === "1" && styles.appPillActive]}
          onPress={() => setAppSlot("1")}
        >
          <Text style={appSlot === "1" ? styles.appPillTextActive : styles.appPillText}>التطبيق الأول</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.appPill, appSlot === "2" && styles.appPillActive]}
          onPress={() => setAppSlot("2")}
        >
          <Text style={appSlot === "2" ? styles.appPillTextActive : styles.appPillText}>التطبيق الثاني</Text>
        </TouchableOpacity>
      </View>

      {!result ? (
        <View style={styles.empty}>
          <Text style={styles.emptyText}>لسه مفيش حاجة اتعملت لهذا التطبيق. روح لتبويب "الإنشاء" الأول.</Text>
        </View>
      ) : (
        <PreviewBody result={result} activeFile={activeFile} setActiveFile={setActiveFile} />
      )}
    </View>
  );
}

function PreviewBody({
  result,
  activeFile,
  setActiveFile,
}: {
  result: GenerationResult;
  activeFile: string | null;
  setActiveFile: (f: string) => void;
}) {
  const file = result.files.find((f) => f.path === activeFile);
  const isHtml = file?.path.endsWith(".html");

  return (
    <View style={{ flex: 1 }}>
      <ScrollView horizontal style={styles.tabBar} contentContainerStyle={{ paddingHorizontal: 8 }}>
        {result.files.map((f) => (
          <TouchableOpacity
            key={f.path}
            style={[styles.fileTab, activeFile === f.path && styles.fileTabActive]}
            onPress={() => setActiveFile(f.path)}
          >
            <Text style={activeFile === f.path ? styles.fileTabTextActive : styles.fileTabText}>{f.path}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {isHtml && file ? (
        <WebView originWhitelist={["*"]} source={{ html: file.content }} style={{ flex: 1 }} />
      ) : (
        <ScrollView style={styles.codeBox}>
          <Text style={styles.codeText}>{file?.content}</Text>
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  appSwitch: { flexDirection: "row", padding: 10, gap: 8, borderBottomWidth: 1, borderColor: "#eee" },
  appPill: { borderWidth: 1, borderColor: "#ccc", borderRadius: 20, paddingVertical: 6, paddingHorizontal: 14, marginRight: 8 },
  appPillActive: { backgroundColor: "#111", borderColor: "#111" },
  appPillText: { color: "#111" },
  appPillTextActive: { color: "#fff" },
  empty: { flex: 1, alignItems: "center", justifyContent: "center", padding: 24 },
  emptyText: { textAlign: "center", color: "#666", lineHeight: 22 },
  tabBar: { maxHeight: 44, borderBottomWidth: 1, borderColor: "#eee" },
  fileTab: { paddingVertical: 10, paddingHorizontal: 14, marginRight: 4 },
  fileTabActive: { borderBottomWidth: 2, borderColor: "#111" },
  fileTabText: { color: "#888" },
  fileTabTextActive: { color: "#111", fontWeight: "700" },
  codeBox: { flex: 1, backgroundColor: "#0d0d0d", padding: 12 },
  codeText: { color: "#d4d4d4", fontFamily: "monospace", fontSize: 12 },
});
