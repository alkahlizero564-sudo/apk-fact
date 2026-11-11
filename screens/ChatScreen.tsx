// "Build by chatting": the owner describes an app in a conversation; the AI asks a little, fills the rest, and
// when ready builds the real app (one app or a connected pair) — all without leaving the chat.
import React, { useEffect, useRef, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TextInput, Pressable, KeyboardAvoidingView, Platform, ActivityIndicator, Image, Alert } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import { colors, space, radius, type } from "../theme";
import { Button } from "../components/ui";
import { chatReply, extractSpec, stripSpec, ChatMsg, ChatSpec } from "../services/chat";
import { setRefImage, refImages } from "../services/attachment";
import { AiImage } from "../services/instantPreview";
import { generateApp, Report } from "../services/appActions";
import { createPair } from "../services/pair";
import { LANGS } from "../services/langs";
import type { RootScreenProps } from "../navigation";

const GREETING =
  "أهلاً 👋 أنا هنا أبني لك تطبيقك بالدردشة. احكِ لي فكرتك: التطبيق يعمل شنو؟ وتريده تطبيقاً واحداً، أم تطبيقين متصلين (زبون + إدارة)؟";

type Bubble = ChatMsg & { kind?: "status" };

export default function ChatScreen({ navigation }: RootScreenProps<"Chat">) {
  const insets = useSafeAreaInsets();
  const [msgs, setMsgs] = useState<Bubble[]>([{ role: "model", text: GREETING }]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [spec, setSpec] = useState<ChatSpec | null>(null);
  const [building, setBuilding] = useState(false);
  const [status, setStatus] = useState("");
  const [refPic, setRefPic] = useState<{ uri: string; image: AiImage } | null>(null);
  const scroll = useRef<ScrollView>(null);

  useEffect(() => {
    const t = setTimeout(() => scroll.current?.scrollToEnd({ animated: true }), 60);
    return () => clearTimeout(t);
  }, [msgs, status]);

  // Keep the shared holder in sync (the preview and the build read it), and clear it on leaving.
  useEffect(() => {
    setRefImage(refPic?.image ?? null);
    return () => setRefImage(null);
  }, [refPic]);

  async function attachImage() {
    try {
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        Alert.alert("إذن الصور", "نحتاج إذن الوصول للصور لإرفاق صورة.");
        return;
      }
      const res = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.5, base64: true });
      const a = res.canceled ? null : res.assets?.[0];
      if (a?.base64) setRefPic({ uri: a.uri, image: { data: a.base64, mime: a.mimeType || "image/jpeg" } });
    } catch (e: any) {
      Alert.alert("تعذّر إرفاق الصورة", e?.message ?? "جرّب مرة أخرى");
    }
  }

  // History the AI sees: only the real conversation (user + model), not status lines.
  const history = (extra: Bubble[]): ChatMsg[] =>
    [...msgs, ...extra].filter((m) => !m.kind).map((m) => ({ role: m.role, text: m.text }));

  async function send() {
    const text = input.trim();
    if ((!text && !refPic) || busy || building) return;
    const mine: Bubble = { role: "user", text: text || "خذ الصورة المرفقة كمرجع لشكل التطبيق." };
    setMsgs((m) => [...m, mine]);
    setInput("");
    setBusy(true);
    try {
      const reply = await chatReply(history([mine]), refImages());
      const found = extractSpec(reply);
      const shown = stripSpec(reply) || (found ? "جاهز أبني التطبيق ✅" : reply);
      setMsgs((m) => [...m, { role: "model", text: shown }]);
      if (found) setSpec(found);
    } catch (e: any) {
      setMsgs((m) => [...m, { role: "model", text: `تعذّر الرد: ${e?.message ?? "جرّب مرة أخرى"}` }]);
    } finally {
      setBusy(false);
    }
  }

  async function build() {
    if (!spec || building) return;
    setBuilding(true);
    setStatus("يبدأ…");
    setMsgs((m) => [...m, { role: "model", text: spec.pair ? "تمام، ببني تطبيقين متصلين الآن ⏳" : "تمام، ببني التطبيق الآن ⏳" }]);
    const report: Report = (step, st, detail) => setStatus(`${stepLabel(step)} ${st === "done" ? "✓" : st === "error" ? "✗" : "…"}${detail ? ` — ${detail}` : ""}`);
    try {
      if (spec.pair) {
        await createPair({ base: spec.name, lang: spec.lang, admins: spec.admins || "", push: false, description: spec.description }, report);
        setMsgs((m) => [...m, { role: "model", text: `تمّ إنشاء «${spec.title}» (زبون + إدارة) ✅` }]);
        navigation.replace("AppDetail", { name: `${spec.name}-customer`, lang: spec.lang });
      } else {
        await generateApp({ name: spec.name, lang: spec.lang, text: spec.description, kind: "create" }, report);
        setMsgs((m) => [...m, { role: "model", text: `تمّ إنشاء «${spec.title}» ✅` }]);
        navigation.replace("AppDetail", { name: spec.name, lang: spec.lang });
      }
    } catch (e: any) {
      setMsgs((m) => [...m, { role: "model", text: `تعذّر الإنشاء: ${e?.message ?? "جرّب مرة أخرى"}` }]);
      setSpec(null);
    } finally {
      setBuilding(false);
      setStatus("");
    }
  }

  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={() => navigation.goBack()} hitSlop={10} style={styles.back}>
          <Ionicons name="close" size={22} color={colors.text} />
        </Pressable>
        <Text style={styles.title}>بناء بالدردشة</Text>
        <View style={{ width: 30 }} />
      </View>

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === "ios" ? "padding" : undefined}>
        <ScrollView ref={scroll} style={{ flex: 1 }} contentContainerStyle={styles.list}>
          {msgs.map((m, i) => (
            <View key={i} style={[styles.bubble, m.role === "user" ? styles.mine : styles.ai]}>
              <Text style={[styles.msg, m.role === "user" ? styles.mineText : styles.aiText]}>{m.text}</Text>
            </View>
          ))}
          {busy ? (
            <View style={[styles.bubble, styles.ai]}>
              <ActivityIndicator color={colors.primary} />
            </View>
          ) : null}
          {building ? (
            <View style={[styles.bubble, styles.ai, { flexDirection: "row-reverse", alignItems: "center", gap: space.sm }]}>
              <ActivityIndicator color={colors.primary} />
              <Text style={styles.aiText}>{status || "يبني…"}</Text>
            </View>
          ) : null}
          {spec && !building ? (
            <View style={styles.specCard}>
              <Text style={styles.specTitle}>
                جاهز: «{spec.title}» · {LANGS[spec.lang].label}
                {spec.pair ? " · تطبيقان متصلان" : ""}
              </Text>
              <Button
                title="شاهد المعاينة أولاً"
                icon="eye-outline"
                variant="secondary"
                onPress={() =>
                  navigation.navigate("InstantPreview", { lang: spec.lang, description: spec.description, title: spec.title })
                }
              />
              <Button title="أنشئ التطبيق الآن" icon="rocket-outline" onPress={build} />
            </View>
          ) : null}
        </ScrollView>

        {refPic ? (
          <View style={styles.attachRow}>
            <Image source={{ uri: refPic.uri }} style={styles.attachThumb} />
            <Text style={styles.attachText}>صورة مرفقة — الذكاء بيشوفها</Text>
            <Pressable onPress={() => setRefPic(null)} hitSlop={10} style={{ padding: space.xs }}>
              <Ionicons name="close" size={18} color={colors.text} />
            </Pressable>
          </View>
        ) : null}
        <View style={[styles.inputBar, { paddingBottom: Math.max(insets.bottom, space.sm) }]}>
          <Pressable onPress={attachImage} disabled={building} hitSlop={8} style={styles.attachBtn}>
            <Ionicons name="image-outline" size={22} color={colors.textMuted} />
          </Pressable>
          <TextInput
            style={styles.input}
            value={input}
            onChangeText={setInput}
            placeholder="اكتب رسالتك…"
            placeholderTextColor={colors.textMuted}
            multiline
            editable={!building}
            textAlign="right"
          />
          <Pressable
            onPress={send}
            disabled={busy || building || (!input.trim() && !refPic)}
            style={[styles.sendBtn, (busy || building || (!input.trim() && !refPic)) && { opacity: 0.4 }]}
          >
            <Ionicons name="arrow-up" size={22} color={colors.primaryText} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

