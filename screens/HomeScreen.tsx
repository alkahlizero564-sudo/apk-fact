// Home — the "studio": a greeting, the idea composer (gradient frame), a 2×2 grid of big actions, a stats card,
// the latest apps and a row of templates.
import React, { useCallback, useState } from "react";
import { View, Text, TextInput, StyleSheet, Pressable, ScrollView, Image, Alert } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "../components/icons";
import { RtlRow } from "../components/ui";
import { AppAvatar } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { TEMPLATES } from "../services/templates";
import { LANGS } from "../services/langs";
import { getRefPics, setRefPics, RefPic, pickRefPics, MAX_PICS } from "../services/attachment";
import { colors, gradient, langColors, space } from "../theme";
import type { RootStackParamList } from "../navigation";

type Nav = NativeStackNavigationProp<RootStackParamList>;
type IconName = React.ComponentProps<typeof Ionicons>["name"];

const OWNER = "ماهر";

function greeting() {
  const h = new Date().getHours();
  return h < 12 ? "صباح الخير" : h < 18 ? "نهارك سعيد" : "مساء الخير";
}

const G = (c: readonly string[]) => c as unknown as string[];
const ACTIONS: { key: string; title: string; text: string; icon: IconName; colors: readonly string[] }[] = [
  { key: "Create", title: "تطبيق جديد", text: "من فكرة إلى APK", icon: "add-circle", colors: gradient },
  { key: "Pair", title: "زبون + إدارة", text: "تطبيقان متصلان", icon: "git-merge", colors: ["#22D3EE", "#3B82F6"] },
  { key: "Chat", title: "بناء بالدردشة", text: "احكِ والذكاء يبني", icon: "chatbubbles", colors: ["#EC4899", "#8B5CF6"] },
  { key: "Gallery", title: "معرض التصاميم", text: "آلاف التصاميم", icon: "color-palette", colors: ["#F59E0B", "#EC4899"] },
];

