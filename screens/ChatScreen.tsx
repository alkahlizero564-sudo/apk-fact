// "Build by chatting": the owner describes an app in a conversation; the AI asks a little, fills the rest, and
// when ready builds the real app (one app or a connected pair) — all without leaving the chat.
import React, { useEffect, useRef, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TextInput, Pressable, KeyboardAvoidingView, Platform, ActivityIndicator, Image, Alert } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "../components/icons";
import { colors, space, type } from "../theme";
import { Button, IconButton, RtlRow } from "../components/ui";
import { chatReply, extractSpec, stripSpec, ChatMsg, ChatSpec } from "../services/chat";
import { setRefPics, refImages, RefPic, pickRefPics, MAX_PICS } from "../services/attachment";
import { generateApp, Report } from "../services/appActions";
import { createPair } from "../services/pair";
import { LANGS } from "../services/langs";
import type { RootScreenProps } from "../navigation";

const GREETING =
  "أهلاً 👋 أنا هنا أبني لك تطبيقك بالدردشة. احكِ لي فكرتك: التطبيق يعمل شنو؟ وتريده تطبيقاً واحداً، أم تطبيقين متصلين (زبون + إدارة)؟";

const CARD = colors.glass;
const SOFT = colors.glassStrong;

type Bubble = ChatMsg & { kind?: "status" };

