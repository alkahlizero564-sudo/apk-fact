import React, { useCallback, useState } from "react";
import { View, Text, StyleSheet, Pressable, RefreshControl, ScrollView, ActivityIndicator } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { Field, Segmented, EmptyState, Button, Banner, Card } from "../components/ui";
import { AppAvatar, LangBadge } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { LANGS, Lang } from "../services/langs";
import { colors, space, radius, type } from "../theme";
import type { RootStackParamList } from "../navigation";

type Nav = NativeStackNavigationProp<RootStackParamList>;

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

  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + space.md }]}
      keyboardShouldPersistTaps="handled"
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          tintColor={colors.accent}
          colors={[colors.primary]}
          onRefresh={async () => {
            setRefreshing(true);
            await load();
            setRefreshing(false);
          }}
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.title}>تطبيقاتي</Text>
        <Text style={styles.subtitle}>{apps ? `${apps.length} تطبيق` : "جاري التحميل…"}</Text>
      </View>

      <Field label="بحث" icon="search-outline" value={query} onChangeText={setQuery} placeholder="اسم التطبيق" ltr autoCapitalize="none" />
      <Segmented
        value={filter}
        onChange={setFilter}
        options={[
          { value: "all", label: "الكل" },
          { value: "html", label: LANGS.html.label },
          { value: "flutter", label: LANGS.flutter.label },
          { value: "kotlin", label: LANGS.kotlin.label },
          { value: "python", label: LANGS.python.label },
        ]}
      />

      <View style={{ height: space.lg }} />
      {error ? <Banner kind="error" text={error} /> : null}
      {!apps && !error ? <ActivityIndicator color={colors.accent} style={{ marginTop: space.xxl }} /> : null}

      {apps && apps.length === 0 ? (
        <Card>
          <EmptyState
            icon="apps-outline"
            title="ما في تطبيقات لسه"
            text="كل تطبيق تبنيه بيظهر هنا، ومن صفحته تعاينه وتبنيه وتعدّله."
            action={<Button title="أنشئ أول تطبيق" icon="add" onPress={() => nav.navigate("Create")} />}
          />
        </Card>
      ) : null}
      {apps && apps.length > 0 && shown.length === 0 ? (
        <EmptyState icon="search-outline" title="ما في نتائج" text="جرّب اسم تاني أو غيّر الفلتر." />
      ) : null}

      <View style={styles.grid}>
        {shown.map((a) => (
          <Pressable
            key={a.name}
            onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
            style={({ pressed }) => [styles.card, pressed && { transform: [{ scale: 0.97 }] }]}
            accessibilityRole="button"
            accessibilityLabel={`${a.name}، ${LANGS[a.lang].label}`}
          >
            <View style={styles.cardTop}>
              <AppAvatar name={a.name} lang={a.lang} size={50} />
              <Ionicons name="chevron-back" size={18} color={colors.textMuted} />
            </View>
            <Text style={styles.name} numberOfLines={1}>
              {a.name}
            </Text>
            <LangBadge lang={a.lang} />
          </Pressable>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space.lg, paddingBottom: 140 },
  header: { marginBottom: space.lg },
  title: { ...type.screenTitle, fontSize: 28, fontWeight: "800", color: colors.text, textAlign: "right" },
  subtitle: { ...type.body, color: colors.textMuted, textAlign: "right" },
  grid: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.md },
  card: {
    width: "47.8%",
    padding: space.lg,
    gap: space.sm,
    borderRadius: radius.card,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  cardTop: { flexDirection: "row-reverse", justifyContent: "space-between", alignItems: "flex-start", marginBottom: space.sm },
  name: { fontSize: 16, fontWeight: "800", color: colors.text, textAlign: "right" },
});
