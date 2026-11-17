import { refImages } from "../services/attachment";
import React, { useCallback, useEffect, useRef, useState } from "react";
import { View, Text, StyleSheet, ActivityIndicator } from "react-native";
import { WebView } from "react-native-webview";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { IconButton, Badge, EmptyState, Button } from "../components/ui";
import { LangBadge } from "../components/appVisuals";
import { TEMPLATES } from "../services/templates";
import { TEMPLATE_DEMOS } from "../services/templateDemos";
import { instantPreview } from "../services/instantPreview";
import { Lang } from "../services/langs";
import { colors, space, type } from "../theme";
import type { RootScreenProps } from "../navigation";

export default function InstantPreviewScreen({ navigation, route }: RootScreenProps<"InstantPreview">) {
  const insets = useSafeAreaInsets();
  const template = TEMPLATES.find((t) => t.id === route.params.templateId);
  const lang: Lang = route.params.lang ?? template?.lang ?? "html";
  const description = route.params.description ?? template?.description ?? "";
  const title = route.params.title ?? template?.title ?? "معاينة فورية";
  // Bundled demo: an HTML template whose description was not changed.
  const demo = template && lang === "html" && description === template.description ? TEMPLATE_DEMOS[template.id] : undefined;

  const [html, setHtml] = useState<string | null>(demo ?? null);
  const [live, setLive] = useState<string | null>(null); // the design as it's being written (streaming)
  const [status, setStatus] = useState("");
  const [error, setError] = useState<string | null>(null);
  const lastLive = useRef(0);

  const load = useCallback(
    async (fresh: boolean) => {
      setError(null);
      setHtml(null);
      setLive(null);
      lastLive.current = 0;
      // Show the design being written: update the live preview at most ~2×/second so the WebView doesn't thrash.
      const onPartial = (partial: string) => {
        const now = Date.now();
        if (partial.length > 300 && now - lastLive.current > 500) {
          lastLive.current = now;
          setLive(partial);
        }
      };
      try {
        const result = await instantPreview(lang, description, setStatus, fresh, refImages(), onPartial);
        setLive(null);
        setHtml(result);
      } catch (e: any) {
        setLive(null);
        setError(e.message);
      }
    },
    [lang, description]
  );

  useEffect(() => {
    if (!demo) load(false);
  }, [demo, load]);

  const hasFooter = !!(route.params.fromWizard || template);

  return (
    <View style={styles.root}>
      <View style={[styles.bar, { paddingTop: insets.top + space.sm }]}>
        <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        <View style={styles.titleWrap}>
          <Text style={styles.title} numberOfLines={1}>
            {title}
          </Text>
          <View style={styles.badges}>
            <LangBadge lang={lang} />
            {demo ? (
              <Badge label="معاينة فورية" color={colors.okText} icon="flash" />
            ) : (
              <Badge label="بالذكاء الاصطناعي" color={colors.accent} icon="sparkles" />
            )}
          </View>
        </View>
        {!demo && html ? <IconButton icon="refresh" label="معاينة جديدة" onPress={() => load(true)} /> : <View style={{ width: 42 }} />}
      </View>

      {!html && !live && !error ? (
        <View style={styles.wait}>
          <ActivityIndicator color={colors.accent} size="large" />
          <Text style={styles.waitTitle}>بنجهّز معاينة فورية…</Text>
          <Text style={styles.waitText}>{status || "ثواني ونكون جاهزين"}</Text>
          <Text style={styles.waitHint}>المعاينة بتتحفظ، والمرة الجاية بتفتح فوراً.</Text>
        </View>
      ) : null}
      {error ? (
        <EmptyState
          icon="cloud-offline-outline"
          title="ما قدرنا نجهّز المعاينة"
          text={error}
          action={<Button title="حاول تاني" icon="refresh" variant="secondary" onPress={() => load(true)} />}
        />
      ) : null}
      {/* While streaming: show the design being written live, with a small "drawing now" ribbon. */}
      {!html && live ? (
        <View style={styles.frame}>
          <WebView originWhitelist={["*"]} source={{ html: live }} style={{ flex: 1, backgroundColor: colors.base }} scrollEnabled={false} />
          <View style={styles.liveRibbon}>
            <ActivityIndicator color={colors.primaryText} size="small" />
            <Text style={styles.liveText}>يرسم التصميم مباشرة…</Text>
          </View>
        </View>
      ) : null}
      {html ? (
        <View style={styles.frame}>
          <WebView originWhitelist={["*"]} source={{ html }} style={{ flex: 1, backgroundColor: colors.base }} />
        </View>
      ) : null}

      <View style={[styles.footer, { paddingBottom: insets.bottom + space.md }, !hasFooter && { paddingTop: 0 }]}>
        {route.params.fromWizard ? (
          <Button title="رجوع للتعديل" icon="create-outline" variant="secondary" onPress={() => navigation.goBack()} style={{ flex: 1 }} />
        ) : template ? (
          <Button
            title="استخدم هذا القالب"
            icon="arrow-back"
            onPress={() => navigation.replace("Create", { templateId: template.id })}
            style={{ flex: 1 }}
          />
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  bar: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    paddingHorizontal: space.lg,
    paddingBottom: space.md,
    backgroundColor: colors.glassBar,
  },
  titleWrap: { flex: 1, alignItems: "center", gap: 4 },
  title: { fontSize: 17, fontWeight: "700", color: colors.text },
  badges: { flexDirection: "row", gap: 6, justifyContent: "center" },

  wait: { flex: 1, alignItems: "center", justifyContent: "center", padding: space.xl, gap: space.sm },
  waitTitle: { ...type.sectionTitle, color: colors.text, marginTop: space.md },
  waitText: { ...type.body, color: colors.textMuted, textAlign: "center" },
  waitHint: { ...type.hint, color: colors.faint, textAlign: "center", marginTop: space.md },

  frame: {
    flex: 1,
    marginHorizontal: space.md,
    borderRadius: 28,
    overflow: "hidden",
    backgroundColor: colors.glass,
  },
  footer: { flexDirection: "row-reverse", gap: space.md, paddingHorizontal: space.lg, paddingTop: space.md, backgroundColor: colors.glassBar },
  liveRibbon: {
    position: "absolute",
    top: space.md,
    alignSelf: "center",
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    backgroundColor: colors.primary,
    paddingHorizontal: space.md,
    paddingVertical: 7,
    borderRadius: 999,
  },
  liveText: { ...type.hint, color: colors.primaryText, fontWeight: "700" },
});