export default function ChatScreen({ navigation }: RootScreenProps<"Chat">) {
  const insets = useSafeAreaInsets();
  const [msgs, setMsgs] = useState<Bubble[]>([{ role: "model", text: GREETING }]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [spec, setSpec] = useState<ChatSpec | null>(null);
  const [building, setBuilding] = useState(false);
  const [status, setStatus] = useState("");
  const [pics, setPics] = useState<RefPic[]>([]);
  const scroll = useRef<ScrollView>(null);

  useEffect(() => {
    const t = setTimeout(() => scroll.current?.scrollToEnd({ animated: true }), 60);
    return () => clearTimeout(t);
  }, [msgs, status]);

  // Keep the shared holder in sync (the preview and the build read it), and clear it on leaving.
  useEffect(() => {
    setRefPics(pics);
    return () => setRefPics([]);
  }, [pics]);

  async function attachImage() {
    try {
      const added = await pickRefPics(MAX_PICS - pics.length, pics);
      if (!added.length) return;
      setPics((prev) => [...prev, ...added].slice(0, MAX_PICS));
    } catch (e: any) {
      Alert.alert("تعذّر إرفاق الصور", e?.message ?? "جرّب مرة أخرى");
    }
  }

  // History the AI sees: only the real conversation (user + model), not status lines.
  const history = (extra: Bubble[]): ChatMsg[] =>
    [...msgs, ...extra].filter((m) => !m.kind).map((m) => ({ role: m.role, text: m.text }));

  async function send() {
    const text = input.trim();
    if ((!text && !pics.length) || busy || building) return;
    const mine: Bubble = { role: "user", text: text || "خذ الصور المرفقة كمرجع لشكل التطبيق." };
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

  const canSend = !busy && !building && (!!input.trim() || pics.length > 0);

  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        <Text style={styles.title}>بناء بالدردشة</Text>
        <View style={{ width: 42 }} />
      </View>

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === "ios" ? "padding" : undefined}>
        <ScrollView ref={scroll} style={{ flex: 1 }} contentContainerStyle={styles.list} showsVerticalScrollIndicator={false}>
          {msgs.map((m, i) => (
            <View key={i} style={[styles.bubble, m.role === "user" ? styles.mine : styles.ai]}>
              <Text style={[styles.msg, m.role === "user" ? styles.mineText : styles.aiText]}>{m.text}</Text>
            </View>
          ))}
          {busy ? (
            <View style={[styles.bubble, styles.ai]}>
              <ActivityIndicator color={colors.accent} />
            </View>
          ) : null}
          {building ? (
            <View style={[styles.bubble, styles.ai, { flexDirection: "row-reverse", alignItems: "center", gap: space.sm }]}>
              <ActivityIndicator color={colors.accent} />
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

        {pics.length > 0 ? (
          <RtlRow contentContainerStyle={styles.picsRow}>
            {pics.map((p, i) => (
              <View key={p.uri + i} style={styles.picWrap}>
                <Image source={{ uri: p.uri }} style={styles.pic} />
                <Pressable
                  onPress={() => setPics((prev) => prev.filter((_, j) => j !== i))}
                  hitSlop={8}
                  style={styles.picX}
                  accessibilityLabel="حذف الصورة"
                >
                  <Ionicons name="close" size={12} color={colors.text} />
                </Pressable>
              </View>
            ))}
          </RtlRow>
        ) : null}

        <View style={[styles.inputBar, { paddingBottom: Math.max(insets.bottom, space.md) }]}>
          <View style={styles.pill}>
            <Pressable
              onPress={attachImage}
              disabled={building || pics.length >= MAX_PICS}
              hitSlop={8}
              style={[styles.attachBtn, (building || pics.length >= MAX_PICS) && { opacity: 0.4 }]}
              accessibilityLabel="إرفاق صور"
            >
              <Ionicons name="image-outline" size={20} color={colors.softText} />
            </Pressable>
            <TextInput
              style={styles.input}
              value={input}
              onChangeText={setInput}
              placeholder="اكتب رسالتك…"
              placeholderTextColor={colors.faint}
              multiline
              editable={!building}
              textAlign="right"
            />
            <Pressable
              onPress={send}
              disabled={!canSend}
              style={[styles.sendBtn, !canSend && { opacity: 0.35 }]}
              accessibilityLabel="إرسال"
            >
              <Ionicons name="arrow-up" size={20} color={colors.primaryText} />
            </Pressable>
          </View>
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
  title: { color: colors.text, fontSize: 17, fontWeight: "700" },
  list: { padding: space.lg, gap: space.sm, paddingBottom: space.xl },

  bubble: { maxWidth: "86%", borderRadius: 22, paddingHorizontal: space.lg, paddingVertical: 12 },
  mine: { alignSelf: "flex-start", backgroundColor: colors.primary, borderBottomRightRadius: 6 },
  ai: { alignSelf: "flex-end", backgroundColor: CARD, borderBottomLeftRadius: 6 },
  msg: { ...type.body },
  mineText: { color: colors.primaryText, textAlign: "right" },
  aiText: { color: colors.text, textAlign: "right" },

  specCard: { alignSelf: "stretch", backgroundColor: CARD, borderRadius: 24, padding: space.lg, gap: space.sm, marginTop: space.sm },
  specTitle: { ...type.body, color: colors.text, textAlign: "right", fontWeight: "700", marginBottom: 4 },

  picsRow: { flexDirection: "row-reverse", gap: space.sm, paddingHorizontal: space.lg, paddingVertical: space.sm },
  picWrap: { width: 54, height: 54 },
  pic: { width: 54, height: 54, borderRadius: 14, backgroundColor: CARD },
  picX: {
    position: "absolute",
    top: -5,
    left: -5,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: SOFT,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    alignItems: "center",
    justifyContent: "center",
  },

  inputBar: { paddingHorizontal: space.lg, paddingTop: space.sm, backgroundColor: colors.glassBar },
  pill: {
    flexDirection: "row-reverse",
    alignItems: "flex-end",
    gap: space.sm,
    backgroundColor: CARD,
    borderRadius: 28,
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  attachBtn: { width: 40, height: 40, borderRadius: 20, alignItems: "center", justifyContent: "center", backgroundColor: SOFT },
  input: { flex: 1, maxHeight: 120, color: colors.text, fontSize: 15, lineHeight: 22, paddingHorizontal: space.sm, paddingTop: 9, paddingBottom: 9 },
  sendBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
}); 
