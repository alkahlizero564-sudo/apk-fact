// Two connected apps (customer + admin) on Supabase, with the sign-in the owner wrote in the description, and push notifications.
import React, { useCallback, useEffect, useRef, useState } from "react";
import { Alert, View, Text, StyleSheet, Pressable, ScrollView, KeyboardAvoidingView, Platform } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { Button, Card, Chip, Field, IconButton, ListRow, Timeline, Banner, Sheet, useSteps } from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import { LANGS, PAIR_LANGS, Lang } from "../services/langs";
import { appExists } from "../services/appActions";
import { createPair, pairApps, pairReadiness, PairReadiness, setAdminPin } from "../services/pair";
import DesignStudio from "../components/DesignStudio";
import DbProjectsPanel from "../components/DbProjectsPanel";
import { OwnerPicker, Owner } from "../components/OwnerSheet";
import { setClient } from "../services/appActions";
import { listProjects, DbProject } from "../services/projects";
import UnderstandStudio, { UnderstandHandle } from "../components/UnderstandStudio";
import { Spec, specText } from "../services/understand";
import { loginFromText, loginLine, LOGIN_LABELS, PairLogin } from "../services/login";
import { saveApprovedDesign, clearDraft, DesignTarget } from "../services/design";
import { loadDraft as loadWork, clearDraft as clearWork, useAutoSave } from "../services/drafts";
import { colors, langColors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";

const EXAMPLES = [
  { label: "مطعم وطلبات", text: "مطعم: الزبون يتصفح المنيو ويطلب ويتابع حالة طلبه، والإدارة تستقبل الطلبات وتغيّر حالتها (جديد، قيد التحضير، في الطريق، تم التسليم) وتدير المنيو والأسعار." },
  { label: "متجر وتوصيل", text: "متجر: الزبون يتصفح المنتجات حسب التصنيف ويضيف للسلة ويطلب مع عنوان التوصيل ويتابع الطلب، والإدارة تدير المنتجات والمخزون وتستقبل الطلبات وتحدّث حالة التوصيل." },
  { label: "صالون وحجوزات", text: "صالون: الزبون يختار الخدمة واليوم والوقت المتاح ويحجز ويلغي حجزه، والإدارة تدير الخدمات والأسعار والمواعيد المتاحة وتؤكد أو ترفض الحجوزات." },
  { label: "عيادة ومواعيد", text: "عيادة: المريض يحجز موعد مع الطبيب ويشوف مواعيده ونتائج الزيارات، والإدارة تدير الأطباء والمواعيد وتسجل ملاحظات الزيارة." },
];

export default function PairScreen({ navigation, route }: RootScreenProps<"Pair">) {
  const insets = useSafeAreaInsets();
  const [base, setBase] = useState("");
  const [lang, setLang] = useState<Lang>("flutter");
  const [description, setDescription] = useState("");
  const [admins, setAdmins] = useState("");
  const [pin, setPin] = useState("");
  const [loginSheet, setLoginSheet] = useState(false);
  const [loginApps, setLoginApps] = useState<"" | "customer" | "admin" | "both">("");
  const [customerName, setCustomerName] = useState("");
  const [adminName, setAdminName] = useState("");
  const [push, setPush] = useState(true);
  // Where the pair's database lives: "" = the default project (Settings > Supabase), else a client's project.
  // A client picked on the create screen without a database project is asked again here (a pair needs one).
  const given = route.params?.owner;
  const [owner, setOwnerState] = useState<Owner | null>(given && !(given.kind === "client" && !given.ref) ? given : null);
  const [dbRef, setDbRef] = useState(route.params?.owner?.kind === "client" ? route.params.owner.ref ?? "" : "");
  function setOwner(o: Owner) {
    setOwnerState(o);
    setDbRef(o.kind === "client" ? o.ref ?? "" : "");
  }
  const [dbProjects, setDbProjects] = useState<DbProject[]>([]);
  const [dbSheet, setDbSheet] = useState(false);
  const [ready, setReady] = useState<PairReadiness | null>(null);
  const [taken, setTaken] = useState(false);
  const [phase, setPhase] = useState<"form" | "understand" | "design" | "running" | "done" | "failed">("form");
  const [spec, setSpec] = useState<Spec | null>(null); // the requirements the owner approved for both apps
  const [understandBusy, setUnderstandBusy] = useState(false);
  const understandRef = useRef<UnderstandHandle>(null);
  const [designs, setDesigns] = useState<Record<string, string>>({});
  const [designBusy, setDesignBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Unfinished work: offer to continue it after an error or after closing APK Fact (the admin PIN is not kept).
  type Work = {
    base: string; lang: Lang; description: string; admins: string; loginApps: "" | "customer" | "admin" | "both";
    customerName: string; adminName: string; push: boolean; owner: Owner | null; dbRef: string; spec: Spec | null;
    stage: "form" | "understand" | "design";
  };
  useEffect(() => {
    loadWork<Work>("pair").then((w) => {
      if (!w || !(w.base || w.description)) return;
      Alert.alert("تكمّل اللي كنت شغال فيه؟", `عندك نظام ما كمّلته${w.base ? `: «${w.base}»` : ""}. تكمّل من مكانك؟`, [
        { text: "ابدأ من جديد", style: "destructive", onPress: () => clearWork("pair") },
        {
          text: "كمّل",
          onPress: () => {
            setBase(w.base);
            setLang(w.lang);
            setDescription(w.description);
            setAdmins(w.admins);
            setLoginApps(w.loginApps);
            setCustomerName(w.customerName);
            setAdminName(w.adminName);
            setPush(w.push);
            if (w.owner) setOwnerState(w.owner);
            setDbRef(w.dbRef);
            setSpec(w.spec);
            // The admin PIN is never saved: when the admin app has no sign-in (it needs the PIN) start from the form.
            const adminSignIn = loginFromText(w.description) !== "none" && (w.loginApps === "admin" || w.loginApps === "both");
            setPhase(!adminSignIn ? "form" : w.stage === "design" && w.spec ? "design" : w.stage === "understand" ? "understand" : "form");
          },
        },
      ]);
    });
  }, []);
  const [steps, report, reset] = useSteps([
    ["design", "حفظ التصميم المعتمد للتطبيقين"],
    ["sync", "ربط المفاتيح بعمليات البناء (مشفّرة)"],
    ["backend", "Supabase: الجداول والأدوار والصلاحيات"],
    ["auth", "Supabase: تسجيل الدخول"],
    ["firebase", "Firebase: الإشعارات"],
    ["customer", "إنشاء تطبيق الزبون"],
    ["admin", "إنشاء تطبيق الإدارة"],
    ["save", "حفظ التطبيقين"],
  ]);

  useFocusEffect(
    useCallback(() => {
      pairReadiness().then(setReady).catch(() => {});
      listProjects().then(setDbProjects);
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
  // The owner decides sign-in in the description (services/login.ts, same rules in scripts/pair.py): whether
  // there is one and how (code / password). When there is, the sign-in sheet asks which app gets it.
  const mode = loginFromText(description);
  const pairLogin: PairLogin = {
    customer: mode !== "none" && (loginApps === "customer" || loginApps === "both") ? mode : "none",
    admin: mode !== "none" && (loginApps === "admin" || loginApps === "both") ? mode : "none",
  };
  const emails = admins.split(/[,\s]+/).filter(Boolean);
  const emailsValid = emails.length > 0 && emails.every((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e));
  const pinValid = /^[A-Za-z0-9]{4,12}$/.test(pin.trim());
  const loginReady = (mode === "none" || !!loginApps) && (pairLogin.admin !== "none" ? emailsValid : pinValid);
  const canSubmit =
    !!ready?.supabase && (!usePush || ready.firebase) && baseValid && !taken && description.trim().length > 20;

  useAutoSave(
    "pair",
    {
      base, lang, description, admins, loginApps, customerName, adminName, push, owner, dbRef, spec,
      stage: phase === "understand" || phase === "design" ? phase : "form",
    },
    (phase === "form" || phase === "understand" || phase === "design") && !!(base || description)
  );

  async function submit() {
    setPhase("running");
    setError(null);
    reset();
    if (!usePush) report("firebase", "done", lang === "python" ? "Python: إشعارات داخل التطبيق فقط" : "الإشعارات مطفية");
    try {
      report("design", "active");
      for (const t of designTargets) if (designs[t.key]) await saveApprovedDesign(t.key, designs[t.key]);
      report("design", "done");
      await createPair(
        {
          base: clean,
          lang,
          admins: pairLogin.admin !== "none" ? emails.join(",") : "-",
          push: usePush,
          description: fullDescription,
          customerName,
          adminName,
          supabaseRef: dbRef || undefined,
        },
        report
      );
      if (owner?.kind === "client") {
        await setClient(apps.customer, owner.name);
        await setClient(apps.admin, owner.name);
      }
      // Admin app without sign-in: it opens with the admin PIN (anyone could install it).
      if (pairLogin.admin === "none") await setAdminPin(clean.replace(/[^a-z0-9_]/g, "_"), dbRef, pin.trim());
      designTargets.forEach((t) => clearDraft(t));
      setPhase("done");
      clearWork("pair");
    } catch (e: any) {
      setError(e.message);
      setPhase("failed");
    }
  }

  const apps = pairApps(clean);
  // What the owner chose in the sign-in sheet, so the understood list matches it.
  const loginNote =
    `${description.trim()}\n\nتسجيل الدخول (اختيار صاحب التطبيق): تطبيق الزبون: ${LOGIN_LABELS[pairLogin.customer]}، ` +
    `تطبيق الإدارة: ${LOGIN_LABELS[pairLogin.admin]}${pairLogin.admin === "none" ? " (يفتح برمز الإدارة)" : ""}.`;
  // The owner's words plus the requirements they approved: the database, the designs and both apps follow it.
  const fullDescription =
    (spec ? `${description.trim()}\n${specText(spec)}` : description.trim()) + `\n${loginLine(pairLogin)}`;
  const designTargets: DesignTarget[] = [
    {
      key: apps.customer,
      label: "تطبيق الزبون",
      title: customerName.trim() || "تطبيق الزبون",
      description: fullDescription,
      lang,
      role: "customer",
    },
    {
      key: apps.admin,
      label: "تطبيق الإدارة",
      title: adminName.trim() || "تطبيق الإدارة",
      description: fullDescription,
      lang,
      role: "admin",
    },
  ];
  const designsReady = designTargets.every((t) => !!designs[t.key]) && !designBusy;

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
        {phase === "form" && !owner ? (
          <>
            <Text style={styles.label}>التطبيقين دول لمين؟</Text>
            <OwnerPicker pair onPick={setOwner} />
          </>
        ) : phase === "understand" ? (
          <>
            <Text style={styles.label}>فهمتك صح؟</Text>
            <Text style={styles.subtitle}>
              ده اللي فهمته من فكرتك للنظام كله، وكل بند مكتوب قدامه تبع أي تطبيق (الزبون، الإدارة، أو الاثنين). احذف
              أي حاجة غلط بـ ✕، جاوب الأسئلة، واكتب أي إضافة أو تصحيح. لما تكون القائمة هي بالضبط اللي في راسك اضغط
              «تمام، ده اللي أبغاه»، وقاعدة البيانات والتصميم والتطبيقين بيتبنوا عليها بند بند.
            </Text>
            <UnderstandStudio
              ref={understandRef}
              target={{ title: clean || "نظام الزبون والإدارة", description: loginNote, lang, pair: true }}
              onBusy={setUnderstandBusy}
            />
          </>
        ) : phase === "design" ? (
          <>
            <Text style={styles.label}>التصميم أولاً</Text>
            <Text style={styles.subtitle}>
              ده شكل شاشات التطبيقين قبل أي برمجة أو قاعدة بيانات. بدّل بين الزبون والإدارة، واضغط على الأزرار جوّه
              التصميم. اكتب أي تعديل والذكاء الاصطناعي بينفّذه. لما يعجبك اضغط «اعتمد التصميم».
            </Text>
            <DesignStudio targets={designTargets} onChange={setDesigns} onBusy={setDesignBusy} />
          </>
        ) : phase !== "form" ? (
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
              {PAIR_LANGS.map((l) => {
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

            <Text style={styles.namesHint}>
              {mode === "none"
                ? "تسجيل الدخول: ما ذكرته في الوصف، فالتطبيقين بدون تسجيل دخول. لو تبغاه اكتبه في الوصف (مثلاً: تسجيل دخول بالبريد ورمز تحقق، أو بكلمة مرور)."
                : `تسجيل الدخول من وصفك: ${LOGIN_LABELS[mode]}. بعد «افهم فكرتي» بتختار لأي تطبيق.`}
            </Text>

            <Pressable onPress={() => setOwnerState(null)} accessibilityRole="button">
              <Text style={styles.namesHint}>
                {owner?.kind === "client" ? `للزبون: ${owner.name}` : "لي (الأساسي)"} · <Text style={{ color: colors.primary }}>تغيير</Text>
              </Text>
            </Pressable>
            <Text style={styles.label}>قاعدة البيانات</Text>
            <View style={styles.chips}>
              <Chip label="مشروعي الأساسي" icon="home-outline" selected={!dbRef} onPress={() => setDbRef("")} />
              {dbProjects.map((p) => (
                <Chip key={p.ref} label={p.label} icon="server-outline" selected={dbRef === p.ref} onPress={() => setDbRef(p.ref)} />
              ))}
              <Chip label="مشروع زبون / جديد" icon="add" onPress={() => setDbSheet(true)} />
            </View>
            <Text style={styles.namesHint}>
              {dbRef
                ? "بيانات النظام ده بتتحفظ في مشروع الزبون لوحده، منفصلة عن باقي زباينك."
                : "النظام ده بيتعمل في مشروع Supabase الأساسي بتاعك (مع أي أنظمة تانية فيه). لكل زبون مشروع خاص، اختار أو أضف مشروع."}
            </Text>

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

      {phase === "form" && owner ? (
        <View style={[styles.footer, { paddingBottom: insets.bottom + space.md }]}>
          <Button
            title="افهم فكرتي"
            icon="bulb-outline"
            onPress={() => setLoginSheet(true)}
            disabled={!canSubmit}
            style={{ flex: 1 }}
          />
        </View>
      ) : phase === "understand" ? (
        <View style={[styles.footer, { paddingBottom: insets.bottom + space.md }]}>
          <Button title="رجوع" variant="secondary" onPress={() => setPhase("form")} disabled={understandBusy} style={{ flex: 1 }} />
          <Button
            title="تمام، ده اللي أبغاه"
            icon="checkmark"
            onPress={async () => {
              const approved = await understandRef.current?.approve();
              if (!approved) return;
              setSpec(approved);
              setDesigns({});
              setPhase("design");
            }}
            disabled={understandBusy}
            style={{ flex: 2 }}
          />
        </View>
      ) : phase === "design" ? (
        <View style={[styles.footer, { paddingBottom: insets.bottom + space.md }]}>
          <Button title="رجوع" variant="secondary" onPress={() => setPhase("understand")} disabled={designBusy} style={{ flex: 1 }} />
          <Button title="اعتمد التصميم وأنشئ التطبيقين" icon="checkmark-done" onPress={submit} disabled={!designsReady} style={{ flex: 2 }} />
        </View>
      ) : null}

      <Sheet visible={dbSheet} title="قاعدة بيانات للزبون" onClose={() => setDbSheet(false)}>
        <DbProjectsPanel
          showList={false}
          onAdded={(p) => {
            listProjects().then(setDbProjects);
            setDbRef(p.ref);
            setDbSheet(false);
          }}
        />
      </Sheet>

      <Sheet visible={loginSheet} title="تسجيل الدخول" onClose={() => setLoginSheet(false)}>
        {mode !== "none" ? (
          <>
            <Text style={styles.sheetText}>
              كتبت في الوصف تسجيل دخول ({LOGIN_LABELS[mode]}). تبغاه لأي تطبيق؟
            </Text>
            <View style={[styles.chips, { marginTop: 0, marginBottom: space.md }]}>
              {(
                [
                  ["customer", `التطبيق الأول: ${customerName.trim() || "الزبون"}`],
                  ["admin", `التطبيق الثاني: ${adminName.trim() || "الإدارة"}`],
                  ["both", "الاثنين"],
                ] as const
              ).map(([k, l]) => (
                <Chip key={k} label={l} selected={loginApps === k} onPress={() => setLoginApps(k)} />
              ))}
            </View>
          </>
        ) : (
          <Text style={styles.sheetText}>
            وصفك ما فيه تسجيل دخول، فالتطبيقين بيفتحوا على طول بدون تسجيل دخول. لو تبغاه، ارجع واكتبه في الوصف.
          </Text>
        )}
        {mode !== "none" && pairLogin.admin !== "none" ? (
          <Field
            label="بريد الإدارة"
            icon="shield-outline"
            value={admins}
            onChangeText={setAdmins}
            placeholder="owner@example.com"
            ltr
            autoCapitalize="none"
            keyboardType="email-address"
            error={
              admins && !emailsValid
                ? "اكتب بريد صحيح (أو أكتر، مفصولين بفاصلة)"
                : emails.find((e) => /\.(con|cmo|comm|cpm|vom)$|@(gmial|gamil|gmai|gmal|hotmial|yaho)\./i.test(e))
                ? `اتأكد من البريد: ${emails.find((e) => /\.(con|cmo|comm|cpm|vom)$|@(gmial|gamil|gmai|gmal|hotmial|yaho)\./i.test(e))} (غالباً قصدك .com)`
                : null
            }
            helper="اللي يسجّل دخول بالبريد ده في تطبيق الإدارة يصير مدير."
          />
        ) : mode === "none" || loginApps ? (
          <Field
            label="رمز الإدارة (PIN)"
            icon="keypad-outline"
            value={pin}
            onChangeText={setPin}
            placeholder="مثال: 4821"
            ltr
            secret
            autoCapitalize="none"
            maxLength={12}
            error={pin && !pinValid ? "من 4 إلى 12 حرف إنجليزي أو رقم" : null}
            helper="تطبيق الإدارة بدون تسجيل دخول، فبيطلب الرمز ده مرة واحدة على كل جهاز عشان ما يدخل الإدارة غيرك."
          />
        ) : null}
        <Button
          title="تم"
          icon="checkmark"
          disabled={!loginReady}
          onPress={() => {
            setLoginSheet(false);
            setSpec(null);
            setDesigns({});
            setPhase("understand");
          }}
        />
      </Sheet>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  sheetText: { ...type.body, color: colors.textMuted, textAlign: "right", marginBottom: space.md },
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
