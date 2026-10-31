import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "@expo/vector-icons";
import { Lang, LANGS } from "../services/langs";
import { colors, langColors } from "../theme";
import { Badge, IconName } from "./ui";

export const LANG_ICONS: Record<Lang, IconName> = {
  html: "logo-html5",
  flutter: "layers-outline",
  python: "logo-python",
  kotlin: "logo-android",
};

export function LangBadge({ lang }: { lang: Lang }) {
  return <Badge label={LANGS[lang].label} color={langColors[lang]} icon={LANG_ICONS[lang]} />;
}

/** Rounded app tile: the language color as a soft gradient with the app's first letter. */
export function AppAvatar({ name, lang, size = 52 }: { name: string; lang: Lang; size?: number }) {
  const tint = langColors[lang];
  return (
    <LinearGradient
      colors={[tint + "55", tint + "14"]}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={[styles.avatar, { width: size, height: size, borderRadius: size * 0.3, borderColor: tint + "66" }]}
    >
      <Text style={[styles.letter, { fontSize: size * 0.42 }]}>{name.slice(0, 1).toUpperCase()}</Text>
      <View style={[styles.corner, { backgroundColor: colors.surface }]}>
        <Ionicons name={LANG_ICONS[lang]} size={size * 0.24} color={tint} />
      </View>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  avatar: { alignItems: "center", justifyContent: "center", borderWidth: 1 },
  letter: { color: colors.text, fontWeight: "900" },
  corner: {
    position: "absolute",
    bottom: -4,
    left: -4,
    borderRadius: 999,
    padding: 3,
    borderWidth: 1,
    borderColor: colors.border,
  },
});