export default function HomeScreen() {
  const nav = useNavigation<Nav>();
  const insets = useSafeAreaInsets();
  const [text, setText] = useState("");
  const [pics, setPics] = useState<RefPic[]>([]);
  const [apps, setApps] = useState<AppInfo[] | null>(null);

  useFocusEffect(
    useCallback(() => {
      setPics(getRefPics());
      let alive = true;
      listApps().then((a) => alive && setApps(a)).catch(() => alive && setApps([]));
      return () => {
        alive = false;
      };
    }, [])
  );

  function updatePics(next: RefPic[]) {
    setPics(next);
    setRefPics(next);
  }

  async function pickImages() {
    try {
      const added = await pickRefPics(MAX_PICS - pics.length, pics);
      if (!added.length) return;
      updatePics([...pics, ...added].slice(0, MAX_PICS));
    } catch (e: any) {
      Alert.alert("تعذّر إرفاق الصور", e?.message ?? "جرّب مرة أخرى");
    }
  }

  function send() {
    if (text.trim().length < 10) {
      Alert.alert("الوصف قصير", "اكتب فكرتك في جملة أو جملتين على الأقل.");
      return;
    }
    nav.navigate("Create", { description: text.trim() });
    setText("");
  }

  const canSend = text.trim().length >= 10;
  const list = apps ?? [];
  const pairs = list.filter((a) => a.name.endsWith("-customer")).length;
  const langs = new Set(list.map((a) => a.lang)).size;
  const recent = list.slice(-4).reverse();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ paddingTop: insets.top + space.md, paddingHorizontal: space.lg, paddingBottom: 140 }}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {/* Header: greeting + account button */}
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.greet}>
            {greeting()}، {OWNER} 👋
          </Text>
          <Text style={styles.title}>شنو نبني اليوم؟</Text>
        </View>
        <Pressable
          onPress={() => nav.navigate("Tabs", { screen: "Settings" } as never)}
          style={styles.avatar}
          accessibilityRole="button"
          accessibilityLabel="الإعدادات"
        >
          <LinearGradient colors={G(gradient)} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
          <Text style={styles.avatarText}>{OWNER.slice(0, 1)}</Text>
        </Pressable>
      </View>

      {/* Idea composer in a gradient frame */}
      <LinearGradient colors={G(gradient)} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={styles.frame}>
        <View style={styles.composer}>
          <View style={styles.composerHead}>
            <Ionicons name="sparkles" size={16} color={colors.accent} />
            <Text style={styles.composerLabel}>صف فكرتك — والذكاء يبنيها</Text>
          </View>
          <TextInput
            value={text}
            onChangeText={setText}
            placeholder="مثلاً: تطبيق مطعم فيه منيو وطلبات وتوصيل…"
            placeholderTextColor={colors.faint}
            multiline
            maxLength={2000}
            style={styles.input}
            textAlign="right"
          />
          {pics.length > 0 ? (
            <RtlRow contentContainerStyle={styles.picsRow}>
              {pics.map((p, i) => (
                <View key={p.uri + i} style={styles.picWrap}>
                  <Image source={{ uri: p.uri }} style={styles.pic} />
                  <Pressable onPress={() => updatePics(pics.filter((_, j) => j !== i))} hitSlop={8} style={styles.picX} accessibilityLabel="حذف الصورة">
                    <Ionicons name="close" size={13} color={colors.text} />
                  </Pressable>
                </View>
              ))}
            </RtlRow>
          ) : null}
          <View style={styles.composerFoot}>
            <View style={{ flexDirection: "row-reverse", gap: space.sm }}>
              <Pressable
                onPress={pickImages}
                disabled={pics.length >= MAX_PICS}
                style={({ pressed }) => [styles.tool, pressed && { opacity: 0.7 }, pics.length >= MAX_PICS && { opacity: 0.4 }]}
                accessibilityRole="button"
                accessibilityLabel="إرفاق صور"
              >
                <Ionicons name="images" size={17} color={colors.softText} />
                <Text style={styles.toolText}>{pics.length > 0 ? `${pics.length}/${MAX_PICS}` : "صور"}</Text>
              </Pressable>
              <Pressable onPress={() => nav.navigate("Chat")} style={({ pressed }) => [styles.tool, pressed && { opacity: 0.7 }]} accessibilityRole="button" accessibilityLabel="بناء بالدردشة">
                <Ionicons name="chatbubble-ellipses" size={17} color={colors.softText} />
                <Text style={styles.toolText}>دردشة</Text>
              </Pressable>
            </View>
            <Pressable
              onPress={send}
              style={({ pressed }) => [styles.send, !canSend && { opacity: 0.4 }, pressed && { transform: [{ scale: 0.94 }] }]}
              accessibilityRole="button"
              accessibilityLabel="ابدأ"
            >
              <LinearGradient colors={G(gradient)} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
              <Ionicons name="arrow-up" size={22} color={colors.primaryText} />
            </Pressable>
          </View>
        </View>
      </LinearGradient>

      {/* 2×2 action grid */}
      <View style={styles.grid}>
        {ACTIONS.map((a) => (
          <Pressable
            key={a.key}
            onPress={() => nav.navigate(a.key as never)}
            style={({ pressed }) => [styles.tile, pressed && { transform: [{ scale: 0.97 }] }]}
            accessibilityRole="button"
            accessibilityLabel={a.title}
          >
            <LinearGradient colors={G(a.colors)} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={styles.tileIcon}>
              <Ionicons name={a.icon} size={24} color="#FFFFFF" />
            </LinearGradient>
            <Text style={styles.tileTitle}>{a.title}</Text>
            <Text style={styles.tileText}>{a.text}</Text>
          </Pressable>
        ))}
      </View>

      {/* Stats */}
      <View style={styles.stats}>
        {[
          { n: apps ? list.length : "–", l: "تطبيقات" },
          { n: apps ? pairs : "–", l: "أنظمة متصلة" },
          { n: apps ? langs : "–", l: "لغات" },
        ].map((s, i) => (
          <React.Fragment key={s.l}>
            {i > 0 ? <View style={styles.statSep} /> : null}
            <View style={styles.stat}>
              <Text style={styles.statNum}>{s.n}</Text>
              <Text style={styles.statLabel}>{s.l}</Text>
            </View>
          </React.Fragment>
        ))}
      </View>

      {/* Latest apps */}
      {recent.length > 0 ? (
        <>
          <View style={styles.secHead}>
            <Text style={styles.secTitle}>آخر تطبيقاتك</Text>
            <Pressable onPress={() => nav.navigate("Tabs", { screen: "Apps" } as never)} hitSlop={8}>
              <Text style={styles.secLink}>عرض الكل</Text>
            </Pressable>
          </View>
          <View style={styles.recent}>
            {recent.map((a, i) => (
              <Pressable
                key={a.name}
                onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
                style={({ pressed }) => [styles.recentRow, i < recent.length - 1 && styles.recentSep, pressed && { backgroundColor: colors.glassStrong }]}
              >
                <AppAvatar name={a.name} lang={a.lang} size={42} />
                <View style={{ flex: 1 }}>
                  <Text style={styles.recentName} numberOfLines={1}>
                    {a.name}
                  </Text>
                  <Text style={[styles.recentLang, { color: langColors[a.lang] }]}>{LANGS[a.lang].label}</Text>
                </View>
                <Ionicons name="chevron-back" size={18} color={colors.faint} />
              </Pressable>
            ))}
          </View>
        </>
      ) : null}

      {/* Templates */}
      <View style={styles.secHead}>
        <Text style={styles.secTitle}>ابدأ من قالب</Text>
      </View>
      <RtlRow contentContainerStyle={styles.tplRow}>
        {TEMPLATES.map((t) => (
          <Pressable
            key={t.id}
            onPress={() => nav.navigate("Create", { templateId: t.id })}
            style={({ pressed }) => [styles.tpl, pressed && { transform: [{ scale: 0.97 }] }]}
            accessibilityRole="button"
            accessibilityLabel={`قالب ${t.title}`}
          >
            <View style={[styles.tplIcon, { backgroundColor: t.color + "2E", borderColor: t.color + "66" }]}>
              <Ionicons name={t.icon} size={22} color={t.color} />
            </View>
            <Text style={styles.tplTitle} numberOfLines={1}>
              {t.title}
            </Text>
            <Text style={[styles.tplLang, { color: langColors[t.lang] }]}>{LANGS[t.lang].label}</Text>
          </Pressable>
        ))}
      </RtlRow>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: "row-reverse", alignItems: "center", gap: space.md, marginBottom: space.lg },
  greet: { color: colors.textMuted, fontSize: 14, textAlign: "right" },
  title: { color: colors.text, fontSize: 28, fontWeight: "800", textAlign: "right", marginTop: 2 },
  avatar: { width: 48, height: 48, borderRadius: 24, overflow: "hidden", alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: colors.glassBorderStrong },
  avatarText: { color: "#FFFFFF", fontSize: 20, fontWeight: "800" },

  frame: { borderRadius: 30, padding: 1.5, shadowColor: colors.glow, shadowOpacity: 0.45, shadowRadius: 22, elevation: 10 },
  composer: { borderRadius: 29, backgroundColor: "rgba(10,13,38,0.92)", padding: space.lg },
  composerHead: { flexDirection: "row-reverse", alignItems: "center", gap: 6, marginBottom: space.sm },
  composerLabel: { color: colors.softText, fontSize: 13, fontWeight: "700" },
  input: { color: colors.text, fontSize: 15, lineHeight: 24, minHeight: 74, maxHeight: 200, textAlignVertical: "top" },
  picsRow: { flexDirection: "row-reverse", gap: space.sm, paddingVertical: space.sm },
  picWrap: { width: 58, height: 58 },
  pic: { width: 58, height: 58, borderRadius: 14, backgroundColor: colors.glassStrong },
  picX: { position: "absolute", top: -6, left: -6, width: 22, height: 22, borderRadius: 11, backgroundColor: colors.base, borderWidth: 1, borderColor: colors.glassBorderStrong, alignItems: "center", justifyContent: "center" },
  composerFoot: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginTop: space.sm },
  tool: { flexDirection: "row-reverse", alignItems: "center", gap: 6, height: 38, paddingHorizontal: 13, borderRadius: 999, backgroundColor: colors.glassStrong, borderWidth: 1, borderColor: colors.glassBorder },
  toolText: { color: colors.softText, fontSize: 13, fontWeight: "600" },
  send: { width: 48, height: 48, borderRadius: 24, overflow: "hidden", alignItems: "center", justifyContent: "center", shadowColor: colors.glow, shadowOpacity: 0.7, shadowRadius: 12, elevation: 10 },

  grid: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.md, marginTop: space.xl },
  tile: { width: "47.8%", backgroundColor: colors.glass, borderRadius: 24, borderWidth: 1, borderColor: colors.glassBorder, padding: space.lg, gap: 4 },
  tileIcon: { width: 48, height: 48, borderRadius: 16, alignItems: "center", justifyContent: "center", marginBottom: space.sm, alignSelf: "flex-end" },
  tileTitle: { color: colors.text, fontSize: 15.5, fontWeight: "800", textAlign: "right" },
  tileText: { color: colors.textMuted, fontSize: 12.5, textAlign: "right" },

  stats: { flexDirection: "row-reverse", alignItems: "center", backgroundColor: colors.glass, borderRadius: 24, borderWidth: 1, borderColor: colors.glassBorder, paddingVertical: space.lg, marginTop: space.lg },
  stat: { flex: 1, alignItems: "center", gap: 2 },
  statNum: { color: colors.text, fontSize: 24, fontWeight: "800" },
  statLabel: { color: colors.textMuted, fontSize: 12 },
  statSep: { width: 1, height: 34, backgroundColor: colors.glassBorder },

  secHead: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginTop: space.xl, marginBottom: space.md },
  secTitle: { color: colors.text, fontSize: 17, fontWeight: "800" },
  secLink: { color: colors.accent, fontSize: 13, fontWeight: "700" },

  recent: { backgroundColor: colors.glass, borderRadius: 24, borderWidth: 1, borderColor: colors.glassBorder, overflow: "hidden" },
  recentRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.md, paddingVertical: 12, paddingHorizontal: space.lg },
  recentSep: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.glassBorder },
  recentName: { color: colors.text, fontSize: 15, fontWeight: "700", textAlign: "right" },
  recentLang: { fontSize: 12, fontWeight: "700", textAlign: "right", marginTop: 2 },

  tplRow: { flexDirection: "row-reverse", gap: space.md, paddingBottom: space.sm },
  tpl: { width: 128, backgroundColor: colors.glass, borderRadius: 22, borderWidth: 1, borderColor: colors.glassBorder, padding: space.md, gap: 6 },
  tplIcon: { width: 44, height: 44, borderRadius: 22, borderWidth: 1, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" },
  tplTitle: { color: colors.text, fontSize: 14, fontWeight: "700", textAlign: "right", marginTop: 4 },
  tplLang: { fontSize: 11.5, fontWeight: "700", textAlign: "right" },
});
