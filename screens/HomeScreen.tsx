import React, { useCallback, useState } from "react";
import { View, Text, TextInput, StyleSheet, Pressable, ScrollView, Image, Alert } from "react-native";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "../components/icons";
import { AppAvatar } from "../components/appVisuals";
import { listApps, AppInfo } from "../services/appActions";
import { TEMPLATES } from "../services/templates";
import { LANGS } from "../services/langs";
import { getRefPics, setRefPics, RefPic, pickRefPics, MAX_PICS } from "../services/attachment";
import { colors, space } from "../theme";
import type { RootStackParamList } from "../navigation";

type Nav = NativeStackNavigationProp<RootStackParamList>;

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

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ paddingTop: insets.top + space.lg, paddingHorizontal: space.lg, paddingBottom: 120 }}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.brand}>ماهر</Text>
      <Text style={styles.hello}>شنو نبني{"\n"}اليوم؟</Text>

      <View style={styles.box}>
        <TextInput
          value={text}
          onChangeText={setText}
          placeholder="صف فكرة تطبيقك هنا..."
          placeholderTextColor={colors.faint}
          multiline
          maxLength={2000}
          style={styles.input}
          textAlign="right"
        />

        {pics.length > 0 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.picsRow}>
            {pics.map((p, i) => (
              <View key={p.uri + i} style={styles.picWrap}>
                <Image source={{ uri: p.uri }} style={styles.pic} />
                <Pressable
                  onPress={() => updatePics(pics.filter((_, j) => j !== i))}
                  hitSlop={8}
                  style={styles.picX}
                  accessibilityLabel="حذف الصورة"
                >
                  <Ionicons name="close" size={14} color={colors.text} />
                </Pressable>
              </View>
            ))}
          </ScrollView>
        ) : null}

        <View style={styles.boxFoot}>
          <Pressable
            onPress={pickImages}
            disabled={pics.length >= MAX_PICS}
            style={({ pressed }) => [styles.imgBtn, pressed && { opacity: 0.7 }, pics.length >= MAX_PICS && { opacity: 0.4 }]}
            accessibilityRole="button"
            accessibilityLabel="إرفاق صور"
          >
            <Ionicons name="image-outline" size={18} color={colors.softText} />
            <Text style={styles.imgBtnText}>{pics.length > 0 ? `${pics.length} من ${MAX_PICS}` : "صور"}</Text>
          </Pressable>

          <Pressable
            onPress={send}
            style={({ pressed }) => [styles.sendBtn, !canSend && { opacity: 0.35 }, pressed && { transform: [{ scale: 0.95 }] }]}
            accessibilityRole="button"
            accessibilityLabel="ابدأ"
          >
            <Ionicons name="arrow-up" size={22} color={colors.primaryText} />
          </Pressable>
        </View>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipsRow}>
        {TEMPLATES.slice(0, 8).map((t) => (
          <Pressable
            key={t.id}
            onPress={() => nav.navigate("Create", { templateId: t.id })}
            style={({ pressed }) => [styles.chip, pressed && { opacity: 0.7 }]}
          >
            <Text style={styles.chipText}>{t.title}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <View style={styles.quickRow}>
        <Pressable onPress={() => nav.navigate("Pair")} style={styles.quick}>
          <Ionicons name="git-merge-outline" size={18} color={colors.softText} />
          <Text style={styles.quickText}>تطبيقين متصلين</Text>
        </Pressable>
        <Pressable onPress={() => nav.navigate("Gallery")} style={styles.quick}>
          <Ionicons name="color-palette-outline" size={18} color={colors.softText} />
          <Text style={styles.quickText}>معرض التصاميم</Text>
        </Pressable>
      </View>

      {apps && apps.length > 0 ? (
        <>
          <View style={styles.secHead}>
            <Text style={styles.secTitle}>تطبيقاتك</Text>
            <Pressable onPress={() => nav.navigate("Tabs", { screen: "Apps" } as never)} hitSlop={8}>
              <Text style={styles.secLink}>عرض الكل</Text>
            </Pressable>
          </View>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.appsRow}>
            {apps.slice(-6).reverse().map((a) => (
              <Pressable
                key={a.name}
                onPress={() => nav.navigate("AppDetail", { name: a.name, lang: a.lang })}
                style={({ pressed }) => [styles.appCard, pressed && { transform: [{ scale: 0.97 }] }]}
              >
                <AppAvatar name={a.name} lang={a.lang} size={44} />
                <Text style={styles.appName} numberOfLines={1}>
                  {a.name}
                </Text>
                <Text style={styles.appLang}>{LANGS[a.lang].label}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  brand: { color: colors.textMuted, fontSize: 14, textAlign: "center", marginBottom: space.xl },
  hello: { color: colors.text, fontSize: 30, fontWeight: "700", lineHeight: 42, textAlign: "right" },

  box: { backgroundColor: colors.glass, borderRadius: 28, padding: space.lg, marginTop: space.xl },
  input: { color: colors.text, fontSize: 15, lineHeight: 24, minHeight: 80, maxHeight: 200, textAlignVertical: "top" },
  picsRow: { flexDirection: "row-reverse", gap: space.sm, paddingVertical: space.md },
  picWrap: { width: 64, height: 64 },
  pic: { width: 64, height: 64, borderRadius: 14, backgroundColor: colors.glassStrong },
  picX: {
    position: "absolute",
    top: -6,
    left: -6,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.glassStrong,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    alignItems: "center",
    justifyContent: "center",
  },
  boxFoot: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginTop: space.sm },
  imgBtn: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: 6,
    height: 38,
    paddingHorizontal: 14,
    borderRadius: 999,
    backgroundColor: colors.glassStrong,
  },
  imgBtnText: { color: colors.softText, fontSize: 13 },
  sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },

  chipsRow: { flexDirection: "row-reverse", gap: space.sm, marginTop: space.lg },
  chip: { backgroundColor: colors.glass, borderRadius: 999, paddingVertical: 9, paddingHorizontal: 16 },
  chipText: { color: colors.softText, fontSize: 13 },

  quickRow: { flexDirection: "row-reverse", gap: space.sm, marginTop: space.lg },
  quick: {
    flex: 1,
    flexDirection: "row-reverse",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderRadius: 18,
    backgroundColor: colors.glass,
  },
  quickText: { color: colors.softText, fontSize: 13 },

  secHead: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginTop: space.xl, marginBottom: space.md },
  secTitle: { color: colors.text, fontSize: 16, fontWeight: "700" },
  secLink: { color: colors.textMuted, fontSize: 13 },
  appsRow: { flexDirection: "row-reverse", gap: space.md },
  appCard: { width: 130, backgroundColor: colors.glass, borderRadius: 22, padding: space.md, gap: 6 },
  appName: { color: colors.text, fontSize: 14, fontWeight: "600", textAlign: "right", marginTop: 6 },
  appLang: { color: colors.faint, fontSize: 12, textAlign: "right" },
}); 
