// APK Fact UI kit. Arabic-first: rows run right-to-left (icon on the right, chevron on the left).
import React, { useEffect, useRef, useState } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  ActivityIndicator,
  StyleSheet,
  StyleProp,
  ViewStyle,
  Modal,
  ScrollView,
  TextInputProps,
  Animated,
  Easing,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "./icons";
import { colors, gradient, space, radius, type } from "../theme";

export type IconName = React.ComponentProps<typeof Ionicons>["name"];

// Glass Gradient look: frosted translucent cards with a thin light edge, glowing gradient primary actions.
const CARD = colors.glass;
const SOFT = colors.glassStrong;
const HAIR = colors.glassBorder;
const SOFT_TEXT = colors.softText;

/* ---------- Layout ---------- */

export function Screen({
  title,
  subtitle,
  right,
  children,
  scroll = true,
  onBack,
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
  children: React.ReactNode;
  scroll?: boolean;
  onBack?: () => void;
}) {
  const insets = useSafeAreaInsets();
  const header = (
    <View style={[styles.header, { paddingTop: insets.top + space.lg }]}>
      <View style={styles.headerRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.headerTitle}>{title}</Text>
          {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
        </View>
        {onBack ? <IconButton icon="arrow-forward" label="رجوع" onPress={onBack} /> : null}
        {right}
      </View>
    </View>
  );
  if (!scroll) {
    return (
      <View style={styles.screen}>
        {header}
        <View style={{ flex: 1 }}>{children}</View>
      </View>
    );
  }
  return (
    <View style={styles.screen}>
      <ScrollView
        contentContainerStyle={styles.screenContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {header}
        {children}
      </ScrollView>
    </View>
  );
}

export function Card({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function Section({
  title,
  action,
  children,
  style,
}: {
  title?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <View style={[{ marginBottom: space.xl }, style]}>
      {title ? (
        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>{title}</Text>
          {action}
        </View>
      ) : null}
      {children}
    </View>
  );
}

/* ---------- Buttons ---------- */

type ButtonProps = {
  title: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "ghost" | "danger";
  icon?: IconName;
  loading?: boolean;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
};

export function Button({ title, onPress, variant = "primary", icon, loading, disabled, style }: ButtonProps) {
  const inactive = !!(disabled || loading);
  const fg = variant === "primary" ? colors.primaryText : variant === "danger" ? colors.errorText : colors.text;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: inactive, busy: !!loading }}
      onPress={onPress}
      disabled={inactive}
      style={({ pressed }) => [
        styles.button,
        variant === "primary" && styles.buttonPrimary,
        variant === "secondary" && styles.buttonSecondary,
        variant === "ghost" && styles.buttonGhost,
        variant === "danger" && styles.buttonDanger,
        pressed && { transform: [{ scale: 0.98 }], opacity: 0.9 },
        inactive && { opacity: 0.45 },
        style,
      ]}
    >
      {variant === "primary" ? (
        <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
      ) : null}
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <View style={styles.buttonInner}>
          <Text style={[styles.buttonText, { color: fg }]}>{title}</Text>
          {icon ? <Ionicons name={icon} size={18} color={fg} /> : null}
        </View>
      )}
    </Pressable>
  );
}

export function IconButton({
  icon,
  label,
  onPress,
  tint = colors.text,
  style,
}: {
  icon: IconName;
  label: string;
  onPress: () => void;
  tint?: string;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <Pressable
      onPress={onPress}
      hitSlop={8}
      accessibilityRole="button"
      accessibilityLabel={label}
      style={({ pressed }) => [styles.iconButton, pressed && { opacity: 0.7 }, style]}
    >
      <Ionicons name={icon} size={20} color={tint} />
    </Pressable>
  );
}

/* ---------- Forms ---------- */

type FieldProps = TextInputProps & {
  label: string;
  icon?: IconName;
  helper?: string;
  error?: string | null;
  ltr?: boolean;
  secret?: boolean;
  counter?: boolean;
  right?: React.ReactNode;
};

