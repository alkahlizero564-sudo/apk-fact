// When a screen hits an unexpected error, APK Fact shows this instead of closing. Unfinished work is kept
// (services/drafts.ts), so «رجوع للرئيسية» goes back without losing it; the error text can be shared.
import React from "react";
import { View, Text, StyleSheet, ScrollView, Share, Pressable } from "react-native";
import { Ionicons } from "./icons";
import { colors, radius, space, type } from "../theme";

type State = { error: Error | null; key: number };

let showFatal: ((e: Error) => void) | null = null;

// Errors outside rendering (in a button handler or a timer) normally close the app in release builds.
const g: any = globalThis as any;
if (g.ErrorUtils?.setGlobalHandler) {
  const previous = g.ErrorUtils.getGlobalHandler?.();
  g.ErrorUtils.setGlobalHandler((error: any, isFatal?: boolean) => {
    if (isFatal && showFatal) showFatal(error instanceof Error ? error : new Error(String(error)));
    else previous?.(error, isFatal);
  });
}

export default class ErrorBoundary extends React.Component<{ children: React.ReactNode }, State> {
  state: State = { error: null, key: 0 };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidMount() {
    showFatal = (e) => this.setState({ error: e });
  }

  componentWillUnmount() {
    showFatal = null;
  }

  render() {
    const { error, key } = this.state;
    if (!error) return <React.Fragment key={key}>{this.props.children}</React.Fragment>;
    const text = `${error.name}: ${error.message}\n${(error.stack ?? "").split("\n").slice(0, 6).join("\n")}`;
    return (
      <View style={styles.root}>
        <Ionicons name="alert-circle-outline" size={56} color={colors.warnText} />
        <Text style={styles.title}>حصل خطأ غير متوقع</Text>
        <Text style={styles.body}>
          شغلك محفوظ. ارجع للرئيسية وافتح «تطبيق جديد» أو «تطبيقين متصلين» تاني وبيسألك تكمّل من مكانك. لو الخطأ اتكرر،
          شارك النص ده عشان يتصلّح.
        </Text>
        <ScrollView style={styles.box}>
          <Text selectable style={styles.code}>
            {text}
          </Text>
        </ScrollView>
        <Pressable style={[styles.btn, { backgroundColor: colors.primary }]} onPress={() => this.setState({ error: null, key: key + 1 })}>
          <Text style={styles.btnText}>رجوع للرئيسية</Text>
        </Pressable>
        <Pressable style={[styles.btn, { backgroundColor: colors.surfaceAlt }]} onPress={() => Share.share({ message: text })}>
          <Text style={styles.btnText}>شارك نص الخطأ</Text>
        </Pressable>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg, alignItems: "center", justifyContent: "center", padding: space.xl, gap: space.md },
  title: { ...type.screenTitle, color: colors.text, textAlign: "center" },
  body: { ...type.body, color: colors.textMuted, textAlign: "center" },
  box: { maxHeight: 160, alignSelf: "stretch", backgroundColor: colors.field, borderRadius: radius.field, padding: space.md },
  code: { fontFamily: "monospace", fontSize: 11, color: colors.textMuted, textAlign: "left" },
  btn: { alignSelf: "stretch", borderRadius: radius.button, paddingVertical: 14, alignItems: "center" },
  btnText: { color: colors.text, fontSize: 16, fontWeight: "700" },
});
