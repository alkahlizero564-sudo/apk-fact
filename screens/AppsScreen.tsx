import React, { useCallback, useState } from "react";
import { View, Text, TextInput, StyleSheet, Pressable, RefreshControl, ScrollView, ActivityIndicator } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "../components/icons";
import { EmptyState, Button, Banner } from "../components/ui";
import { AppAvatar } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { colors, space } from "../theme";
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
      <Text style={styles.title}>تطبيقاتي</Text>
      <Text style={styles.subtitle}>{apps ? `${apps.length} تطبيق` : "جاري التحميل…"}</Text>

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

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filters}>
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
      </ScrollView>

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

      <View style={styles.list}>
        {shown.map((a) => (
          <Pressable
            key={a.name}
            onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
            style={({ pressed }) => [styles.item, pressed && { backgroundColor: colors.glassStrong }]}
            accessibilityRole="button"
            accessibilityLabel={`${a.name}، ${LANGS[a.lang].label}`}
          >
            <AppAvatar name={a.name} lang={a.lang} size={52} />
            <View style={{ flex: 1 }}>
              <Text style={styles.name} numberOfLines={1}>
                {a.name}
              </Text>
              <Text style={styles.meta} numberOfLines={1}>
                {LANGS[a.lang].label} · {LANGS[a.lang].tools}
              </Text>
            </View>
            <Ionicons name="chevron-back" size={18} color={colors.glassBorderStrong} />
          </Pressable>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space.lg, paddingBottom: 140 },
  title: { color: colors.text, fontSize: 32, fontWeight: "700", textAlign: "right" },
  subtitle: { color: colors.textMuted, fontSize: 14, textAlign: "right", marginTop: 4, marginBottom: space.lg },

  search: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    height: 52,
    paddingHorizontal: space.lg,
    borderRadius: 999,
    backgroundColor: CARD,
  },
  searchInput: { flex: 1, color: colors.text, fontSize: 15, paddingVertical: 0 },

  filters: { flexDirection: "row-reverse", gap: space.sm, paddingVertical: space.lg },
  filter: { paddingVertical: 9, paddingHorizontal: 18, borderRadius: 999, backgroundColor: CARD },
  filterOn: { backgroundColor: colors.primary },
  filterText: { color: SOFT_TEXT, fontSize: 13, fontWeight: "600" },

  list: { gap: space.sm },
  item: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    padding: space.md,
    borderRadius: 24,
    backgroundColor: CARD,
  },
  name: { color: colors.text, fontSize: 16, fontWeight: "700", textAlign: "right" },
  meta: { color: colors.faint, fontSize: 12.5, textAlign: "right", marginTop: 3 },
});
