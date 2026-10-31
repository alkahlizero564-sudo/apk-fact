// Two connected apps (customer + admin) on Supabase, with email-code login and push notifications.
import React, { useCallback, useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable, ScrollView, KeyboardAvoidingView, Platform } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { Button, Card, Chip, Field, IconButton, ListRow, Timeline, Banner, useSteps } from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import { LANGS, LANG_ORDER, Lang } from "../services/langs";
import { appExists } from "../services/appActions";
import { createPair, pairApps, pairReadiness, PairReadiness } from "../services/pair";
import { colors, langColors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";

const EXAMPLES = [
  { label: "مطعم وطلبات", text: "مطعم: الزبون يتصفح المنيو ويطلب ويتابع حالة طلبه، والإدارة تستقبل الطلبات وتغيّر حالتها (جديد، قيد التحضير، في الطريق، تم التسليم) وتدير المنيو والأسعار." },
  { label: "متجر وتوصيل", text: "متجر: الزبون يتصفح المنتجات حسب التصنيف ويضيف للسلة ويطلب مع عنوان التوصيل ويتابع الطلب، والإدارة تدير المنتجات والمخزون وتستقبل الطلبات وتحدّث حالة التوصيل." },
  { label: "صالون وحجوزات", text: "صالون: الزبون يختار الخدمة واليوم والوقت المتاح ويحجز ويلغي حجزه، والإدارة تدير الخدمات والأسعار والمواعيد المتاحة وتؤكد أو ترفض الحجوزات." },
  { label: "عيادة ومواعيد", text: "عيادة: المريض يحجز موعد مع الطبيب ويشوف مواعيده ونتائج الزيارات، والإدارة تدير الأطباء والمواعيد وتسجل ملاحظات الزيارة." },
];

export default function PairScreen({ navigation }: RootScreenProps<"Pair">) {
  const insets = useSafeAreaInsets();
  const [base, setBase] = useState("");
  const [lang, setLang] = useState<Lang>("flutter");
  const [description, setDescription] = useState("");
  const [admins, setAdmins] = useState("");
  const [customerName, setCustomerName] = useState("");
  const [adminName, setAdminName] = useState("");
  const [push, setPush] = useState(true);
  const [ready, setReady] = useState<PairReadiness | null>(null);
  const [taken, setTaken] = useState(false);
  const [phase, setPhase] = useState<"form" | "running" | "done" | "failed">("form");
  const [error, setError] = useState<string | null>(null);
  const [steps, report, reset] = useSteps([
    ["sync", "ربط المفاتيح بعمليات البناء (مشفّرة)"],
    ["backend", "Supabase: الجداول والأدوار والصلاحيات"],
    ["auth", "Supabase: تسجيل الدخول برمز البريد"],
    ["firebase", "Firebase: الإشعارات"],
    ["customer", "إنشاء تطبيق الزبون"],
    ["admin", "إنشاء تطبيق الإدارة"],
    ["save", "حفظ التطبيقين"],
  ]);

  useFocusEffect(
    useCallback(() => {
      pairReadiness().then(setReady).catch(() => {});
    }, [])
  );

  const clean = base.trim().toLowerCase();
  const baseValid = /^[a-z][a-z0-9-]{1,30}$/.test(clean);
  useEffect(() => {
    setTaken(false);
    if (!baseValid) return;
    const t = setTimeout(async () => {
      const names = pairApps(clean);
      setTaken(!!(await appExists(names.customer).catch(() => null)) || !!(await appExists(names.admin).catch(() => null)));
    }, 500);
    return () => clearTimeout(t);
  }, [clean, baseValid]);

  const usePush = push && lang !== "python";
  const emails = admins.split(/[,\s]+/).filter(Boolean);
  const emailsValid = emails.length > 0 && emails.every((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e));
  const canSubmit =
    !!ready?.supabase && (!usePush || ready.firebase) && baseValid && !taken && description.trim().length > 20 && emailsValid;

  async function submit() {
    setPhase("running");
    setError(null);
    reset();
    if (!usePush) report("firebase", "done", lang === "python" ? "Python: إشعارات داخل التطبيق فقط" : "الإشعارات مطفية");
    try {
      await createPair({ base: clean, lang, admins: emails.join(","), push: usePush, description: description.trim(), customerName, adminName }, report);
      setPhase("done");
    } catch (e: any) {
      setError(e.message);
      setPhase("failed");
    }
  }

  const apps = pairApps(clean);

  return (
    <KeyboardAvoidingView style={styles.root} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <View style={[styles.top, { paddingTop: insets.top + space.md }]}>
        <View style={styles.topRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.title}>تطبيقين متصلين</Text>
            <Text style={styles.subtitle}>زبون + إدارة · Supabase · دخول برمز البريد · إشعارات</Text>
          </View>
          <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        {phase !== "form" ? (
          <>
            <Card style={styles.pairCard}>
              {(["customer", "admin"] as const).map((r) => (
                <View key={r} style={styles.pairItem}>
                  <AppAvatar name={apps[r]} lang={lang} size={52} />
                  <Text style={styles.pairName}>{apps[r]}</Text>
                  <Text style={styles.pairRole}>{r === "customer" ? "تطبيق الزبون" : "تطبيق الإدارة"}</Text>
                </View>
              ))}
              <Ionicons name="swap-horizontal" size={22} color={colors.accent} style={styles.link} />
            </Card>
            <Card>
              <Timeline steps={steps} />
            </Card>
            {phase === "running" ? <Banner kind="info" text="بياخد من 5 إلى 15 دقيقة. تقدر تقفل الشاشة، والعملية بتكمل على GitHub." /> : null}
            {phase === "done" ? (
              <>
                <Banner kind="ok" text="التطبيقين جاهزين ومتصلين! ابنِ كل واحد من صفحته وثبّته." />
                <View style={styles.row}>
                  <Button title="تطبيق الزبون" variant="secondary" onPress={() => navigation.replace("AppDetail", { name: apps.customer, lang })} style={{ flex: 1 }} />
                  <Button title="تطبيق الإدارة" onPress={() => navigation.replace("AppDetail", { name: apps.admin, lang })} style={{ flex: 1 }} />
                </View>
              </>
            ) : null}
            {phase === "failed" && error ? (
              <>
                <Banner kind="error" text={error} />
                <View style={styles.row}>
                  <Button title="تعديل" variant="secondary" onPress={() => setPhase("form")} style={{ flex: 1 }} />
                  <Button title="إعادة المحاولة" icon="refresh" onPress={submit} style={{ flex: 2 }} />
                </View>
              </>
            ) : null}
          </>
        ) : (
          <>
            <Card style={{ padding: 0, overflow: "hidden" }}>
              <ListRow
                icon="server-outline"
                tint={ready?.supabase ? colors.okText : colors.errorText}
                title="Supabase"
                subtitle={ready?.supabase ? "جاهز: قاعدة البيانات وتسجيل الدخول" : "مطلوب: أضف المفتاح و Project Ref من الإعدادات"}
                onPress={() => navigation.navigate("Tabs", { screen: "Settings" } as never)}
              />
              <ListRow
                icon="notifications-outline"
                tint={!usePush ? colors.textMuted : ready?.firebase ? colors.okText : colors.errorText}
                title="Firebase"
                subtitle={
                  !usePush ? "غير مطلوب (الإشعارات مطفية)" : ready?.firebase ? `جاهز: ${ready.firebaseProject}` : "مطلوب للإشعارات: أضف مفتاح حساب الخدمة من الإعدادات"
                }
                onPress={() => navigation.navigate("Tabs", { screen: "Settings" } as never)}
              />
              <ListRow
                icon="mail-outline"
                tint={ready?.smtp ? colors.okText : colors.warnText}
                title="بريد الرموز (SMTP)"
                subtitle={ready?.smtp ? "جاهز: الرموز بتوصل لكل الزبائن" : "اختياري لكن مهم: بدونه Supabase يرسل رموز قليلة ولعناوين فريقك فقط"}
                onPress={() => navigation.navigate("Tabs", { screen: "Settings" } as never)}
                last
              />
            </Card>

            <Field
              label="اسم المشروع"
              icon="at-outline"
              value={base}
              onChangeText={setBase}
              placeholder="مثال: cafe"
              ltr
              autoCapitalize="none"
              autoCorrect={false}
              error={base && !baseValid ? "حروف إنجليزية صغيرة وأرقام و -، ويبدأ بحرف" : taken ? "في تطبيق بنفس الاسم. اختر اسم تاني." : null}
              helper={baseValid ? `التطبيقين: ${apps.customer} و ${apps.admin}` : "منه بيتعمل اسم التطبيقين"}
            />
            <View style={styles.names}>
              <Field
                label="اسم تطبيق الزبون"
                icon="person-outline"
                value={customerName}
                onChangeText={setCustomerName}
                placeholder="مثال: كافيه النيل"
                maxLength={40}
              />
              <Field
                label="اسم تطبيق الإدارة"
                icon="shield-checkmark-outline"
                value={adminName}
                onChangeText={setAdminName}
                placeholder="مثال: إدارة كافيه النيل"
                maxLength={40}
              />
            </View>
            <Text style={styles.namesHint}>الأسماء دي بتظهر تحت أيقونات التطبيقين بعد التثبيت، وتقدر تكتبها بالعربي (اختياري).</Text>

            <Text style={styles.label}>اللغة</Text>
            <View style={styles.langs}>
              {LANG_ORDER.map((l) => {
                const sel = lang === l;
                return (
                  <Pressable
                    key={l}
                    onPress={() => setLang(l)}
                    style={[styles.lang, sel && { borderColor: langColors[l], backgroundColor: langColors[l] + "14" }]}
                    accessibilityRole="radio"
                    accessibilityState={{ selected: sel }}
                  >
                    <Ionicons name={LANG_ICONS[l]} size={24} color={sel ? langColors[l] : colors.textMuted} />
                    <Text style={[styles.langText, sel && { color: colors.text }]}>{LANGS[l].label}</Text>
                  </Pressable>
                );
              })}
            </View>
            {lang === "python" ? (
              <Banner kind="info" text="Python (Flet) ما بيدعم إشعارات Firebase: الإشعارات بتظهر داخل التطبيق وهو مفتوح فقط. للإشعارات والتطبيق مقفول اختر Flutter أو HTML." />
            ) : null}

            <Field
              label="وصف المشروع"
              icon="document-text-outline"
              value={description}
              onChangeText={setDescription}
              placeholder="شنو بيعمل الزبون؟ وشنو بتعمل الإدارة؟ ومتى يوصل إشعار لمين؟"
              multiline
              maxLength={2500}
              counter
            />
            <View style={styles.chips}>
              {EXAMPLES.map((e) => (
                <Chip key={e.label} label={e.label} selected={description === e.text} onPress={() => setDescription(e.text)} />
              ))}
            </View>

            <Field
              label="إيميل الإدارة"
              icon="shield-outline"
              value={admins}
              onChangeText={setAdmins}
              placeholder="owner@example.com"
              ltr
              autoCapitalize="none"
              keyboardType="email-address"
              error={admins && !emailsValid ? "اكتب إيميل صحيح (أو أكتر، مفصولين بفاصلة)" : null}
              helper="أي حد يسجّل دخول بالإيميل ده يصير مدير تلقائياً. الباقي زبائن."
            />

            <Pressable
              onPress={() => lang !== "python" && setPush((p) => !p)}
              style={[styles.toggle, lang === "python" && { opacity: 0.5 }]}
              accessibilityRole="switch"
              accessibilityState={{ checked: usePush, disabled: lang === "python" }}
            >
              <Ionicons name={usePush ? "toggle" : "toggle-outline"} size={34} color={usePush ? colors.accent : colors.textMuted} />
              <View style={{ flex: 1 }}>
                <Text style={styles.toggleTitle}>إشعارات حتى والتطبيق مقفول</Text>
                <Text style={styles.toggleSub}>طلب جديد يوصل للإدارة، وتغيير الحالة يوصل للزبون (Firebase)</Text>
              </View>
            </Pressable>
          </>
        )}
      </ScrollView>

      {phase === "form" ? (
        <View style={[styles.footer, { paddingBottom: insets.bottom + space.md }]}>
          <Button title="أنشئ التطبيقين" icon="git-merge-outline" onPress={submit} disabled={!canSubmit} style={{ flex: 1 }} />
        </View>
      ) : null}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  top: { paddingHorizontal: space.lg, paddingBottom: space.md },
  topRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.md },
  title: { ...type.screenTitle, fontSize: 24, fontWeight: "800", color: colors.text, textAlign: "right" },
  subtitle: { ...type.hint, color: colors.textMuted, textAlign: "right" },
  body: { paddingHorizontal: space.lg, paddingBottom: space.xxl, gap: space.md },
  label: { ...type.label, color: colors.text, textAlign: "right" },
  langs: { flexDirection: "row-reverse", gap: space.sm },
  lang: {
    flex: 1,
    alignItems: "center",
    gap: 4,
    paddingVertical: space.md,
    borderRadius: radius.field,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.field,
  },
  langText: { color: colors.textMuted, fontWeight: "800" },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginTop: -space.sm },
  toggle: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    padding: space.lg,
    borderRadius: radius.card,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  toggleTitle: { fontSize: 15, fontWeight: "800", color: colors.text, textAlign: "right" },
  toggleSub: { ...type.hint, color: colors.textMuted, textAlign: "right" },
  pairCard: { flexDirection: "row-reverse", justifyContent: "space-around", alignItems: "center" },
  pairItem: { alignItems: "center", gap: 6, flex: 1 },
  pairName: { fontWeight: "900", color: colors.text },
  pairRole: { ...type.hint, color: colors.textMuted },
  link: { position: "absolute", alignSelf: "center", left: "47%" },
  row: { flexDirection: "row-reverse", gap: space.md },
  footer: {
    flexDirection: "row-reverse",
    gap: space.md,
    paddingHorizontal: space.lg,
    paddingTop: space.md,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  names: { gap: 0 },
  namesHint: { fontSize: 12, color: colors.textMuted, textAlign: "right", marginTop: -space.sm, marginBottom: space.lg },
});
