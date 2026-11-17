import React, { useCallback, useState } from "react";
import { View, Text, TextInput, StyleSheet, Pressable, RefreshControl, ScrollView, ActivityIndicator } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "../components/icons";
import { EmptyState, Button, Banner, RtlRow } from "../components/ui";
import { AppAvatar } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { LinearGradient } from "expo-linear-gradient";
import { colors, gradient, langColors, space } from "../theme";
import type { RootStackParamList } from "../navigation";

type Nav = NativeStackNavigationProp<RootStackParamList>;

const CARD = colors.glass;
const SOFT_TEXT = colors.softText;

export default function AppsScreen() {
  const nav = useNavigation<Nav>();
  const insets = useSafeAreaInsets();
  const [apps, setApps] = useState<AppInfo[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Lang | "all">("all");

  const load = useCallback(async () => {
    try {
      setApps(await listApps());
      setError(null);
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  const q = query.trim().toLowerCase();
  const shown = (apps ?? []).filter((a) => (filter === "all" || a.lang === filter) && a.name.includes(q));
  const filters: { value: Lang | "all"; label: string }[] = [
    { value: "all", label: "الكل" },
    ...LANG_ORDER.map((l) => ({ value: l as Lang | "all", label: LANGS[l].label })),
  ];

  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + space.lg }]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          tintColor={colors.accent}
          colors={[colors.accent]}
          progressBackgroundColor={colors.glassStrong}
          onRefresh={async () => {
            setRefreshing(true);
            await load();
            setRefreshing(false);
          }}
        />
      }
    >
      <View style={styles.head}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>تطبيقاتي</Text>
          <Text style={styles.subtitle}>{apps ? `${apps.length} تطبيق · ${(apps ?? []).filter((a) => a.name.endsWith("-customer")).length} نظام متصل` : "جاري التحميل…"}</Text>
        </View>
        <Pressable onPress={() => nav.navigate("Create")} style={({ pressed }) => [styles.newBtn, pressed && { transform: [{ scale: 0.94 }] }]} accessibilityRole="button" accessibilityLabel="تطبيق جديد">
          <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
          <Ionicons name="add" size={26} color={colors.primaryText} />
        </Pressable>
      </View>

      <View style={styles.search}>
        <Ionicons name="search-outline" size={18} color={colors.faint} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder="ابحث باسم التطبيق"
          placeholderTextColor={colors.faint}
          autoCapitalize="none"
          autoCorrect={false}
          style={styles.searchInput}
          textAlign="right"
        />
        {query ? (
          <Pressable onPress={() => setQuery("")} hitSlop={10} accessibilityLabel="مسح">
            <Ionicons name="close-circle" size={18} color={colors.faint} />
          </Pressable>
        ) : null}
      </View>

      <RtlRow contentContainerStyle={styles.filters}>
        {filters.map((f) => {
          const on = filter === f.value;
          return (
            <Pressable
              key={f.value}
              onPress={() => setFilter(f.value)}
              style={[styles.filter, on && styles.filterOn]}
              accessibilityRole="button"
              accessibilityState={{ selected: on }}
            >
              <Text style={[styles.filterText, on && { color: colors.primaryText, fontWeight: "700" }]}>{f.label}</Text>
            </Pressable>
          );
        })}
      </RtlRow>

      {error ? <Banner kind="error" text={error} /> : null}
      {!apps && !error ? <ActivityIndicator color={colors.accent} style={{ marginTop: space.xxl }} /> : null}

      {apps && apps.length === 0 ? (
        <EmptyState
          icon="apps-outline"
          title="ما في تطبيقات لسه"
          text="كل تطبيق تبنيه بيظهر هنا، ومن صفحته تعاينه وتبنيه وتعدّله."
          action={<Button title="أنشئ أول تطبيق" icon="add" onPress={() => nav.navigate("Create")} />}
        />
      ) : null}
      {apps && apps.length > 0 && shown.length === 0 ? (
        <EmptyState icon="search-outline" title="ما في نتائج" text="جرّب اسم تاني أو غيّر الفلتر." />
      ) : null}

      <View style={styles.grid}>
        {shown.map((a) => {
          const role = a.name.endsWith("-customer") ? "زبون" : a.name.endsWith("-admin") ? "إدارة" : null;
          return (
            <Pressable
              key={a.name}
              onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
              style={({ pressed }) => [styles.card, pressed && { transform: [{ scale: 0.97 }], backgroundColor: colors.glassStrong }]}
              accessibilityRole="button"
              accessibilityLabel={`${a.name}، ${LANGS[a.lang].label}`}
            >
              {role ? (
                <View style={[styles.role, role === "إدارة" && { backgroundColor: colors.primarySoft, borderColor: colors.primary }]}>
                  <Text style={styles.roleText}>{role}</Text>
                </View>
              ) : null}
              <View style={[styles.halo, { backgroundColor: langColors[a.lang] + "22", borderColor: langColors[a.lang] + "55" }]}>
                <AppAvatar name={a.name} lang={a.lang} size={58} />
              </View>
              <Text style={styles.name} numberOfLines={1}>
                {a.name}
              </Text>
              <View style={[styles.langPill, { backgroundColor: langColors[a.lang] + "24" }]}>
                <Text style={[styles.langText, { color: langColors[a.lang] }]}>{LANGS[a.lang].label}</Text>
              </View>
            </Pressable>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space.lg, paddingBottom: 140 },
  title: { color: colors.text, fontSize: 30, fontWeight: "800", textAlign: "right" },
  subtitle: { color: colors.textMuted, fontSize: 13.5, textAlign: "right", marginTop: 4 },

  search: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    height: 52,
    paddingHorizontal: space.lg,
    borderRadius: 999,
    backgroundColor: CARD,
    borderWidth: 1,
    borderColor: colors.glassBorder,
  },
  searchInput: { flex: 1, color: colors.text, fontSize: 15, paddingVertical: 0 },

  filters: { flexDirection: "row-reverse", gap: space.sm, paddingVertical: space.lg },
  filter: { paddingVertical: 9, paddingHorizontal: 18, borderRadius: 999, backgroundColor: CARD },
  filterOn: { backgroundColor: colors.primary },
  filterText: { color: SOFT_TEXT, fontSize: 13, fontWeight: "600" },

  head: { flexDirection: "row-reverse", alignItems: "center", gap: space.md, marginBottom: space.lg },
  newBtn: { width: 50, height: 50, borderRadius: 25, overflow: "hidden", alignItems: "center", justifyContent: "center", shadowColor: colors.glow, shadowOpacity: 0.7, shadowRadius: 12, elevation: 10 },
  grid: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.md },
  card: { width: "47.8%", alignItems: "center", gap: space.sm, paddingVertical: space.lg, paddingHorizontal: space.md, borderRadius: 26, backgroundColor: CARD, borderWidth: 1, borderColor: colors.glassBorder },
  halo: { width: 82, height: 82, borderRadius: 41, borderWidth: 1, alignItems: "center", justifyContent: "center", marginBottom: 4 },
  role: { position: "absolute", top: 10, left: 10, paddingHorizontal: 8, paddingVertical: 2, borderRadius: 999, backgroundColor: "rgba(34,211,238,0.16)", borderWidth: 1, borderColor: colors.accent },
  roleText: { color: colors.text, fontSize: 10.5, fontWeight: "800" },
  name: { color: colors.text, fontSize: 15, fontWeight: "800", textAlign: "center" },
  langPill: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 999 },
  langText: { fontSize: 11.5, fontWeight: "800" },
});
