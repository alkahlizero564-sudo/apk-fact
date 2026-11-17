// The design stage UI: shows the AI design of one app (or both apps of a pair), lets the owner change it
// with AI, undo, start over or view it full screen. The parent reads the current designs through onChange.
import { refImages } from "../services/attachment";
import React, { useEffect, useRef, useState } from "react";
import { View, Text, StyleSheet, Modal, ActivityIndicator, Pressable } from "react-native";
import { WebView } from "react-native-webview";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "./icons";
import Backdrop from "./Backdrop";
import { Button, Chip, Field, Banner, IconButton } from "./ui";
import { DesignTarget, designApp, reviseDesign, loadDraft, saveDraft } from "../services/design";
import { colors, space, radius, type } from "../theme";

const IDEAS = [
  "غيّر الألوان لألوان أفخم",
  "خلّي التصميم أبسط وأنظف",
  "كبّر الخطوط والأزرار",
  "أضف شاشة جديدة لـ…",
  "احذف الشاشة/القسم الخاص بـ…",
  "غيّر شكل الشريط السفلي",
  "أضف وضع ليلي",
  "خلّي البطاقات بصور أكبر",
];

type Props = {
  targets: DesignTarget[];
  onChange: (designs: Record<string, string>) => void;
  onBusy?: (busy: boolean) => void;
};

