import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { Lang, LANGS } from "../services/langs";
import { colors, langColors } from "../theme";
import { Badge, IconName } from "./ui";

export const LANG_ICONS: Record<Lang, IconName> = {
  html: "logo-html5",
  react: "logo-react",
  flutter: "layers-outline",
  python: "logo-python",
  kotlin: "logo-android",
};

export function LangBadge({ lang }: { lang: Lang }) {
  return <Badge label={LANGS[lang].label} color={langColors[lang]} icon={LANG_ICONS[lang]} />;
}

/** Flat rounded app tile: a solid dark square with the app's first letter and a small language mark. */
export function AppAvatar({ name, lang, size = 52 }: { name: string; lang: Lang; size?: number }) {
  const tint = langColors[lang];
  return (
    <View style={[styles.avatar, { width: size, height: size, borderRadius: size * 0.34, backgroundColor: tint + "26" }]}>
      <Text style={[styles.letter, { fontSize: size * 0.42, color: tint }]}>{name.slice(0, 1).toUpperCase()}</Text>
      <View style={styles.corner}>
        <Ionicons name={LANG_ICONS[lang]} size={size * 0.22} color={tint} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { alignItems: "center", justifyContent: "center" },
  letter: { fontWeight: "800" },
  corner: {
    position: "absolute",
    bottom: -4,
    left: -4,
    borderRadius: 999,
    padding: 3,
    backgroundColor: colors.bg,
  },
});