export function Field({ label, icon, helper, error, ltr, secret, counter, right, multiline, style, ...input }: FieldProps) {
  const [focused, setFocused] = useState(false);
  const [revealed, setRevealed] = useState(false);
  const value = String(input.value ?? "");
  return (
    <View style={{ marginBottom: space.lg }}>
      <View style={styles.fieldLabelRow}>
        <Text style={styles.fieldLabel}>{label}</Text>
        {counter && input.maxLength ? (
          <Text style={styles.fieldCounter}>
            {value.length}/{input.maxLength}
          </Text>
        ) : null}
      </View>
      <View
        style={[
          styles.fieldBox,
          multiline && styles.fieldBoxMulti,
          focused && styles.fieldFocused,
          !!error && styles.fieldError,
        ]}
      >
        {icon ? (
          <Ionicons
            name={icon}
            size={18}
            color={focused ? colors.text : colors.textMuted}
            style={multiline ? { marginTop: 2 } : undefined}
          />
        ) : null}
        <TextInput
          {...input}
          multiline={multiline}
          secureTextEntry={secret && !revealed}
          placeholderTextColor={colors.faint}
          onFocus={(e) => {
            setFocused(true);
            input.onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            input.onBlur?.(e);
          }}
          accessibilityLabel={label}
          style={[
            styles.fieldInput,
            multiline && styles.fieldInputMulti,
            { textAlign: ltr ? "left" : "right", writingDirection: ltr ? "ltr" : "rtl" },
            style,
          ]}
        />
        {secret ? (
          <Pressable
            onPress={() => setRevealed((r) => !r)}
            hitSlop={8}
            accessibilityRole="button"
            accessibilityLabel={revealed ? "إخفاء" : "إظهار"}
          >
            <Ionicons name={revealed ? "eye-off-outline" : "eye-outline"} size={18} color={colors.textMuted} />
          </Pressable>
        ) : null}
        {right}
      </View>
      {error ? (
        <View style={styles.fieldMsgRow}>
          <Ionicons name="alert-circle" size={14} color={colors.errorText} />
          <Text style={[styles.fieldMsg, { color: colors.errorText }]}>{error}</Text>
        </View>
      ) : helper ? (
        <Text style={styles.fieldMsg}>{helper}</Text>
      ) : null}
    </View>
  );
}

