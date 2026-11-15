// Two connected apps (customer + admin) on Supabase, with the sign-in the owner wrote in the description, and push notifications.
import React, { useCallback, useEffect, useRef, useState } from "react";
import { Alert, View, Text, StyleSheet, Pressable, ScrollView, KeyboardAvoidingView, Platform, Image } from "react-native";
import * as ImagePicker from "expo-image-picker";
import { setRefImage } from "../services/attachment";
import { AiImage } from "../services/instantPreview";
import { useFocusEffect } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { Button, Card, Chip, Field, IconButton, ListRow, Timeline, Banner, Sheet, useSteps } from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import { LANGS, PAIR_LANGS, Lang } from "../services/langs";
import { appExists } from "../services/appActions";
import { takeGalleryPairPick } from "../services/galleryPick";
import { createPair, pairApps, pairReadiness, PairReadiness, setAdminPin } from "../services/pair";
import DesignStudio from "../components/DesignStudio";
import DbProjectsPanel from "../components/DbProjectsPanel";
import { OwnerPicker, Owner } from "../components/OwnerSheet";
import { setClient } from "../services/appActions";
import { listProjects, DbProject } from "../services/projects";
import UnderstandStudio, { UnderstandHandle } from "../components/UnderstandStudio";
import { Spec, specText } from "../services/understand";
import { loginLine, LOGIN_LABELS, LOGIN_CHOICES, LoginMode, PairLogin, suggestedChoice, usesEmail } from "../services/login";
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
  // A design picked in the gallery starts this pair (taken once).
  const [picked] = useState(() => takeGalleryPairPick());
  const [base, setBase] = useState(picked?.base ?? "");
  const [lang, setLang] = useState<Lang>(picked?.lang ?? "flutter");
  const [description, setDescription] = useState(picked?.description ?? "");
  const [refPic, setRefPic] = useState<{ uri: string; image: AiImage } | null>(null);
  const [admins, setAdmins] = useState("");
  const [pin, setPin] = useState("");
  const [loginSheet, setLoginSheet] = useState(false);
  const [loginApps, setLoginApps] = useState<"" | "customer" | "admin" | "both">("");
  const [method, setMethod] = useState<LoginMode | "">(""); // how users sign in (the owner picks it in the sheet)
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

  // An optional reference picture for both apps; synced to the shared holder so understanding and design use it.
  useEffect(() => {
    setRefImage(refPic?.image ?? null);
    return () => setRefImage(null);
  }, [refPic]);
  async function pickReferenceImage() {
    try {
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        Alert.alert("إذن الصور", "نحتاج إذن الوصول للصور لإرفاق صورة مرجعية.");
        return;
      }
      const res = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.5, base64: true });
      const a = res.canceled ? null : res.assets?.[0];
      if (a?.base64) setRefPic({ uri: a.uri, image: { data: a.base64, mime: a.mimeType || "image/jpeg" } });
    } catch (e: any) {
      Alert.alert("تعذّر إرفاق الصورة", e?.message ?? "جرّب مرة أخرى");
    }
  }
  const [designs, setDesigns] = useState<Record<string, string>>({});
  const [designBusy, setDesignBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Unfinished work: offer to continue it after an error or after closing APK Fact (the admin PIN is not kept).
  type Work = {
    base: string; lang: Lang; description: string; admins: string; loginApps: "" | "customer" | "admin" | "both"; method?: LoginMode | "";
    customerName: string; adminName: string; push: boolean; owner: Owner | null; dbRef: string; spec: Spec | null;
    stage: "form" | "understand" | "design";
  };
  useEffect(() => {
    if (picked) return; // started from a gallery design: don't offer an older draft over it
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
            setMethod(w.method ?? "");
            setCustomerName(w.customerName);
            setAdminName(w.adminName);
            setPush(w.push);
            // «لمين؟» is asked again (one tap; it also picks the database), never taken silently from a draft.
            setSpec(w.spec);
            // The admin PIN is never saved: when the admin app has no sign-in (it needs the PIN) start from the form.
            const adminEmail = !!w.method && usesEmail(w.method) && (w.loginApps === "admin" || w.loginApps === "both");
            setPhase(!adminEmail ? "form" : w.stage === "design" && w.spec ? "design" : w.stage === "understand" ? "understand" : "form");
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
  // The owner picks the sign-in in the sheet (services/login.ts, same modes in scripts/pair.py): how users sign
  // in, and which app gets it. The description only suggests the first choice.
  const mode: LoginMode = method || "none";
  const pairLogin: PairLogin = {
    customer: mode !== "none" && (loginApps === "customer" || loginApps === "both") ? mode : "none",
    admin: mode !== "none" && (loginApps === "admin" || loginApps === "both") ? mode : "none",
  };
  const emails = admins.split(/[,\s]+/).filter(Boolean);
  const emailsValid = emails.length > 0 && emails.every((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e));
  const pinValid = /^[A-Za-z0-9]{4,12}$/.test(pin.trim());
  // The admin app needs admin emails when its sign-in uses an email, else the admin PIN (anyone could install it).
  const adminByEmail = usesEmail(pairLogin.admin);
  const loginReady = !!method && (mode === "none" || !!loginApps) && (adminByEmail ? emailsValid : pinValid);
  const canSubmit =
    !!ready?.supabase && (!usePush || ready.firebase) && baseValid && !taken && description.trim().length > 20;

  useAutoSave(
    "pair",
    {
      base, lang, description, admins, loginApps, method, customerName, adminName, push, owner, dbRef, spec,
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
          admins: adminByEmail ? emails.join(",") : "-",
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
      // Admin app without admin emails: it opens with the admin PIN (anyone could install it).
      // With admin emails, a secret random PIN: only those emails are admins (nobody else can claim it).
      const secretPin = Array.from({ length: 12 }, () => "abcdefghjkmnpqrstuvwxyz23456789"[Math.floor(Math.random() * 31)]).join("");
      await setAdminPin(clean.replace(/[^a-z0-9_]/g, "_"), dbRef, adminByEmail ? secretPin : pin.trim());
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
    `تطبيق الإدارة: ${LOGIN_LABELS[pairLogin.admin]}${!adminByEmail ? " (يفتح برمز الإدارة)" : ""}.`;
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
            <Text style={styles.subtitle}>زبون + إدارة · Supabase · تسجيل دخول تختاره · إشعارات</Text>
          </View>
          <IconButton icon="close" label="إغلاق" onPress={() => navigation.goBack()} />
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        {!owner && (phase === "form" || phase === "understand" || phase === "design") ? (
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
              maxLength={12000}
              counter
            />
            {refPic ? (
              <View style={styles.refRow}>
                <Image source={{ uri: refPic.uri }} style={styles.refThumb} />
                <View style={{ flex: 1 }}>
                  <Text style={styles.refTitle}>صورة مرجعية مرفقة</Text>
                  <Text style={styles.refHint}>الذكاء بيستلهم شكلها في تصميم التطبيقين.</Text>
                </View>
                <Pressable onPress={() => setRefPic(null)} hitSlop={10} style={{ padding: space.xs }}>
                  <Ionicons name="close" size={18} color={colors.text} />
                </Pressable>
              </View>
            ) : (
              <Button title="أرفق صورة مرجعية (اختياري)" icon="image-outline" variant="secondary" onPress={pickReferenceImage} />
            )}
            <View style={styles.chips}>
              {EXAMPLES.map((e) => (
                <Chip key={e.label} label={e.label} selected={description === e.text} onPress={() => setDescription(e.text)} />
              ))}
            </View>

            <Text style={styles.namesHint}>
              تسجيل الدخول: بعد «افهم فكرتي» بتختار الطريقة (بالهاتف، أو بالهاتف والبريد ورمز تأكيد، أو بالبريد) ولأي تطبيق.
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
            onPress={() => {
              if (!method) setMethod(suggestedChoice(description));
              setLoginSheet(true);
            }}
            disabled={!canSubmit}
            style={{ flex: 1 }}
          />
        </View>
      ) : !owner ? null : phase === "understand" ? (
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
        <Text style={styles.sheetText}>المستخدم يسجّل حسابه جوه التطبيق بأي طريقة؟</Text>
        <View style={{ gap: space.sm, marginBottom: space.md }}>
          {LOGIN_CHOICES.map((m) => (
            <Pressable
              key={m}
              onPress={() => setMethod(m)}
              accessibilityRole="radio"
              accessibilityState={{ selected: method === m }}
              style={[styles.choice, method === m && styles.choiceOn]}
            >
              <Ionicons
                name={method === m ? "radio-button-on" : "radio-button-off"}
                size={20}
                color={method === m ? colors.primary : colors.textMuted}
              />
              <Text style={styles.choiceText}>{LOGIN_LABELS[m]}</Text>
            </Pressable>
          ))}
        </View>
        {method && method !== "none" ? (
          <>
            <Text style={styles.sheetText}>لأي تطبيق؟</Text>
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
        ) : null}
        {!method ? null : adminByEmail ? (
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
            helper={
              pairLogin.admin === "none"
                ? "تطبيق الإدارة بدون تسجيل دخول، فبيطلب الرمز ده مرة واحدة على كل جهاز عشان ما يدخل الإدارة غيرك."
                : "بعد ما يسجّل حسابه في تطبيق الإدارة، بيطلب الرمز ده مرة واحدة عشان يصير مدير. ما تديه لأي زول."
            }
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
  choice: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    padding: space.md,
    borderRadius: radius.field,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surfaceAlt,
  },
  choiceOn: { borderColor: colors.primary },
  choiceText: { ...type.body, color: colors.text, textAlign: "right", flex: 1 },
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
  refRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.md, backgroundColor: colors.surface, borderRadius: radius.card, padding: space.md, marginTop: space.sm },
  refThumb: { width: 54, height: 54, borderRadius: radius.field, backgroundColor: colors.bg },
  refTitle: { ...type.body, color: colors.text, textAlign: "right", fontWeight: "600" },
  refHint: { ...type.hint, color: colors.textMuted, textAlign: "right" },
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