export default function DesignStudio({ targets, onChange, onBusy }: Props) {
  const insets = useSafeAreaInsets();
  const [history, setHistory] = useState<Record<string, string[]>>({});
  const [active, setActive] = useState(targets[0]?.key ?? "");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [change, setChange] = useState("");
  const [both, setBoth] = useState(false);
  const [full, setFull] = useState(false);
  const [live, setLive] = useState<string | null>(null); // the current design as it's being written (streaming)
  const started = useRef("");
  const lastLive = useRef(0);

  const sig = targets.map((t) => `${t.key}|${t.lang}|${t.description}`).join("\n");
  const current = (k: string) => history[k]?.[history[k].length - 1];
  const target = targets.find((t) => t.key === active) ?? targets[0];

  function setBusyBoth(b: boolean) {
    setBusy(b);
    onBusy?.(b);
  }

  function commit(next: Record<string, string[]>) {
    setHistory(next);
    const designs: Record<string, string> = {};
    for (const t of targets) {
      const h = next[t.key];
      if (h?.length) designs[t.key] = h[h.length - 1];
    }
    onChange(designs);
    for (const t of targets) if (next[t.key]?.length) saveDraft(t, next[t.key]);
  }

  async function generate(keys: string[], fresh: boolean) {
    setBusyBoth(true);
    setError(null);
    let next = { ...history };
    try {
      for (const t of targets) {
        if (!keys.includes(t.key)) continue;
        if (!fresh) {
          const draft = await loadDraft(t);
          if (draft?.length) {
            next = { ...next, [t.key]: draft };
            commit(next);
            continue;
          }
        }
        setActive(t.key);
        setLive(null);
        lastLive.current = 0;
        // The second app of a pair shares the brand of the first one.
        const brand = targets.map((x) => x.key).filter((k) => k !== t.key).map((k) => next[k]?.[next[k].length - 1]).find(Boolean);
        const onPartial = (partial: string) => {
          const now = Date.now();
          if (partial.length > 300 && now - lastLive.current > 500) {
            lastLive.current = now;
            setLive(partial);
          }
        };
        const html = await designApp(t, (s) => setStatus(`${targets.length > 1 ? t.label + ": " : ""}${s}`), brand, refImages(), onPartial);
        setLive(null);
        next = { ...next, [t.key]: [...(fresh ? next[t.key] ?? [] : []), html] };
        commit(next);
      }
    } catch (e: any) {
      setError(e.message);
    } finally {
      setStatus("");
      setLive(null);
      setBusyBoth(false);
    }
  }

  useEffect(() => {
    if (!targets.length || started.current === sig) return;
    started.current = sig;
    setActive(targets[0].key);
    generate(
      targets.map((t) => t.key),
      false
    );
  }, [sig]);

  async function applyChange() {
    const text = change.trim();
    if (text.length < 3) return;
    const keys = both && targets.length > 1 ? targets.map((t) => t.key) : [active];
    setBusyBoth(true);
    setError(null);
    let next = { ...history };
    try {
      for (const k of keys) {
        const t = targets.find((x) => x.key === k)!;
        const html = current(k);
        if (!html) continue;
        setActive(k);
        const out = await reviseDesign(t, html, text, (s) => setStatus(`${targets.length > 1 ? t.label + ": " : ""}${s}`));
        next = { ...next, [k]: [...(next[k] ?? []), out] };
        commit(next);
      }
      setChange("");
    } catch (e: any) {
      setError(e.message);
    } finally {
      setStatus("");
      setBusyBoth(false);
    }
  }

  function undo() {
    const h = history[active];
    if (!h || h.length < 2) return;
    commit({ ...history, [active]: h.slice(0, -1) });
  }

  const html = current(active);
  const versions = history[active]?.length ?? 0;

  return (
    <View>
      {targets.length > 1 ? (
        <View style={styles.tabs}>
          {targets.map((t) => (
            <Chip key={t.key} label={t.label} selected={active === t.key} onPress={() => setActive(t.key)} />
          ))}
        </View>
      ) : null}

      <View style={styles.frame}>
        {html ? (
          <WebView key={`${active}-${versions}`} originWhitelist={["*"]} source={{ html }} style={styles.web} nestedScrollEnabled />
        ) : live ? (
          <View style={styles.web}>
            <WebView originWhitelist={["*"]} source={{ html: live }} style={styles.web} scrollEnabled={false} />
            <View style={styles.liveRibbon}>
              <ActivityIndicator color={colors.primaryText} size="small" />
              <Text style={styles.liveText}>يرسم التصميم مباشرة…</Text>
            </View>
          </View>
        ) : (
          <View style={styles.wait}>
            <ActivityIndicator color={colors.accent} size="large" />
            <Text style={styles.waitText}>{status || "بنجهّز التصميم…"}</Text>
            <Text style={styles.waitHint}>المصمّم بيرسم كل شاشات التطبيق. بياخد دقيقة أو اتنين.</Text>
          </View>
        )}
        {html && busy ? (
          <View style={styles.overlay}>
            <ActivityIndicator color={colors.primaryText} />
            <Text style={styles.overlayText}>{status}</Text>
          </View>
        ) : null}
      </View>

      <View style={styles.tools}>
        <IconButton icon="expand-outline" label="ملء الشاشة" onPress={() => html && setFull(true)} />
        <IconButton icon="arrow-undo-outline" label="تراجع" onPress={undo} />
        <Pressable
          onPress={() => !busy && generate([active], true)}
          style={({ pressed }) => [styles.redo, pressed && { opacity: 0.7 }]}
          accessibilityRole="button"
        >
          <Ionicons name="color-palette-outline" size={16} color={colors.infoText} />
          <Text style={styles.redoText}>تصميم مختلف</Text>
        </Pressable>
        <Text style={styles.version}>{versions ? `النسخة ${versions}` : ""}</Text>
      </View>

      {error ? <Banner kind="error" text={error} /> : null}

      <Field
        label={`شنو تغيّر في تصميم ${targets.length > 1 ? target?.label : "التطبيق"}؟`}
        icon="brush-outline"
        value={change}
        onChangeText={setChange}
        placeholder="مثال: خلّي اللون الأساسي أخضر، وأضف شاشة العروض، واحذف زر المشاركة"
        multiline
        maxLength={1200}
      />
      <View style={styles.chips}>
        {IDEAS.map((i) => (
          <Chip key={i} label={i} onPress={() => setChange((c) => `${c.trim()} ${i}`.trim())} />
        ))}
      </View>
      {targets.length > 1 ? (
        <View style={styles.chips}>
          <Chip label="على التطبيق المعروض" selected={!both} onPress={() => setBoth(false)} />
          <Chip label="على التطبيقين" selected={both} onPress={() => setBoth(true)} />
        </View>
      ) : null}
      <Button
        title="عدّل التصميم بالذكاء الاصطناعي"
        icon="sparkles"
        variant="secondary"
        onPress={applyChange}
        loading={busy && !!html}
        disabled={busy || change.trim().length < 3 || !html}
      />

      <Modal visible={full} animationType="slide" onRequestClose={() => setFull(false)}>
        <View style={[styles.fullRoot, { paddingTop: insets.top }]}>
          <Backdrop />
          <View style={styles.fullBar}>
            <IconButton icon="close" label="إغلاق" onPress={() => setFull(false)} />
            <Text style={styles.fullTitle}>{target?.label}</Text>
          </View>
          {html ? <WebView originWhitelist={["*"]} source={{ html }} style={{ flex: 1 }} /> : null}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  tabs: { flexDirection: "row-reverse", gap: space.sm, marginBottom: space.md },
  frame: {
    height: 560,
    borderRadius: radius.card,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  web: { flex: 1, backgroundColor: colors.surface },
  wait: { flex: 1, alignItems: "center", justifyContent: "center", gap: space.md, padding: space.xl },
  waitText: { ...type.label, color: colors.text, textAlign: "center" },
  waitHint: { ...type.hint, color: colors.textMuted, textAlign: "center" },
  overlay: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    padding: space.md,
    backgroundColor: "rgba(10,12,20,0.85)",
  },
  overlayText: { flex: 1, color: colors.primaryText, fontSize: 13, textAlign: "right" },
  liveRibbon: { position: "absolute", top: space.md, alignSelf: "center", flexDirection: "row-reverse", alignItems: "center", gap: space.sm, backgroundColor: colors.primary, paddingHorizontal: space.md, paddingVertical: 6, borderRadius: 999 },
  liveText: { color: colors.primaryText, fontSize: 12, fontWeight: "800" },
  tools: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm, marginTop: space.md, marginBottom: space.md },
  redo: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: space.md,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.primarySoft,
  },
  redoText: { color: colors.infoText, fontWeight: "800", fontSize: 13 },
  version: { flex: 1, textAlign: "left", color: colors.textMuted, fontSize: 12 },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginTop: space.sm, marginBottom: space.md },
  fullRoot: { flex: 1, backgroundColor: colors.base },
  fullBar: { flexDirection: "row-reverse", alignItems: "center", gap: space.md, padding: space.md },
  fullTitle: { ...type.label, color: colors.text, flex: 1, textAlign: "right" },
});