function stepLabel(step: string): string {
  const map: Record<string, string> = {
    send: "يجهّز الطلب",
    ai: "الذكاء يبني الكود",
    save: "يحفظ",
    backend: "قاعدة البيانات",
    auth: "تسجيل الدخول",
    firebase: "الإشعارات",
    design: "التصميم",
    customer: "تطبيق الزبون",
    admin: "تطبيق الإدارة",
  };
  return map[step] || step;
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  header: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", paddingHorizontal: space.lg, paddingVertical: space.md },
  back: { padding: space.xs },
  title: { ...type.screenTitle, color: colors.text },
  list: { padding: space.lg, gap: space.sm, paddingBottom: space.xl },
  bubble: { maxWidth: "88%", borderRadius: radius.card, paddingHorizontal: space.md, paddingVertical: space.sm },
  mine: { alignSelf: "flex-start", backgroundColor: colors.primary },
  ai: { alignSelf: "flex-end", backgroundColor: colors.surface },
  msg: { ...type.body },
  mineText: { color: colors.primaryText, textAlign: "right" },
  aiText: { color: colors.text, textAlign: "right" },
  specCard: { alignSelf: "stretch", backgroundColor: colors.surface, borderRadius: radius.card, padding: space.md, gap: space.sm, marginTop: space.sm },
  specTitle: { ...type.body, color: colors.text, textAlign: "right", fontWeight: "600" },
  attachRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm, paddingHorizontal: space.md, paddingVertical: space.xs },
  attachThumb: { width: 36, height: 36, borderRadius: radius.field, backgroundColor: colors.surface },
  attachText: { flex: 1, ...type.hint, color: colors.textMuted, textAlign: "right" },
  attachBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  inputBar: { flexDirection: "row-reverse", alignItems: "flex-end", gap: space.sm, paddingHorizontal: space.md, paddingTop: space.sm, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border, backgroundColor: colors.bg },
  input: { flex: 1, maxHeight: 120, color: colors.text, backgroundColor: colors.surface, borderRadius: radius.card, paddingHorizontal: space.md, paddingVertical: space.sm, ...type.body },
  sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
});
