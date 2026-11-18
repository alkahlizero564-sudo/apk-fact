// Design gallery: browse thousands of ready designs (category × style × palette). Tap one to start your app from
// it — the AI builds a complete app on that category and follows that exact style and palette. Each tile is a
// lightweight mock drawn from the palette/style (instant, offline); an eye button opens a real AI preview.
import React, { useMemo, useState } from "react";
import { View, Text, StyleSheet, FlatList, Pressable, TextInput } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "../components/icons";
import { colors, space } from "../theme";
import { IconButton, RtlRow } from "../components/ui";
import { buildGallery, galleryTemplate, galleryPairStart, CATEGORIES, PAIR_CATEGORIES, GALLERY_COUNT, PAIR_GALLERY_COUNT, GalleryItem } from "../services/gallery";
import { setGalleryPick, setGalleryPairPick, GALLERY_PICK } from "../services/galleryPick";
import type { RootScreenProps } from "../navigation";

const CARD = colors.glass;
const SOFT_TEXT = colors.softText;

export default function GalleryScreen({ navigation }: RootScreenProps<"Gallery">) {
  const insets = useSafeAreaInsets();
  const [pair, setPair] = useState(false); // false: one app · true: connected pair (customer + admin)
  const [category, setCategory] = useState("all");
  const [query, setQuery] = useState("");
  const data = useMemo(() => buildGallery({ category, query, pair }), [category, query, pair]);

  function start(item: GalleryItem) {
    if (item.pair) {
      setGalleryPairPick(galleryPairStart(item));
      navigation.navigate("Pair");
      return;
    }
    setGalleryPick(galleryTemplate(item));
    navigation.navigate("Create", { templateId: GALLERY_PICK });
  }
  function preview(item: GalleryItem) {
    // For a pair the preview shows the customer app in that style.
    const description = item.pair ? galleryPairStart(item).description : galleryTemplate(item).description;
    navigation.navigate("InstantPreview", { lang: item.pair ? "html" : item.lang, description, title: item.cat.title });
  }
  function switchMode(p: boolean) {
    setPair(p);
    setCategory("all");
  }

  const chips = [{ key: "all", title: "الكل" }, ...(pair ? PAIR_CATEGORIES : CATEGORIES).map((c) => ({ key: c.key, title: c.title }))];
  const count = pair ? PAIR_GALLERY_COUNT : GALLERY_COUNT;

  const header = (
    <View>
      <View style={styles.topBar}>
        <IconButton icon="arrow-forward" label="رجوع" onPress={() => navigation.goBack()} />
      </View>
      <Text style={styles.title}>معرض التصاميم</Text>
      <Text style={styles.subtitle}>
        {count.toLocaleString("ar-EG")} {pair ? "تصميم لتطبيقين متصلين" : "تصميم جاهز"}، اختر وابدأ
      </Text>

      <View style={styles.modes}>
        <Pressable onPress={() => switchMode(false)} style={[styles.mode, !pair && styles.modeOn]}>
          <Ionicons name="phone-portrait-outline" size={16} color={!pair ? colors.primaryText : colors.textMuted} />
          <Text style={[styles.modeText, !pair && styles.modeTextOn]}>تطبيق واحد</Text>
        </Pressable>
        <Pressable onPress={() => switchMode(true)} style={[styles.mode, pair && styles.modeOn]}>
          <Ionicons name="git-merge-outline" size={16} color={pair ? colors.primaryText : colors.textMuted} />
          <Text style={[styles.modeText, pair && styles.modeTextOn]}>زبون + إدارة</Text>
        </Pressable>
      </View>

      <View style={styles.searchRow}>
        <Ionicons name="search" size={18} color={colors.faint} />
        <TextInput
          style={styles.search}
          value={query}
          onChangeText={setQuery}
          placeholder="ابحث: مطعم، أزرق، فاخر…"
          placeholderTextColor={colors.faint}
          textAlign="right"
        />
        {query ? (
          <Pressable onPress={() => setQuery("")} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={colors.faint} />
          </Pressable>
        ) : null}
      </View>

      <RtlRow contentContainerStyle={styles.chips}>
        {chips.map((c) => (
          <Pressable key={c.key} onPress={() => setCategory(c.key)} style={[styles.chip, category === c.key && styles.chipOn]}>
            <Text style={[styles.chipText, category === c.key && styles.chipTextOn]}>{c.title}</Text>
          </Pressable>
        ))}
      </RtlRow>
    </View>
  );

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <FlatList
        data={data}
        keyExtractor={(it) => it.id}
        numColumns={2}
        ListHeaderComponent={header}
        columnWrapperStyle={{ gap: space.md }}
        contentContainerStyle={{ gap: space.md, paddingTop: insets.top + space.md, paddingHorizontal: space.lg, paddingBottom: 60 }}
        initialNumToRender={8}
        windowSize={7}
        removeClippedSubviews
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        ListEmptyComponent={<Text style={styles.empty}>لا نتائج، جرّب كلمة أخرى</Text>}
        renderItem={({ item }) => <Tile item={item} onStart={() => start(item)} onPreview={() => preview(item)} />}
      />
    </View>
  );
}

