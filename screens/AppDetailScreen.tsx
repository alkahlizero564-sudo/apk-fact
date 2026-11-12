import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Alert, Image, Linking, Share } from "react-native";
import * as ImagePicker from "expo-image-picker";
import {
  Screen,
  Card,
  Section,
  ListRow,
  Button,
  Sheet,
  Field,
  Chip,
  Timeline,
  Banner,
  useSteps,
} from "../components/ui";
import { AppAvatar, LANG_ICONS, LangBadge } from "../components/appVisuals";
import {
  generateApp,
  makeAiPreview,
  uploadCode,
  uploadIcon,
  getDisplayName,
  setDisplayName,
  cleanLabel,
  buildAndInstall,
  buildForStore,
  publishLive,
  getPackageId,
  getClient,
  setPackageId,
  validPackageId,
  deleteApp,
  listApps,
  AppInfo,
  Report,
} from "../services/appActions";
import { linkAppsViaSupabase } from "../services/link";
import { confirmPermissions } from "../services/permissionPrompt";
import { saveToVault, vaultStatus, listVaultApps, VaultApp } from "../services/vault";
import { LANGS } from "../services/langs";
import { publishedVersion, PublishedVersion, pairInfo, PairInfo } from "../services/updates";
import { listAdmins, addAdmin, removeAdmin, AdminAccount, setAdminPin, adminMode, openAdminMode, AdminMode } from "../services/pair";
import { colors, langColors, space, radius, type } from "../theme";
import type { RootScreenProps } from "../navigation";

type Op = "edit" | "aiPreview" | "paste" | "build" | "store" | "live";

const EDIT_IDEAS = [
  "غيّر الألوان لدرجات أهدأ",
  "أضف وضع ليلي",
  "حسّن الشاشة الرئيسية",
  "أضف شاشة إعدادات",
  "كبّر الخطوط والأزرار",
  "أضف أنيميشن خفيف",
];