export function Chip({
  label,
  icon,
  selected,
  onPress,
  tint = colors.primary,
}: {
  label: string;
  icon?: IconName;
  selected?: boolean;
  onPress: () => void;
  tint?: string;
}) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      style={({ pressed }) => [
        styles.chip,
        selected && { backgroundColor: tint + "33", borderColor: tint },
        pressed && { opacity: 0.8 },
      ]}
    >
      <Text style={[styles.chipText, selected && { color: colors.text }]}>{label}</Text>
      {icon ? <Ionicons name={icon} size={14} color={selected ? tint : colors.textMuted} /> : null}
    </Pressable>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <View style={styles.segmented} accessibilityRole="tablist">
      {options.map((o) => {
        const active = o.value === value;
        return (
          <Pressable
            key={o.value}
            onPress={() => onChange(o.value)}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            style={[styles.segment, active && styles.segmentActive]}
          >
            <Text style={[styles.segmentText, active && { color: colors.primaryText }]}>{o.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/* ---------- Lists ---------- */

export function ListRow({
  icon,
  leading,
  tint = SOFT_TEXT,
  title,
  subtitle,
  value,
  onPress,
  chevron = true,
  danger,
  right,
  last,
}: {
  icon?: IconName;
  leading?: React.ReactNode;
  tint?: string;
  title: string;
  subtitle?: string;
  value?: string;
  onPress?: () => void;
  chevron?: boolean;
  danger?: boolean;
  right?: React.ReactNode;
  last?: boolean;
}) {
  const color = danger ? colors.errorText : tint;
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      accessibilityRole={onPress ? "button" : undefined}
      style={({ pressed }) => [styles.row, !last && styles.rowDivider, pressed && { backgroundColor: SOFT }]}
    >
      {leading ??
        (icon ? (
          <View style={[styles.rowIcon, { backgroundColor: color + "26", borderColor: color + "55" }]}>
            <Ionicons name={icon} size={18} color={color} />
          </View>
        ) : null)}
      <View style={{ flex: 1 }}>
        <Text style={[styles.rowTitle, danger && { color: colors.errorText }]} numberOfLines={1}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={styles.rowSubtitle} numberOfLines={2}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {value ? <Text style={styles.rowValue}>{value}</Text> : null}
      {right}
      {onPress && chevron ? <Ionicons name="chevron-back" size={18} color={colors.faint} /> : null}
    </Pressable>
  );
}

export function Badge({ label, color = SOFT_TEXT, icon }: { label: string; color?: string; icon?: IconName }) {
  return (
    <View style={[styles.badge, { backgroundColor: color + "1F" }]}>
      <Text style={[styles.badgeText, { color }]}>{label}</Text>
      {icon ? <Ionicons name={icon} size={11} color={color} /> : null}
    </View>
  );
}

export function EmptyState({
  icon,
  title,
  text,
  action,
}: {
  icon: IconName;
  title: string;
  text?: string;
  action?: React.ReactNode;
}) {
  return (
    <View style={styles.empty}>
      <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={styles.emptyIcon}>
        <Ionicons name={icon} size={30} color={colors.primaryText} />
      </LinearGradient>
      <Text style={styles.emptyTitle}>{title}</Text>
      {text ? <Text style={styles.emptyText}>{text}</Text> : null}
      {action}
    </View>
  );
}

/* ---------- Feedback ---------- */

export function Banner({ kind, text }: { kind: "info" | "ok" | "error"; text: string }) {
  const map = {
    info: { bg: colors.infoBg, fg: colors.infoText, icon: "information-circle" as IconName },
    ok: { bg: colors.okBg, fg: colors.okText, icon: "checkmark-circle" as IconName },
    error: { bg: colors.errorBg, fg: colors.errorText, icon: "alert-circle" as IconName },
  }[kind];
  return (
    <View style={[styles.banner, { backgroundColor: map.bg }]} accessibilityLiveRegion="polite">
      <Text style={[styles.bannerText, { color: map.fg }]}>{text}</Text>
      <Ionicons name={map.icon} size={18} color={map.fg} />
    </View>
  );
}

export type StepState = "pending" | "active" | "done" | "error";
export type TimelineStep = { key: string; title: string; state: StepState; detail?: string };

function Elapsed() {
  const [s, setS] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setS((x) => x + 1), 1000);
    return () => clearInterval(t);
  }, []);
  return <Text style={styles.stepDetail}>{`${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`}</Text>;
}

export function Timeline({ steps }: { steps: TimelineStep[] }) {
  return (
    <View>
      {steps.map((st, i) => {
        const last = i === steps.length - 1;
        const color =
          st.state === "done"
            ? colors.okText
            : st.state === "error"
            ? colors.errorText
            : st.state === "active"
            ? colors.accent
            : colors.faint;
        return (
          <View key={st.key} style={styles.step}>
            <View style={{ flex: 1, paddingBottom: last ? 0 : space.lg }}>
              <Text style={[styles.stepTitle, st.state === "pending" && { color: colors.textMuted }]}>{st.title}</Text>
              {st.detail ? <Text style={styles.stepDetail}>{st.detail}</Text> : null}
              {st.state === "active" ? <Elapsed /> : null}
            </View>
            <View style={styles.stepRail}>
              <View style={[styles.stepDot, { borderColor: color, backgroundColor: st.state === "done" ? color : "transparent" }]}>
                {st.state === "active" ? (
                  <ActivityIndicator size="small" color={color} />
                ) : st.state === "done" ? (
                  <Ionicons name="checkmark" size={14} color={colors.base} />
                ) : st.state === "error" ? (
                  <Ionicons name="close" size={14} color={color} />
                ) : null}
              </View>
              {!last ? <View style={[styles.stepLine, st.state === "done" && { backgroundColor: colors.okText }]} /> : null}
            </View>
          </View>
        );
      })}
    </View>
  );
}

/** Steps state helper: useSteps([["send","إرسال"],...]) -> [steps, report, reset] */
export function useSteps(defs: [string, string][]) {
  const initial = () => defs.map(([key, title]) => ({ key, title, state: "pending" as StepState }));
  const [steps, setSteps] = useState<TimelineStep[]>(initial);
  const report = (key: string, state: StepState, detail?: string) =>
    setSteps((prev) => prev.map((s) => (s.key === key ? { ...s, state, detail: detail ?? s.detail } : s)));
  return [steps, report, () => setSteps(initial())] as const;
}

export function Stepper({ steps, current }: { steps: string[]; current: number }) {
  return (
    <View style={styles.stepper}>
      {steps.map((label, i) => {
        const done = i < current;
        const active = i === current;
        return (
          <View key={label} style={styles.stepperItem}>
            <View
              style={[
                styles.stepperBar,
                (done || active) && { backgroundColor: active ? colors.accent : colors.okText },
              ]}
            />
            <Text style={[styles.stepperLabel, (done || active) && { color: colors.text }]} numberOfLines={1}>
              {label}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

/* ---------- Sheet ---------- */

export function Sheet({
  visible,
  title,
  onClose,
  children,
}: {
  visible: boolean;
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  const insets = useSafeAreaInsets();
  const slide = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (visible) {
      slide.setValue(0);
      Animated.timing(slide, { toValue: 1, duration: 220, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    }
  }, [visible, slide]);
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} accessibilityLabel="إغلاق" />
      <Animated.View
        style={[
          styles.sheet,
          { paddingBottom: insets.bottom + space.lg },
          { transform: [{ translateY: slide.interpolate({ inputRange: [0, 1], outputRange: [400, 0] }) }] },
        ]}
      >
        <View style={styles.sheetHandle} />
        <View style={styles.sheetHead}>
          <Text style={styles.sheetTitle}>{title}</Text>
          <IconButton icon="close" label="إغلاق" onPress={onClose} />
        </View>
        <ScrollView keyboardShouldPersistTaps="handled" style={{ maxHeight: 560 }}>
          {children}
        </ScrollView>
      </Animated.View>
    </Modal>
  );
}

/* ---------- Kept for the settings screen ---------- */

export function KeyInput({
  label,
  value,
  onChangeText,
  placeholder,
  secret = false,
}: {
  label: string;
  value: string;
  onChangeText: (t: string) => void;
  placeholder?: string;
  secret?: boolean;
}) {
  return (
    <Field
      label={label}
      icon={secret ? "key-outline" : "at-outline"}
      value={value}
      onChangeText={onChangeText}
      placeholder={placeholder}
      secret={secret}
      ltr
      autoCapitalize="none"
      autoCorrect={false}
    />
  );
}

export type Status =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "ok"; message: string }
  | { kind: "error"; message: string };

export function StatusLine({ status }: { status: Status }) {
  if (status.kind === "idle") return null;
  if (status.kind === "loading") return <Banner kind="info" text="جاري الاتصال…" />;
  return <Banner kind={status.kind === "ok" ? "ok" : "error"} text={status.message} />;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
  screenContent: { paddingHorizontal: space.lg, paddingBottom: 140 },
  header: { paddingBottom: space.xl },
  headerRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm },
  headerTitle: { ...type.screenTitle, fontSize: 30, fontWeight: "800", color: colors.text, textAlign: "right", letterSpacing: 0.2 },
  headerSubtitle: { ...type.body, color: colors.textMuted, marginTop: 4, textAlign: "right" },

  card: {
    backgroundColor: CARD,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: HAIR,
    padding: space.lg,
  },
  sectionHead: {
    flexDirection: "row-reverse",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: space.md,
  },
  sectionTitle: { ...type.sectionTitle, fontSize: 17, color: colors.text, textAlign: "right" },

  button: {
    minHeight: 54,
    borderRadius: 999,
    paddingHorizontal: space.xl,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    backgroundColor: SOFT,
    borderWidth: 1,
    borderColor: HAIR,
  },
  buttonPrimary: {
    backgroundColor: colors.primary,
    borderColor: "rgba(255,255,255,0.22)",
    shadowColor: colors.glow,
    shadowOpacity: 0.55,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 6 },
    elevation: 10,
  },
  buttonSecondary: { backgroundColor: SOFT },
  buttonGhost: { backgroundColor: "transparent", borderColor: "transparent" },
  buttonDanger: { backgroundColor: colors.errorBg, borderColor: colors.errorText + "55" },
  buttonInner: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm },
  buttonText: { fontSize: 15, fontWeight: "800", letterSpacing: 0.2 },

  iconButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: CARD,
    borderWidth: 1,
    borderColor: HAIR,
  },

  fieldLabelRow: { flexDirection: "row-reverse", justifyContent: "space-between", marginBottom: space.sm },
  fieldLabel: { ...type.label, color: SOFT_TEXT, textAlign: "right" },
  fieldCounter: { fontSize: 12, color: colors.textMuted },
  fieldBox: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    minHeight: 54,
    paddingHorizontal: space.lg,
    borderRadius: radius.field,
    backgroundColor: colors.field,
    borderWidth: 1,
    borderColor: HAIR,
  },
  fieldBoxMulti: { alignItems: "flex-start", paddingVertical: space.md },
  fieldFocused: { borderColor: colors.primary, backgroundColor: colors.primarySoft },
  fieldError: { borderColor: colors.errorText },
  fieldInput: { flex: 1, fontSize: 15, color: colors.text, paddingVertical: space.sm },
  fieldInputMulti: { minHeight: 110, textAlignVertical: "top", paddingVertical: 0 },
  fieldMsgRow: { flexDirection: "row-reverse", alignItems: "center", gap: 4, marginTop: space.xs },
  fieldMsg: { ...type.hint, color: colors.textMuted, marginTop: space.xs, textAlign: "right" },

  chip: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: 6,
    paddingVertical: 9,
    paddingHorizontal: 16,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: HAIR,
    backgroundColor: CARD,
  },
  chipText: { color: SOFT_TEXT, fontWeight: "600", fontSize: 13 },

  segmented: {
    flexDirection: "row-reverse",
    backgroundColor: CARD,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: HAIR,
    padding: 4,
  },
  segment: { flex: 1, paddingVertical: 10, borderRadius: 999, alignItems: "center" },
  segmentActive: { backgroundColor: colors.primary, shadowColor: colors.glow, shadowOpacity: 0.5, shadowRadius: 10, elevation: 6 },
  segmentText: { color: colors.textMuted, fontWeight: "600", fontSize: 13 },

  row: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    paddingVertical: 15,
    paddingHorizontal: space.lg,
  },
  rowDivider: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: HAIR },
  rowIcon: { width: 40, height: 40, borderRadius: 20, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  rowTitle: { fontSize: 15, fontWeight: "600", color: colors.text, textAlign: "right" },
  rowSubtitle: { fontSize: 12.5, color: colors.textMuted, marginTop: 2, textAlign: "right", lineHeight: 18 },
  rowValue: { fontSize: 13, color: colors.textMuted },

  badge: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: 4,
    paddingHorizontal: 9,
    paddingVertical: 3,
    borderRadius: 999,
    alignSelf: "flex-end",
  },
  badgeText: { fontSize: 11, fontWeight: "700" },

  empty: { alignItems: "center", paddingVertical: space.xxl, paddingHorizontal: space.xl, gap: space.sm },
  emptyIcon: {
    width: 68,
    height: 68,
    borderRadius: 34,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: space.sm,
    overflow: "hidden",
  },
  emptyTitle: { ...type.sectionTitle, color: colors.text, textAlign: "center" },
  emptyText: { ...type.body, color: colors.textMuted, textAlign: "center", marginBottom: space.md },

  banner: {
    flexDirection: "row-reverse",
    alignItems: "flex-start",
    gap: space.sm,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: HAIR,
    padding: space.md,
    marginTop: space.md,
  },
  bannerText: { ...type.body, flex: 1, textAlign: "right" },

  step: { flexDirection: "row", gap: space.md },
  stepRail: { alignItems: "center", width: 28 },
  stepDot: {
    width: 28,
    height: 28,
    borderRadius: 14,
    borderWidth: 2,
    alignItems: "center",
    justifyContent: "center",
  },
  stepLine: { flex: 1, width: 2, backgroundColor: HAIR, marginVertical: 4 },
  stepTitle: { fontSize: 15, fontWeight: "600", color: colors.text, textAlign: "right", marginTop: 3 },
  stepDetail: { fontSize: 12.5, color: colors.textMuted, textAlign: "right", marginTop: 2 },

  stepper: { flexDirection: "row-reverse", gap: space.sm, marginBottom: space.xl },
  stepperItem: { flex: 1, gap: 6 },
  stepperBar: { height: 4, borderRadius: 2, backgroundColor: HAIR },
  stepperLabel: { fontSize: 11.5, fontWeight: "700", color: colors.faint, textAlign: "right" },

  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(3,5,20,0.72)" },
  sheet: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: colors.glassBar,
    borderTopWidth: 1,
    borderColor: colors.glassBorderStrong,
    borderTopLeftRadius: 32,
    borderTopRightRadius: 32,
    paddingHorizontal: space.lg,
    paddingTop: space.sm,
  },
  sheetHandle: {
    alignSelf: "center",
    width: 44,
    height: 5,
    borderRadius: 3,
    backgroundColor: colors.glassBorderStrong,
    marginBottom: space.md,
  },
  sheetHead: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: space.lg },
  sheetTitle: { ...type.sectionTitle, color: colors.text },
}); 
