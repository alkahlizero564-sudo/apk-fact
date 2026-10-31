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

      {!data && !error ? <ActivityIndicator color={colors.accent} style={{ marginTop: space.xxl }} /> : null}
      {error ? (
        <EmptyState
          icon="eye-off-outline"
          title="ما قدرنا نعرض المعاينة"
          text={error}
          action={<Button title="حاول تاني" icon="refresh" variant="secondary" onPress={() => setReload((r) => r + 1)} />}
        />
      ) : null}
      {data ? (
        <View style={styles.frame}>
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
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: colors.surface,
  },
  titleWrap: { flex: 1, alignItems: "flex-end", gap: 4 },
  title: { fontSize: 18, fontWeight: "900", color: colors.text },
  badges: { flexDirection: "row-reverse", gap: 6 },
  frame: { flex: 1 },
});
