import React, { useCallback, useState } from "react";
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, ActivityIndicator, Alert } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { WebView } from "react-native-webview";
import { Ionicons } from "@expo/vector-icons";
import { listDir, getFileText, deleteFolder } from "../services/github";
import { REPO } from "../services/config";
import { LANGS, Lang, detectLang } from "../services/langs";
import { colors, langColors, space, radius, type } from "../theme";

export default function PreviewScreen() {
  const [apps, setApps] = useState<string[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [html, setHtml] = useState<string | null>(null);
  const [lang, setLang] = useState<Lang | null>(null);
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
    setLang(null);
    setError(null);
    setLoading(true);
    try {
      const appLang = await detectLang(REPO, name);
      setLang(appLang);
      const text = await getFileText(
        REPO,
        appLang === "html" ? `apps/${name}/index.html` : `apps/${name}/preview.html`
      );
      if (!text) {
        throw new Error(
          appLang === "html"
            ? "الملف مش موجود."
            : "لسه ما في معاينة. من تبويب الإنشاء اضغط \"معاينة جديدة بالذكاء الاصطناعي\"."
        );
      }
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
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <View style={styles.topRow}>
        <Text style={styles.title}>تطبيقاتك</Text>
        <TouchableOpacity onPress={refresh} hitSlop={8} style={styles.iconBtn} accessibilityLabel="تحديث">
          <Ionicons name="refresh" size={20} color={colors.infoText} />
        </TouchableOpacity>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.appsBar}
        contentContainerStyle={styles.appsBarContent}
      >
        {apps.map((a) => (
          <TouchableOpacity
            key={a}
            style={[styles.chip, selected === a && styles.chipActive]}
            onPress={() => openApp(a)}
            accessibilityRole="tab"
            accessibilityState={{ selected: selected === a }}
          >
            <Text style={[styles.chipText, selected === a && styles.chipTextActive]}>{a}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {selected && (
        <View style={styles.actionRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.selectedName} numberOfLines={1}>
              {selected}
            </Text>
            {lang && (
              <View style={styles.badgeRow}>
                <View style={[styles.badge, { borderColor: langColors[lang] }]}>
                  <Text style={[styles.badgeText, { color: langColors[lang] }]}>{LANGS[lang].label}</Text>
                </View>
                {lang !== "html" && (
                  <View style={[styles.badge, { borderColor: colors.accent }]}>
                    <Ionicons name="sparkles" size={12} color={colors.accent} />
                    <Text style={[styles.badgeText, { color: colors.accent }]}>معاينة بالذكاء الاصطناعي</Text>
                  </View>
                )}
              </View>
            )}
          </View>
          <TouchableOpacity
            style={[styles.deleteBtn, loading && { opacity: 0.5 }]}
            onPress={() => confirmDelete(selected)}
            disabled={loading}
            accessibilityLabel={`حذف ${selected}`}
          >
            <Ionicons name="trash-outline" size={16} color={colors.errorText} />
            <Text style={styles.deleteText}>حذف</Text>
          </TouchableOpacity>
        </View>
      )}

      {loading && <ActivityIndicator style={{ marginTop: space.lg }} color={colors.accent} />}
      {error && (
        <View style={styles.errorBox}>
          <Text style={styles.errorText}>❌ {error}</Text>
        </View>
      )}

      {!loading && !error && apps.length === 0 && (
        <View style={styles.empty}>
          <Ionicons name="phone-portrait-outline" size={48} color={colors.textMuted} />
          <Text style={styles.emptyTitle}>لسه مفيش تطبيقات</Text>
          <Text style={styles.emptyText}>روح لتبويب "الإنشاء" واعمل أول تطبيق.</Text>
        </View>
      )}

      {!loading && !selected && apps.length > 0 && (
        <View style={styles.empty}>
          <Ionicons name="eye-outline" size={48} color={colors.textMuted} />
          <Text style={styles.emptyTitle}>اختر تطبيق للمعاينة</Text>
          <Text style={styles.emptyText}>اضغط على اسم التطبيق من الشريط اللي فوق.</Text>
        </View>
      )}

      {html && <WebView originWhitelist={["*"]} source={{ html }} style={{ flex: 1 }} />}
    </View>
  );
}

const styles = StyleSheet.create({
  topRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: space.lg,
    paddingVertical: space.md,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  title: { ...type.sectionTitle, color: colors.text, flex: 1 },
  iconBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.surfaceAlt,
  },
  appsBar: {
    flexGrow: 0,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  appsBarContent: { paddingHorizontal: space.md, paddingVertical: space.sm, gap: space.sm },
  chip: {
    paddingVertical: space.sm,
    paddingHorizontal: space.lg,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.field,
  },
  chipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  chipText: { color: colors.textMuted, fontWeight: "600" },
  chipTextActive: { color: colors.primaryText, fontWeight: "700" },
  actionRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.md,
    paddingHorizontal: space.lg,
    paddingVertical: space.md,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  selectedName: { fontWeight: "700", fontSize: 16, color: colors.text },
  badgeRow: { flexDirection: "row", flexWrap: "wrap", gap: space.xs, marginTop: space.xs },
  badge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    borderWidth: 1,
    borderRadius: radius.pill,
    paddingHorizontal: space.sm,
    paddingVertical: 2,
  },
  badgeText: { fontSize: 11, fontWeight: "700" },
  deleteBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.xs,
    borderWidth: 1.5,
    borderColor: colors.errorText,
    borderRadius: radius.button,
    paddingVertical: space.sm,
    paddingHorizontal: space.lg,
  },
  deleteText: { color: colors.errorText, fontWeight: "700" },
  errorBox: {
    backgroundColor: colors.errorBg,
    borderRadius: radius.field,
    padding: space.md,
    margin: space.lg,
  },
  errorText: { color: colors.errorText, ...type.body },
  empty: { alignItems: "center", justifyContent: "center", padding: space.xxl, gap: space.sm },
  emptyTitle: { ...type.sectionTitle, color: colors.text, textAlign: "center" },
  emptyText: { ...type.body, color: colors.textMuted, textAlign: "center" },
});
