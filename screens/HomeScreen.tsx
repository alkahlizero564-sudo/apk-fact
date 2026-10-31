import React, { useCallback, useState } from "react";
import { View, Text, StyleSheet, Pressable, ActivityIndicator } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "@expo/vector-icons";
import { Screen, Section, Card, Chip, ListRow, EmptyState, Button, Banner } from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { TEMPLATES } from "../services/templates";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { colors, gradient, langColors, space, radius, type } from "../theme";
import type { RootStackParamList } from "../navigation";

type Nav = NativeStackNavigationProp<RootStackParamList>;

export default function HomeScreen() {
  const nav = useNavigation<Nav>();
  const [apps, setApps] = useState<AppInfo[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Lang | "all">("all");
  const [showAll, setShowAll] = useState(false);

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      listApps()
        .then((a) => alive && (setApps(a), setError(null)))
        .catch((e) => alive && setError(e.message));
      return () => {
        alive = false;
      };
    }, [])
  );

  const templates = TEMPLATES.filter((t) => filter === "all" || t.lang === filter);
  const shown = showAll ? templates : templates.slice(0, 4);
  const count = (l: Lang) => (apps ?? []).filter((a) => a.lang === l).length;

  return (
    <Screen title="أهلاً بيك 👋" subtitle="شنو التطبيق الجاي اللي حنبنيه؟">
      <LinearGradient colors={gradient} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={styles.hero}>
        <View style={styles.heroOrb} />
        <View style={styles.heroOrb2} />
        <View style={styles.heroTag}>
          <Text style={styles.heroTagText}>ذكاء اصطناعي · إصلاح تلقائي · APK</Text>
          <Ionicons name="sparkles" size={13} color={colors.primaryText} />
        </View>
        <Text style={styles.heroTitle}>ابنِ تطبيقك في دقائق</Text>
        <Text style={styles.heroText}>صف فكرتك أو اختار قالب، ونحن نكتب الكود ونصلّح أخطاءه ونبني لك APK.</Text>
        <Pressable
          onPress={() => nav.navigate("Create")}
          style={({ pressed }) => [styles.heroBtn, pressed && { transform: [{ scale: 0.98 }] }]}
          accessibilityRole="button"
        >
          <Text style={styles.heroBtnText}>تطبيق جديد</Text>
          <Ionicons name="add-circle" size={22} color={colors.primary} />
        </Pressable>
      </LinearGradient>

      <View style={styles.stats}>
        {LANG_ORDER.map((l) => (
          <View key={l} style={styles.stat}>
            <Ionicons name={LANG_ICONS[l]} size={20} color={langColors[l]} />
            <Text style={styles.statNum}>{apps ? count(l) : "–"}</Text>
            <Text style={styles.statLabel}>{LANGS[l].label}</Text>
          </View>
        ))}
      </View>

      <Section
        title="قوالب جاهزة"
        action={
          <Pressable onPress={() => setShowAll((s) => !s)} hitSlop={8}>
            <Text style={styles.link}>{showAll ? "أقل" : `الكل (${templates.length})`}</Text>
          </Pressable>
        }
      >
        <View style={styles.chips}>
          <Chip label="الكل" selected={filter === "all"} onPress={() => setFilter("all")} />
          {LANG_ORDER.map((l) => (
            <Chip
              key={l}
              label={LANGS[l].label}
              icon={LANG_ICONS[l]}
              tint={langColors[l]}
              selected={filter === l}
              onPress={() => setFilter(l)}
            />
          ))}
        </View>
        <View style={styles.grid}>
          {shown.map((t) => (
            <Pressable
              key={t.id}
              onPress={() => nav.navigate("Create", { templateId: t.id })}
              style={({ pressed }) => [styles.tpl, pressed && { transform: [{ scale: 0.97 }] }]}
              accessibilityRole="button"
              accessibilityLabel={`قالب ${t.title}`}
            >
              <View style={[styles.tplIcon, { backgroundColor: t.color + "24" }]}>
                <Ionicons name={t.icon} size={26} color={t.color} />
              </View>
              <Text style={styles.tplTitle} numberOfLines={1}>
                {t.title}
              </Text>
              <Text style={styles.tplDesc} numberOfLines={2}>
                {t.description}
              </Text>
<View style={styles.tplFoot}>
                <LangBadge lang={t.lang} />
                <Pressable
                  onPress={() => nav.navigate("InstantPreview", { templateId: t.id })}
                  hitSlop={8}
                  style={({ pressed }) => [styles.eye, pressed && { opacity: 0.7 }]}
                  accessibilityRole="button"
                  accessibilityLabel={`معاينة ${t.title}`}
                >
                  <Ionicons name={t.lang === "html" ? "flash" : "eye-outline"} size={15} color={colors.infoText} />
                </Pressable>
              </View>
            </Pressable>
          ))}
        </View>
      </Section>

      <Section
        title="أحدث تطبيقاتك"
        action={
          apps && apps.length > 0 ? (
            <Pressable onPress={() => nav.navigate("Tabs", { screen: "Apps" } as never)} hitSlop={8}>
              <Text style={styles.link}>عرض الكل</Text>
            </Pressable>
          ) : undefined
        }
      >
        {error ? <Banner kind="error" text={error} /> : null}
        {!apps && !error ? <ActivityIndicator color={colors.accent} style={{ marginVertical: space.xl }} /> : null}
        {apps && apps.length === 0 ? (
          <Card>
            <EmptyState
              icon="rocket-outline"
              title="لسه ما بنيت تطبيق"
              text="ابدأ بقالب أو من الصفر، وأول تطبيق بيكون جاهز خلال دقائق."
              action={<Button title="ابدأ الآن" icon="add" onPress={() => nav.navigate("Create")} />}
            />
          </Card>
        ) : null}
        {apps && apps.length > 0 ? (
          <Card style={{ padding: 0, overflow: "hidden" }}>
            {apps.slice(-5).reverse().map((a, i, arr) => (
              <ListRow
                key={a.name}
                title={a.name}
                subtitle={LANGS[a.lang].tools}
                leading={<AppAvatar name={a.name} lang={a.lang} size={40} />}
                onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
                last={i === arr.length - 1}
              />
            ))}
          </Card>
        ) : null}
      </Section>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { borderRadius: 28, padding: space.xl, overflow: "hidden", marginBottom: space.lg },
  heroOrb: {
    position: "absolute",
    width: 200,
    height: 200,
    borderRadius: 100,
    left: -70,
    top: -70,
    backgroundColor: "rgba(255,255,255,0.12)",
  },
  heroOrb2: {
    position: "absolute",
    width: 120,
    height: 120,
    borderRadius: 60,
    left: 60,
    bottom: -60,
    backgroundColor: "rgba(45,212,191,0.25)",
  },
  heroTag: {
    flexDirection: "row-reverse",
    alignItems: "center",
    alignSelf: "flex-end",
    gap: 6,
    paddingVertical: 5,
    paddingHorizontal: 12,
    borderRadius: radius.pill,
    backgroundColor: "rgba(255,255,255,0.16)",
  },
  heroTagText: { color: colors.primaryText, fontSize: 12, fontWeight: "700" },
  heroTitle: { ...type.hero, fontSize: 26, color: colors.primaryText, textAlign: "right", marginTop: space.lg },
  heroText: { ...type.body, color: "rgba(255,255,255,0.88)", textAlign: "right", marginTop: space.sm },
  heroBtn: {
    marginTop: space.lg,
    alignSelf: "flex-end",
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    backgroundColor: colors.primaryText,
    paddingVertical: 12,
    paddingHorizontal: space.xl,
    borderRadius: radius.pill,
  },
  heroBtnText: { color: colors.primary, fontWeight: "900", fontSize: 16 },

  stats: { flexDirection: "row-reverse", gap: space.sm, marginBottom: space.xl },
  stat: {
    flex: 1,
    alignItems: "center",
    gap: 2,
    paddingVertical: space.md,
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.border,
  },
  statNum: { fontSize: 22, fontWeight: "900", color: colors.text, marginTop: 4 },
  statLabel: { fontSize: 12, color: colors.textMuted, fontWeight: "700" },

  link: { color: colors.infoText, fontWeight: "800", fontSize: 13 },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginBottom: space.md },
  grid: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.md },
  tpl: {
    width: "47.8%",
    padding: space.md,
    gap: space.sm,
    borderRadius: radius.card,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  tplIcon: { width: 48, height: 48, borderRadius: 16, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" },
  tplTitle: { color: colors.text, fontWeight: "800", fontSize: 15, textAlign: "right" },
  tplDesc: { color: colors.textMuted, fontSize: 12, lineHeight: 17, textAlign: "right" },
  tplFoot: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  eye: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.primarySoft,
  },
});