export default function AppDetailScreen({ navigation, route }: RootScreenProps<"AppDetail">) {
  const { name, lang } = route.params;
  const info = LANGS[lang];

  const [sheet, setSheet] = useState<null | "edit" | "paste" | "link" | "progress" | "vault" | "label" | "admins" | "pkg">(null);
  const [pair, setPair] = useState<PairInfo | null>(null);
  const [admins, setAdmins] = useState<AdminAccount[] | null>(null);
  const [adminEmail, setAdminEmail] = useState("");
  const [adminBusy, setAdminBusy] = useState(false);
  const [adminMsg, setAdminMsg] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const [mode, setMode] = useState<AdminMode | null>(null);
  const [pin, setPin] = useState("");
  const [label, setLabel] = useState("");
  const [labelDraft, setLabelDraft] = useState("");
  const [labelBusy, setLabelBusy] = useState(false);
  const [pkg, setPkg] = useState<{ id: string; custom: boolean } | null>(null);
  const [client, setClientName] = useState("");
  const [pkgDraft, setPkgDraft] = useState("");
  const [pkgBusy, setPkgBusy] = useState(false);
  const [aabUrl, setAabUrl] = useState("");
  const [liveUrl, setLiveUrl] = useState("");
  const [op, setOp] = useState<Op | null>(null);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const [editText, setEditText] = useState("");
  const [pasteText, setPasteText] = useState("");
  const [iconUri, setIconUri] = useState<string | null>(null);
  const [iconBusy, setIconBusy] = useState(false);
  const [others, setOthers] = useState<AppInfo[]>([]);
  const [linkTo, setLinkTo] = useState("");
  const [linkLog, setLinkLog] = useState<string[]>([]);
  const [linking, setLinking] = useState(false);
  const [published, setPublished] = useState<PublishedVersion | null>(null);
  const [vault, setVault] = useState<{ ready: boolean; saved?: VaultApp } | null>(null);
  const [vaultNotes, setVaultNotes] = useState("");
  const [vaultBusy, setVaultBusy] = useState(false);
  const [vaultResult, setVaultResult] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const [vaultSteps, vaultReport, vaultReset] = useSteps([
    ["send", "طلب الحفظ"],
    ["save", "حفظ الكود والتفاصيل ومفتاح التوقيع في المستودع الخاص"],
  ]);

  const [genSteps, genReport, genReset] = useSteps([
    ["send", "إرسال طلب التعديل"],
    ["ai", "الذكاء الاصطناعي يعدّل ويفحص الأخطاء ويصلحها"],
    ["save", "حفظ التعديل"],
  ]);
  const [prevSteps, prevReport, prevReset] = useSteps([
    ["upload", "رفع الكود"],
    ["send", "طلب المعاينة"],
    ["ai", "الذكاء الاصطناعي يجهّز المعاينة"],
  ]);
  const [buildSteps, buildReport, buildReset] = useSteps([
    ["start", "تجهيز البناء"],
    ["build", "البناء على GitHub (مع إصلاح الأخطاء تلقائياً)"],
    ["download", "تنزيل الـ APK"],
    ["install", "فتح شاشة التثبيت"],
  ]);
  const [storeSteps, storeReport, storeReset] = useSteps([
    ["start", "تجهيز البناء"],
    ["build", "بناء نسخة Google Play وتوقيعها بمفتاح التطبيق الدائم"],
    ["file", "ملف Google Play (AAB)"],
  ]);
  const [liveSteps, liveReport, liveReset] = useSteps([
    ["send", "طلب نشر الرابط"],
    ["ai", "النشر على GitHub Pages"],
  ]);

  async function loadVault() {
    try {
      const st = await vaultStatus();
      if (!st.ready || !st.repo) return setVault({ ready: false });
      const apps = await listVaultApps(st.repo);
      setVault({ ready: true, saved: apps.find((a) => a.name === name) });
    } catch {
      setVault({ ready: false });
    }
  }

  useEffect(() => {
    loadVault();
    getDisplayName(name).then(setLabel);
    getPackageId(name, lang).then(setPkg);
    getClient(name).then(setClientName);
    pairInfo(name).then(setPair);
  }, [name]);

  async function openAdmins() {
    if (!pair) return;
    setSheet("admins");
    setAdminMsg(null);
    setAdmins(null);
    try {
      setAdmins(await listAdmins(pair.prefix, pair.ref));
      setMode(await adminMode(pair.prefix, pair.ref));
    } catch (e: any) {
      setAdmins([]);
      setAdminMsg({ kind: "error", text: e.message });
    }
  }

  async function savePin() {
    if (!pair) return;
    setAdminBusy(true);
    setAdminMsg(null);
    try {
      await setAdminPin(pair.prefix, pair.ref, pin.trim());
      setPin("");
      setMode("pin");
      setAdminMsg({
        kind: "ok",
        text: "اتحفظ رمز الإدارة. الدخول للإدارة بقى يحتاج الرمز في شاشة «دخول الإدارة».",
      });
    } catch (e: any) {
      setAdminMsg({ kind: "error", text: e.message });
    } finally {
      setAdminBusy(false);
    }
  }

  async function makeOpen() {
    if (!pair) return;
    setAdminBusy(true);
    setAdminMsg(null);
    try {
      await openAdminMode(pair.prefix, pair.ref);
      setMode("open");
      setAdminMsg({ kind: "ok", text: "تمام: أي حد يسجّل في تطبيق الإدارة بيكون مدير، وفي تطبيق الزبون بيكون زبون." });
    } catch (e: any) {
      setAdminMsg({ kind: "error", text: e.message });
    } finally {
      setAdminBusy(false);
    }
  }

  async function changeAdmin(kind: "add" | "remove", email: string) {
    if (!pair) return;
    setAdminBusy(true);
    setAdminMsg(null);
    try {
      if (kind === "add") await addAdmin(pair.prefix, pair.ref, email);
      else await removeAdmin(pair.prefix, pair.ref, email);
      setAdmins(await listAdmins(pair.prefix, pair.ref));
      if (kind === "add") setAdminEmail("");
      setAdminMsg({
        kind: "ok",
        text:
          kind === "add"
            ? `${email.trim()} بقى حساب إدارة. يسجّل خروج من تطبيق الإدارة ويدخل تاني بنفس البريد.`
            : `${email} ما عاد حساب إدارة.`,
      });
    } catch (e: any) {
      setAdminMsg({ kind: "error", text: e.message });
    } finally {
      setAdminBusy(false);
    }
  }

  async function saveLabel() {
    setLabelBusy(true);
    try {
      await setDisplayName(name, labelDraft);
      setLabel(cleanLabel(labelDraft));
      setSheet(null);
      Alert.alert("تم", "الاسم الجديد بيظهر تحت الأيقونة من البناء الجاي (ابنِ وثبّت، أو انشر تحديث).");
    } catch (e: any) {
      Alert.alert("ما قدرنا نحفظ الاسم", e.message);
    } finally {
      setLabelBusy(false);
    }
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", () => {
      publishedVersion(name).then(setPublished);
    });
    return unsub;
  }, [navigation, name]);

  async function doVaultSave() {
    setVaultBusy(true);
    setVaultResult(null);
    vaultReset();
    try {
      await saveToVault(name, vaultNotes.trim(), vaultReport);
      setVaultResult({ kind: "ok", text: "اتحفظ التطبيق بكل تفاصيله ومفتاح توقيعه في الخزنة الخاصة." });
      setVaultNotes("");
      loadVault();
    } catch (e: any) {
      setVaultResult({ kind: "error", text: e.message });
    } finally {
      setVaultBusy(false);
    }
  }

  useEffect(() => {
    listApps()
      .then((a) => setOthers(a.filter((x) => x.name !== name && x.lang === "html")))
      .catch(() => {});
  }, [name]);

  async function runOp(kind: Op, fn: (report: Report) => Promise<unknown>, done: string) {
    setOp(kind);
    setResult(null);
    setRunning(true);
    setSheet("progress");
    try {
      await fn(
        kind === "build" ? buildReport : kind === "store" ? storeReport : kind === "edit" ? genReport : kind === "live" ? liveReport : prevReport
      );
      setResult({ kind: "ok", text: done });
    } catch (e: any) {
      setResult({ kind: "error", text: e.message });
    } finally {
      setRunning(false);
    }
  }

  function startEdit() {
    const text = editText.trim();
    if (!text) return;
    genReset();
    runOp("edit", (r) => generateApp({ name, lang, text, kind: "edit" }, r), "اتعدّل التطبيق. افتح المعاينة تشوف التغيير.").then(() =>
      setEditText("")
    );
  }

  function startAiPreview() {
    prevReset();
    prevReport("upload", "done", "الكود موجود");
    runOp("aiPreview", (r) => makeAiPreview(name, lang, r), "المعاينة الجديدة جاهزة.");
  }

  function startPaste() {
    const code = pasteText.trim();
    if (code.length < 20) return;
    prevReset();
    runOp(
      "paste",
      async (r) => {
        await uploadCode(name, lang, code, r);
        if (!info.hasAiPreview) {
          r("send", "done");
          r("ai", "done", "تطبيقات HTML تُعرض كما هي");
        }
      },
      "ارتفع الكود."
    ).then(() => setPasteText(""));
  }

  async function startBuild() {
    // A permission the code uses but the description did not mention: ask the owner first.
    if (!(await confirmPermissions([{ name, lang }]))) return;
    buildReset();
    runOp("build", (r) => buildAndInstall(name, lang, r), "اكتمل. اضغط تثبيت في شاشة أندرويد.");
  }

  async function pickIcon() {
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
      base64: true,
    });
    const asset = res.canceled ? null : res.assets?.[0];
    if (!asset?.base64) return;
    setIconBusy(true);
    try {
      await uploadIcon(name, asset.base64);
      setIconUri(asset.uri);
      Alert.alert("تم", "الأيقونة الجديدة بتظهر في البناء الجاي.");
    } catch (e: any) {
      Alert.alert("ما قدرنا نرفع الأيقونة", e.message);
    } finally {
      setIconBusy(false);
    }
  }

  function confirmDelete() {
    Alert.alert("حذف التطبيق", `متأكد تبغى تحذف "${name}"؟ ما يمكن التراجع.`, [
      { text: "إلغاء", style: "cancel" },
      {
        text: "حذف",
        style: "destructive",
        onPress: async () => {
          try {
            await deleteApp(name);
            navigation.goBack();
          } catch (e: any) {
            Alert.alert("ما قدرنا نحذف", e.message);
          }
        },
      },
    ]);
  }

  async function doLink() {
    if (!linkTo) return;
    setLinking(true);
    setLinkLog([]);
    const add = (s: string) => setLinkLog((p) => [...p, s]);
    try {
      const r = await linkAppsViaSupabase(name, linkTo, add);
      add("✅ اتعاد كتابة التطبيقين وارتفعوا.");
      if (r.tables.length) add(`🗄️ الجداول: ${r.tables.join("، ")}`);
    } catch (e: any) {
      add(`❌ ${e.message}`);
    } finally {
      setLinking(false);
    }
  }

  async function startStore() {
    if (!vault?.ready) {
      Alert.alert("الخزنة الخاصة غير مجهّزة", "ملف Google Play لازم يتوقّع بمفتاح التطبيق الدائم. جهّز الخزنة من الإعدادات الأول.");
      return;
    }
    if (!(await confirmPermissions([{ name, lang }]))) return;
    storeReset();
    setAabUrl("");
    runOp(
      "store",
      async (r) => setAabUrl(await buildForStore(name, lang, r)),
      "ملف AAB جاهز وموقّع بمفتاح التطبيق الدائم. نزّله وارفعه في Google Play Console (إصدار جديد)."
    );
  }

  function startPublishLive() {
    liveReset();
    setLiveUrl("");
    runOp("live", async (r) => setLiveUrl(await publishLive(name, r)), "الرابط الحيّ جاهز. شاركه مع العميل — يفتح التطبيق على أي هاتف بلا تثبيت.");
  }

  async function savePkg() {
    setPkgBusy(true);
    try {
      await setPackageId(name, pkgDraft);
      setPkg({ id: pkgDraft.trim().toLowerCase(), custom: true });
      setSheet(null);
      Alert.alert("تم", "اسم الحزمة الجديد بيتطبّق من البناء الجاي.");
    } catch (e: any) {
      Alert.alert("ما قدرنا نحفظ اسم الحزمة", e.message);
    } finally {
      setPkgBusy(false);
    }
  }

  const progressSteps = op === "build" ? buildSteps : op === "store" ? storeSteps : op === "edit" ? genSteps : op === "live" ? liveSteps : prevSteps;
  const progressTitle =
    op === "build"
      ? "بناء وتثبيت"
      : op === "store"
      ? "ملف Google Play"
      : op === "edit"
      ? "تعديل بالذكاء الاصطناعي"
      : op === "paste"
      ? "رفع الكود"
      : op === "live"
      ? "نشر رابط حيّ"
      : "معاينة جديدة";

  return (
    <Screen title={name} subtitle={info.tools} onBack={() => navigation.goBack()}>
      <Card style={styles.hero}>
        {iconUri ? (
          <Image source={{ uri: iconUri }} style={styles.icon} />
        ) : (
          <AppAvatar name={name} lang={lang} size={76} />
        )}
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={styles.name}>{label || name}</Text>
          <LangBadge lang={lang} />
          {client ? <Text style={styles.client}>للزبون: {client}</Text> : null}
          <Text style={styles.path}>{label ? `${name} · ` : ""}apps/{name}</Text>
        </View>
      </Card>

      <View style={styles.actions}>
        <Button title="معاينة" icon="eye-outline" variant="secondary" onPress={() => navigation.navigate("Preview", { name })} style={{ flex: 1 }} />
        <Button title="ابنِ وثبّت" icon="download-outline" onPress={startBuild} disabled={running} style={{ flex: 1 }} />
      </View>
      <Button
        title="انشر رابطاً حيّاً (للعميل، بلا تثبيت)"
        icon="link-outline"
        variant="secondary"
        onPress={startPublishLive}
        disabled={running}
        style={{ marginTop: space.sm }}
      />
      {result?.kind === "ok" && op === "live" && liveUrl ? (
        <View style={[styles.actions, { marginTop: space.sm }]}>
          <Button title="افتح الرابط" icon="open-outline" onPress={() => Linking.openURL(liveUrl)} style={{ flex: 1 }} />
          <Button title="شارك الرابط" icon="share-social-outline" variant="secondary" onPress={() => Share.share({ message: liveUrl })} style={{ flex: 1 }} />
        </View>
      ) : null}

      <Card style={[styles.list, styles.updateCard]}>
        <ListRow
          icon="cloud-upload-outline"
          tint={colors.accent}
          title="تحديث التطبيق"
          subtitle="غيّر، احذف، أضف بالذكاء الاصطناعي مع معاينة فورية، والتطبيق المثبّت يجيه إشعار بالتحديث"
          value={published ? `v${published.versionName ?? published.version}` : undefined}
          onPress={() => navigation.navigate("Update", { name, lang })}
          last
        />
      </Card>

      <Section title="تطوير">
        <Card style={styles.list}>
          <ListRow
            icon="sparkles-outline"
            tint={colors.accent}
            title="تعديل بالذكاء الاصطناعي"
            subtitle="صف التغيير اللي تبغاه، والكود بيتعدّل ويتفحص"
            onPress={() => setSheet("edit")}
          />
          {info.hasAiPreview ? (
            <ListRow
              icon="color-wand-outline"
              title="معاينة جديدة بالذكاء الاصطناعي"
              subtitle="إعادة توليد المعاينة الحيّة من الكود الحالي"
              onPress={startAiPreview}
            />
          ) : null}
          <ListRow icon="code-slash-outline" title="لصق كود جاهز" subtitle={info.pasteLabel} onPress={() => setSheet("paste")} />
          <ListRow
            icon="text-outline"
            title="اسم التطبيق على الجهاز"
            subtitle={label ? "يظهر تحت أيقونة التطبيق" : "اكتب اسم بالعربي يظهر تحت الأيقونة"}
            value={label || name}
            onPress={() => {
              setLabelDraft(label);
              setSheet("label");
            }}
          />
          <ListRow
            icon="image-outline"
            title={iconBusy ? "بيترفع…" : "أيقونة التطبيق"}
            subtitle="اختيار صورة من المعرض"
            onPress={iconBusy ? undefined : pickIcon}
            last
          />
        </Card>
      </Section>

      <Section title="Google Play">
        <Card style={styles.list}>
          <ListRow
            icon="cube-outline"
            title="اسم الحزمة"
            subtitle={
              pair
                ? "التطبيقين المتصلين مسجّلين بالاسم ده في الإشعارات، فما بيتغيّر"
                : pkg?.custom
                ? "الاسم اللي اخترته. ما بيتغيّر بعد النشر على Google Play"
                : "اسم تلقائي. اختار اسم باسم صاحب التطبيق قبل أول نشر على Google Play"
            }
            value={pkg?.id}
            onPress={
              pair
                ? undefined
                : () => {
                    setPkgDraft(pkg?.custom ? pkg.id : "");
                    setSheet("pkg");
                  }
            }
          />
          <ListRow
            icon="logo-google-playstore"
            tint={colors.accent}
            title="ملف Google Play (AAB)"
            subtitle="نسخة إصدار موقّعة بمفتاح التطبيق الدائم، جاهزة للرفع على Google Play Console"
            onPress={running ? undefined : startStore}
            last
          />
        </Card>
      </Section>

      {lang === "html" ? (
        <Section title="مشروع">
          <Card style={styles.list}>
            <ListRow
              icon="git-merge-outline"
              tint="#34D399"
              title="ربط مع تطبيق آخر"
              subtitle="قاعدة بيانات مشتركة عبر Supabase"
              onPress={() => setSheet("link")}
              last
            />
          </Card>
        </Section>
      ) : null}

      {pair ? (
        <Section title="التطبيقين المتصلين">
          <Card style={styles.list}>
            <ListRow
              icon="shield-checkmark-outline"
              tint={colors.accent}
              title="حسابات الإدارة"
              subtitle="البريد اللي يدخل تطبيق الإدارة. التغيير فوري بدون بناء جديد"
              onPress={openAdmins}
              last
            />
          </Card>
        </Section>
      ) : null}

      <Section title="الخزنة الخاصة">
        <Card style={styles.list}>
          <ListRow
            icon="shield-checkmark-outline"
            tint={vault?.saved ? colors.okText : colors.warnText}
            title="حفظ في الخزنة الخاصة"
            subtitle={
              !vault
                ? "…"
                : !vault.ready
                ? "الخزنة غير مجهّزة. جهّزها من الإعدادات"
                : vault.saved?.savedAt
                ? `محفوظ · ${new Date(vault.saved.savedAt).toLocaleString("ar-EG")}`
                : "الكود والتفاصيل ومفتاح التوقيع الدائم"
            }
            onPress={() => setSheet("vault")}
            last
          />
        </Card>
      </Section>

      <Section title="منطقة الخطر">
        <Card style={styles.list}>
          <ListRow icon="trash-outline" title="حذف التطبيق" subtitle="يحذف كل ملفاته من GitHub" danger onPress={confirmDelete} last />
        </Card>
      </Section>

      <Sheet visible={sheet === "edit"} title="تعديل بالذكاء الاصطناعي" onClose={() => setSheet(null)}>
        <Field
          label="شنو التغيير؟"
          icon="create-outline"
          value={editText}
          onChangeText={setEditText}
          placeholder="مثال: غيّر الألوان للأخضر وأضف زر واتساب في الصفحة الرئيسية"
          multiline
          maxLength={1500}
          counter
        />
        <View style={styles.chips}>
          {EDIT_IDEAS.map((i) => (
            <Chip key={i} label={i} onPress={() => setEditText((t) => `${t.trim()} ${i}.`.trim())} />
          ))}
        </View>
        <Button title="نفّذ التعديل" icon="sparkles" onPress={startEdit} disabled={editText.trim().length < 3} />
      </Sheet>

      <Sheet visible={sheet === "admins"} title="حسابات الإدارة" onClose={() => setSheet(null)}>
        <Text style={styles.sheetText}>
          تحكّم في مين يدخل تطبيق الإدارة كمدير. التغيير فوري في Supabase، بدون بناء جديد.
        </Text>
        {!admins ? (
          <Banner kind="info" text="بنقرأ القائمة…" />
        ) : (
          <Card style={{ padding: 0, overflow: "hidden", marginBottom: space.lg }}>
            {admins.map((a, i) => (
              <ListRow
                key={a.email}
                icon="person-circle-outline"
                title={a.email}
                subtitle={a.signedUp ? "دخل قبل كده" : "لسه ما دخل"}
                chevron={false}
                right={
                  <Button title="إزالة" variant="secondary" onPress={() => changeAdmin("remove", a.email)} disabled={adminBusy} />
                }
                last={i === admins.length - 1}
              />
            ))}
          </Card>
        )}
        <Text style={styles.sheetSubtitle}>مين يكون مدير؟</Text>
        <Banner
          kind={mode === "missing" ? "info" : "ok"}
          text={
            mode === "open"
              ? "الوضع الحالي: أي حد يسجّل في تطبيق الإدارة يكون مدير، وأي حد يسجّل في تطبيق الزبون يكون زبون."
              : mode === "pin"
              ? "الوضع الحالي: الدخول للإدارة يحتاج رمز الإدارة السري."
              : mode === "missing"
              ? "المشروع ده اتعمل قبل الميزة دي: اختار وضع من تحت عشان يتفعّل."
              : "…"
          }
        />
        {mode !== "open" ? (
          <Button
            title="أي حد يسجّل في تطبيق الإدارة يكون مدير"
            icon="people-outline"
            variant="secondary"
            onPress={makeOpen}
            loading={adminBusy}
            style={{ marginTop: space.md }}
          />
        ) : null}
        <Text style={[styles.sheetText, { marginTop: space.lg }]}>
          {mode === "pin"
            ? "تقدر تغيّر رمز الإدارة هنا."
            : "أو حدّد رمز سري (4 إلى 12 حرف إنجليزي أو رقم): وقتها الدخول للإدارة يحتاج الرمز."}
        </Text>
        <Field
          label={mode === "pin" ? "رمز جديد" : "رمز الإدارة (اختياري)"}
          icon="key-outline"
          value={pin}
          onChangeText={setPin}
          placeholder="123456"
          ltr
          secret
          autoCapitalize="none"
          maxLength={12}
        />
        <Button
          title={mode === "pin" ? "غيّر الرمز" : "فعّل رمز الإدارة"}
          icon="key-outline"
          variant="secondary"
          onPress={savePin}
          loading={adminBusy}
          disabled={!/^[A-Za-z0-9]{4,12}$/.test(pin.trim())}
        />
        <Text style={[styles.sheetSubtitle, { marginTop: space.xl }]}>بريد إدارة ثابت (اختياري)</Text>
        <Field
          label="إضافة بريد إدارة"
          icon="mail-outline"
          value={adminEmail}
          onChangeText={setAdminEmail}
          placeholder="name@gmail.com"
          ltr
          autoCapitalize="none"
          keyboardType="email-address"
        />
        <Button title="أضف" icon="add" onPress={() => changeAdmin("add", adminEmail)} loading={adminBusy} disabled={!adminEmail.includes("@")} />
        {adminMsg ? <Banner kind={adminMsg.kind} text={adminMsg.text} /> : null}
      </Sheet>

      <Sheet visible={sheet === "label"} title="اسم التطبيق على الجهاز" onClose={() => setSheet(null)}>
        <Field
          label="الاسم"
          icon="text-outline"
          value={labelDraft}
          onChangeText={setLabelDraft}
          placeholder="مثال: متجر الورد"
          maxLength={40}
          counter
          helper="بيظهر تحت أيقونة التطبيق بعد التثبيت. اسم المجلد والحزمة ما بيتغيروا."
        />
        <Button title="احفظ الاسم" icon="checkmark" onPress={saveLabel} loading={labelBusy} disabled={!cleanLabel(labelDraft)} />
      </Sheet>

      <Sheet visible={sheet === "pkg"} title="اسم الحزمة" onClose={() => setSheet(null)}>
        <Text style={styles.sheetText}>
          ده الاسم اللي Google Play بيعرف بيه التطبيق، والزبون بيشوفه في رابط المتجر. اكتبه بالإنجليزي مفصول بنقاط، زي
          اسم موقع بالعكس: com.اسم_الشركة.اسم_التطبيق
        </Text>
        <Field
          label="اسم الحزمة"
          icon="cube-outline"
          value={pkgDraft}
          onChangeText={setPkgDraft}
          placeholder="com.alwardshop.app"
          ltr
          autoCapitalize="none"
          autoCorrect={false}
          error={pkgDraft.trim() && !validPackageId(pkgDraft.trim().toLowerCase()) ? "حروف إنجليزية صغيرة وأرقام و _ ، جزئين أو أكتر مفصولين بنقطة، وكل جزء يبدأ بحرف" : null}
        />
        {published ? (
          <Banner
            kind="error"
            text="التطبيق ده عنده نسخ مثبّتة. لو غيّرت اسم الحزمة، الجوال بيعتبره تطبيق جديد، والنسخ القديمة ما بيوصلها التحديث."
          />
        ) : null}
        <Banner kind="info" text="بعد ما تنشر التطبيق على Google Play ما تقدر تغيّر اسم الحزمة أبداً." />
        <Button
          title="احفظ اسم الحزمة"
          icon="checkmark"
          onPress={savePkg}
          loading={pkgBusy}
          disabled={!validPackageId(pkgDraft.trim().toLowerCase())}
          style={{ marginTop: space.md }}
        />
      </Sheet>

      <Sheet visible={sheet === "paste"} title="لصق كود جاهز" onClose={() => setSheet(null)}>
        <Field
          label={info.pasteLabel}
          icon="code-slash-outline"
          value={pasteText}
          onChangeText={setPasteText}
          placeholder="الصق الكود هنا"
          multiline
          ltr
          autoCapitalize="none"
          autoCorrect={false}
          style={{ fontFamily: "monospace", fontSize: 12, minHeight: 200 }}
          helper="الكود الحالي بيتبدّل بالكود ده"
        />
        <Button title="ارفع الكود" icon="cloud-upload-outline" onPress={startPaste} disabled={pasteText.trim().length < 20} />
      </Sheet>

      <Sheet visible={sheet === "link"} title="ربط مع تطبيق آخر" onClose={() => setSheet(null)}>
        <Text style={styles.sheetText}>
          بنصمم جداول مشتركة في Supabase ونعيد كتابة التطبيقين عشان يقروا ويكتبوا نفس البيانات. التطبيقين القدام بيتغيروا.
        </Text>
        {others.length === 0 ? (
          <Banner kind="info" text="محتاج تطبيق HTML ثاني عشان تربطه." />
        ) : (
          <View style={styles.chips}>
            {others.map((a) => (
              <Chip
                key={a.name}
                label={a.name}
                icon={LANG_ICONS[a.lang]}
                tint={langColors[a.lang]}
                selected={linkTo === a.name}
                onPress={() => setLinkTo(a.name)}
              />
            ))}
          </View>
        )}
        <Button title="اربط التطبيقين" icon="git-merge-outline" onPress={doLink} loading={linking} disabled={!linkTo} />
        {linkLog.length ? (
          <View style={styles.log}>
            {linkLog.map((l, i) => (
              <Text key={i} style={styles.logLine}>
                {l}
              </Text>
            ))}
          </View>
        ) : null}
      </Sheet>

      <Sheet visible={sheet === "vault"} title="الخزنة الخاصة" onClose={() => setSheet(null)}>
        <Text style={styles.sheetText}>
          بنحفظ في مستودعك الخاص: كود التطبيق كامل، وصفه وكل التعديلات، اسم الحزمة، وبصمة ومفتاح التوقيع الدائم (بيتولّد أول مرة).
        </Text>
        {vault?.saved?.sha256 ? (
          <Card style={{ marginBottom: space.lg, padding: 0, overflow: "hidden" }}>
            <ListRow icon="cube-outline" title="اسم الحزمة" value={vault.saved.packageId} chevron={false} />
            <ListRow icon="finger-print-outline" title="بصمة التوقيع" subtitle={vault.saved.sha256} chevron={false} last />
          </Card>
        ) : null}
        {vault && !vault.ready ? (
          <Banner kind="info" text="جهّز الخزنة مرة واحدة من: الإعدادات > الخزنة الخاصة." />
        ) : (
          <>
            <Field
              label="ملاحظات (اختياري)"
              icon="create-outline"
              value={vaultNotes}
              onChangeText={setVaultNotes}
              placeholder="مثال: النسخة اللي اتسلّمت للعميل"
              multiline
              maxLength={900}
              counter
            />
            <Button title="احفظ الآن" icon="shield-checkmark-outline" onPress={doVaultSave} loading={vaultBusy} />
          </>
        )}
        {vaultBusy || vaultResult ? (
          <Card style={{ marginTop: space.lg }}>
            <Timeline steps={vaultSteps} />
          </Card>
        ) : null}
        {vaultResult ? <Banner kind={vaultResult.kind} text={vaultResult.text} /> : null}
      </Sheet>

      <Sheet visible={sheet === "progress"} title={progressTitle} onClose={() => setSheet(null)}>
        <Timeline steps={progressSteps} />
        {running ? <Banner kind="info" text="تقدر تقفل النافذة، والعملية بتكمل. خلّي التطبيق مفتوح." /> : null}
        {result ? <Banner kind={result.kind} text={result.text} /> : null}
        {result?.kind === "ok" && op === "store" && aabUrl ? (
          <View style={{ flexDirection: "row-reverse", gap: space.sm, marginTop: space.md }}>
            <Button title="نزّل الملف" icon="download-outline" onPress={() => Linking.openURL(aabUrl)} style={{ flex: 1 }} />
            <Button title="شارك الرابط" icon="share-social-outline" variant="secondary" onPress={() => Share.share({ message: aabUrl })} style={{ flex: 1 }} />
          </View>
        ) : null}
        {result?.kind === "ok" && op !== "build" && op !== "store" ? (
          <Button
            title="افتح المعاينة"
            icon="eye-outline"
            variant="secondary"
            onPress={() => {
              setSheet(null);
              navigation.navigate("Preview", { name });
            }}
            style={{ marginTop: space.md }}
          />
        ) : null}
      </Sheet>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { flexDirection: "row-reverse", alignItems: "center", gap: space.lg, marginBottom: space.md },
  icon: { width: 76, height: 76, borderRadius: 22 },
  name: { fontSize: 24, fontWeight: "900", color: colors.text, textAlign: "right" },
  client: { fontSize: 13, color: colors.accent, textAlign: "right", fontWeight: "600" },
  path: { fontSize: 12, color: colors.textMuted, textAlign: "right", fontFamily: "monospace" },
  actions: { flexDirection: "row-reverse", gap: space.md, marginBottom: space.xl },
  list: { padding: 0, overflow: "hidden" },
  updateCard: { marginBottom: space.xl, borderColor: colors.accent + "66" },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginBottom: space.lg },
  sheetSubtitle: { ...type.label, color: colors.text, textAlign: "right", marginBottom: space.sm },
  sheetText: { ...type.body, color: colors.textMuted, textAlign: "right", marginBottom: space.lg },
  log: { marginTop: space.lg, padding: space.md, borderRadius: radius.field, backgroundColor: colors.field, gap: 4 },
  logLine: { fontSize: 13, color: colors.text, textAlign: "right" },
});