function Tile({ item, onStart, onPreview }: { item: GalleryItem; onStart: () => void; onPreview: () => void }) {
  const p = item.palette;
  const s = item.style;
  const cardR = Math.max(6, s.radius * 0.6);
  const border = s.border ? { borderWidth: 1, borderColor: p.muted + "55" } : null;
  return (
    <Pressable onPress={onStart} style={({ pressed }) => [styles.tile, pressed && { transform: [{ scale: 0.98 }] }]}>
      {/* Mock preview drawn from the palette + style */}
      <View style={[styles.mock, { backgroundColor: p.bg, borderRadius: Math.min(s.radius, 22) }]}>
        <View style={styles.mockTopRow}>
          <View style={[styles.mockBar, { backgroundColor: p.primary }]} />
          <View style={[styles.mockDot, { backgroundColor: p.accent }]} />
        </View>
        <View style={[styles.mockCard, { backgroundColor: p.surface, borderRadius: cardR }, border]}>
          <View style={[styles.mockLine, { backgroundColor: p.primary, width: "55%" }]} />
          <View style={[styles.mockLine, { backgroundColor: p.muted + "88", width: "80%" }]} />
          <View style={[styles.mockLine, { backgroundColor: p.muted + "55", width: "65%" }]} />
        </View>
        <View style={[styles.mockCard, { backgroundColor: p.surface, borderRadius: cardR }, border]}>
          <View style={[styles.mockLine, { backgroundColor: p.muted + "88", width: "70%" }]} />
          <View style={[styles.mockLine, { backgroundColor: p.muted + "55", width: "45%" }]} />
        </View>
        <View style={[styles.mockBtn, { backgroundColor: p.primary, borderRadius: Math.min(cardR, 14) }]} />
      </View>

      <View style={styles.tileFooter}>
        <View style={{ flex: 1 }}>
          <Text style={styles.tileTitle} numberOfLines={1}>
            {item.cat.title}
          </Text>
          <Text style={styles.tileSub} numberOfLines={1}>
            {item.pair ? "زبون + إدارة · " : ""}
            {item.style.title} · {item.palette.name}
          </Text>
        </View>
        <Pressable onPress={onPreview} hitSlop={8} style={styles.eye}>
          <Ionicons name="eye-outline" size={17} color={SOFT_TEXT} />
        </Pressable>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  topBar: { flexDirection: "row-reverse", marginBottom: space.md },
  title: { color: colors.text, fontSize: 32, fontWeight: "700", textAlign: "right" },
  subtitle: { color: colors.textMuted, fontSize: 14, textAlign: "right", marginTop: 4, marginBottom: space.lg },

  modes: { flexDirection: "row-reverse", gap: space.sm, backgroundColor: CARD, borderRadius: 999, padding: 4 },
  mode: {
    flex: 1,
    flexDirection: "row-reverse",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    height: 42,
    borderRadius: 999,
  },
  modeOn: { backgroundColor: colors.primary },
  modeText: { color: colors.textMuted, fontSize: 13, fontWeight: "600" },
  modeTextOn: { color: colors.primaryText, fontWeight: "700" },

  searchRow: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.sm,
    marginTop: space.md,
    paddingHorizontal: space.lg,
    height: 52,
    backgroundColor: CARD,
    borderRadius: 999,
  },
  search: { flex: 1, color: colors.text, fontSize: 15, paddingVertical: 0 },

  chips: { flexDirection: "row-reverse", gap: space.sm, paddingVertical: space.lg },
  chip: { paddingHorizontal: 18, paddingVertical: 9, borderRadius: 999, backgroundColor: CARD },
  chipOn: { backgroundColor: colors.primary },
  chipText: { color: SOFT_TEXT, fontSize: 13, fontWeight: "600" },
  chipTextOn: { color: colors.primaryText, fontWeight: "700" },

  tile: { flex: 1, backgroundColor: CARD, borderRadius: 24, padding: space.sm },
  mock: { height: 150, padding: 12, gap: 8, overflow: "hidden" },
  mockTopRow: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: 2 },
  mockBar: { height: 12, width: "45%", borderRadius: 6 },
  mockDot: { width: 16, height: 16, borderRadius: 8 },
  mockCard: { padding: 9, gap: 6 },
  mockLine: { height: 6, borderRadius: 3 },
  mockBtn: { height: 22, width: "55%", marginTop: 2 },
  tileFooter: { flexDirection: "row-reverse", alignItems: "center", gap: space.xs, paddingHorizontal: 6, paddingTop: space.sm, paddingBottom: 2 },
  tileTitle: { color: colors.text, fontSize: 14, fontWeight: "700", textAlign: "right" },
  tileSub: { color: colors.faint, fontSize: 12, textAlign: "right", marginTop: 2 },
  eye: { width: 32, height: 32, borderRadius: 16, alignItems: "center", justifyContent: "center", backgroundColor: colors.glassStrong },
  empty: { color: colors.textMuted, fontSize: 15, textAlign: "center", marginTop: space.xxl },
});
