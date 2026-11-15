import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, ActivityIndicator } from "react-native";
import { WebView } from "react-native-webview";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { IconButton, Badge, EmptyState, Button } from "../components/ui";
import { LangBadge } from "../components/appVisuals";
import { loadPreview } from "../services/appActions";
import { Lang } from "../services/langs";
import { colors, space } from "../theme";
import type { RootScreenProps } from "../navigation";

export default function PreviewScreen({ navigation, route }: RootScreenProps<"Preview">) {
  const { name } = route.params;
  const insets = useSafeAreaInsets();
  const [data, setData] = useState<{ html: string; lang: Lang; ai: boolean } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    setData(null);
    setError(null);
    loadPreview(name).then(setData).catch((e) => setError(e.message));
  }, [name, reload]);

  return (
    <View style={styles.root}>
      <View style={[styles.bar, { paddingTop: insets.top + space.sm }]}>
        <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        <View style={styles.titleWrap}>
          <Text style={styles.title} numberOfLines={1}>
            {name}
          </Text>
          <View style={styles.badges}>
            {data ? <LangBadge lang={data.lang} /> : null}
            {data?.ai ? <Badge label="معاينة بالذكاء الاصطناعي" color={colors.accent} icon="sparkles" /> : null}
          </View>
        </View>
        <IconButton icon="refresh" label="تحديث" onPress={() => setReload((r) => r + 1)} />
      </View>

      {!data && !error ? <ActivityIndicator color="#FFFFFF" style={{ marginTop: space.xxl }} /> : null}
      {error ? (
        <EmptyState
          icon="eye-off-outline"
          title="ما قدرنا نعرض المعاينة"
          text={error}
          action={<Button title="حاول تاني" icon="refresh" variant="secondary" onPress={() => setReload((r) => r + 1)} />}
        />
      ) : null}
      {data ? (
        <View style={[styles.frame, { marginBottom: Math.max(insets.bottom, space.md) }]}>
          <WebView originWhitelist={["*"]} source={{ html: data.html }} style={{ flex: 1, backgroundColor: colors.bg }} />
        </View>
      ) : null}
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
    backgroundColor: colors.bg,
  },
  titleWrap: { flex: 1, alignItems: "center", gap: 4 },
  title: { fontSize: 17, fontWeight: "700", color: colors.text },
  badges: { flexDirection: "row", gap: 6, justifyContent: "center" },
  frame: {
    flex: 1,
    marginHorizontal: space.md,
    borderRadius: 28,
    overflow: "hidden",
    backgroundColor: "#111114",
  },
});
