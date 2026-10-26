import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  ActivityIndicator,
  StyleSheet,
  StyleProp,
  ViewStyle,
} from "react-native";
import { colors, space, radius, type } from "../theme";

export function Card({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.card, style]}>{children}</View>;
}

type ButtonProps = {
  title: string;
  onPress: () => void;
  variant?: "primary" | "secondary";
  loading?: boolean;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
};

export function Button({
  title,
  onPress,
  variant = "primary",
  loading = false,
  disabled = false,
  style,
}: ButtonProps) {
  const isPrimary = variant === "primary";
  const inactive = disabled || loading;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: inactive, busy: loading }}
      onPress={onPress}
      disabled={inactive}
      style={({ pressed }) => [
        styles.button,
        isPrimary ? styles.buttonPrimary : styles.buttonSecondary,
        pressed && (isPrimary ? styles.buttonPrimaryPressed : styles.buttonSecondaryPressed),
        inactive && styles.buttonInactive,
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={isPrimary ? colors.primaryText : colors.primary} />
      ) : (
        <Text style={[styles.buttonText, { color: isPrimary ? colors.primaryText : colors.primary }]}>
          {title}
        </Text>
      )}
    </Pressable>
  );
}

type KeyInputProps = {
  label: string;
  value: string;
  onChangeText: (t: string) => void;
  placeholder?: string;
  secret?: boolean;
};

export function KeyInput({ label, value, onChangeText, placeholder, secret = false }: KeyInputProps) {
  const [revealed, setRevealed] = useState(false);
  return (
    <View style={{ marginBottom: space.lg }}>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.textMuted}
          secureTextEntry={secret && !revealed}
          autoCapitalize="none"
          autoCorrect={false}
          textAlign="left"
          writingDirection="ltr"
          accessibilityLabel={label}
        />
        {secret && (
          <Pressable
            onPress={() => setRevealed((r) => !r)}
            hitSlop={8}
            accessibilityRole="button"
            accessibilityLabel={revealed ? "إخفاء المفتاح" : "إظهار المفتاح"}
            style={styles.reveal}
          >
            <Text style={styles.revealText}>{revealed ? "إخفاء" : "إظهار"}</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

export type Status =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "ok"; message: string }
  | { kind: "error"; message: string };

export function StatusLine({ status }: { status: Status }) {
  if (status.kind === "idle") return null;

  if (status.kind === "loading") {
    return (
      <View style={[styles.status, { backgroundColor: colors.infoBg }]} accessibilityLiveRegion="polite">
        <ActivityIndicator size="small" color={colors.infoText} />
        <Text style={[styles.statusText, { color: colors.infoText }]}>جاري الاتصال…</Text>
      </View>
    );
  }

  const ok = status.kind === "ok";
  return (
    <View
      style={[styles.status, { backgroundColor: ok ? colors.okBg : colors.errorBg }]}
      accessibilityLiveRegion="polite"
    >
      <Text style={[styles.statusText, { color: ok ? colors.okText : colors.errorText }]}>
        {ok ? "✅ " : "❌ "}
        {status.message}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.border,
    padding: space.lg,
  },

  button: {
    minHeight: 48,
    borderRadius: radius.button,
    paddingHorizontal: space.lg,
    alignItems: "center",
    justifyContent: "center",
  },
  buttonPrimary: { backgroundColor: colors.primary },
  buttonPrimaryPressed: { backgroundColor: colors.primaryPressed },
  buttonSecondary: {
    backgroundColor: colors.surface,
    borderWidth: 1.5,
    borderColor: colors.primary,
  },
  buttonSecondaryPressed: { backgroundColor: colors.infoBg },
  buttonInactive: { opacity: 0.55 },
  buttonText: { fontSize: 16, fontWeight: "700" },

  label: { ...type.label, color: colors.text, marginBottom: space.sm },
  inputRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.field,
    paddingHorizontal: space.md,
  },
  input: {
    flex: 1,
    minHeight: 46,
    fontSize: 15,
    color: colors.text,
  },
  reveal: { paddingStart: space.md, paddingVertical: space.sm },
  revealText: { color: colors.primary, fontWeight: "600", fontSize: 14 },

  status: {
    flexDirection: "row",
    alignItems: "center",
    gap: space.sm,
    borderRadius: radius.field,
    padding: space.md,
    marginTop: space.md,
  },
  statusText: { ...type.body, flexShrink: 1 },
});
