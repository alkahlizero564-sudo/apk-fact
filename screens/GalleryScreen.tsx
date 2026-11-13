// Design gallery: browse thousands of ready designs (category × style × palette). Tap one to start your app from
// it — the AI builds a complete app on that category and follows that exact style and palette. Each tile is a
// lightweight mock drawn from the palette/style (instant, offline); an eye button opens a real AI preview.
import React, { useMemo, useState } from "react";
import { View, Text, StyleSheet, FlatList, Pressable, TextInput, ScrollView } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { colors, space, radius, type } from "../theme";
import { Screen } from "../components/ui";
import { buildGallery, galleryTemplate, CATEGORIES, GALLERY_COUNT, GalleryItem } from "../services/gallery";
import { setGalleryPick, GALLERY_PICK } from "../services/galleryPick";
import type { RootScreenProps } from "../navigation";

export default function GalleryScreen({ navigation }: RootScreenProps<"Gallery">) {
  const [category, setCategory] = useState("all");
  const [query, setQuery] = useState("");
  const data = useMemo(() => buildGallery({ category, query }), [category, query]);

  function start(item: GalleryItem) {
    setGalleryPick(galleryTemplate(item));
    navigation.navigate("Create", { templateId: GALLERY_PICK });
  }
  function preview(item: GalleryItem) {
    const t = galleryTemplate(item);
    navigation.navigate("InstantPreview", { lang: item.lang, description: t.description, title: item.cat.title });
  }

  const chips = [{ key: "all", title: "الكل" }, ...CATEGORIES.map((c) => ({ key: c.key, title: c.title }))];

  return (
    <Screen title="معرض التصاميم" subtitle={`${GALLERY_COUNT.toLocaleString("ar-EG")} تصميم جاهز — اختر وابدأ`} scroll={false} onBack={() => navigation.goBack()}>
      <View style={styles.searchRow}>
        <Ionicons name="search" size={18} color={colors.textMuted} />
        <TextInput
          style={styles.search}
          value={query}
          onChangeText={setQuery}
          placeholder="ابحث: مطعم، أزرق، فاخر…"
          placeholderTextColor={colors.textMuted}
          textAlign="right"
        />
        {query ? (
          <Pressable onPress={() => setQuery("")} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={colors.textMuted} />
          </Pressable>
        ) : null}
      </View>

      <View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
          {chips.map((c) => (
            <Pressable key={c.key} onPress={() => setCategory(c.key)} style={[styles.chip, category === c.key && styles.chipOn]}>
              <Text style={[styles.chipText, category === c.key && styles.chipTextOn]}>{c.title}</Text>
            </Pressable>
          ))}
        </ScrollView>
      </View>

      <FlatList
        data={data}
        keyExtractor={(it) => it.id}
        numColumns={2}
        columnWrapperStyle={{ gap: space.md, paddingHorizontal: space.lg }}
        contentContainerStyle={{ gap: space.md, paddingVertical: space.md, paddingBottom: space.xxl }}
        initialNumToRender={8}
        windowSize={7}
        removeClippedSubviews
        keyboardShouldPersistTaps="handled"
        ListEmptyComponent={<Text style={styles.empty}>لا نتائج — جرّب كلمة أخرى</Text>}
        renderItem={({ item }) => <Tile item={item} onStart={() => start(item)} onPreview={() => preview(item)} />}
      />
    </Screen>
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
      <View style={[styles.mock, { backgroundColor: p.bg, borderRadius: s.radius }]}>
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
          <Text style={styles.tileTitle} numberOfLines={1}>{item.cat.title}</Text>
          <Text style={styles.tileSub} numberOfLines={1}>{item.style.title} · {item.palette.name}</Text>
        </View>
        <Pressable onPress={onPreview} hitSlop={8} style={styles.eye}>
          <Ionicons name="eye-outline" size={18} color={colors.textMuted} />
        </Pressable>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  searchRow: { flexDirection: "row-reverse", alignItems: "center", gap: space.sm, marginHorizontal: space.lg, marginTop: space.sm, paddingHorizontal: space.md, height: 44, backgroundColor: colors.surface, borderRadius: radius.field, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border },
  search: { flex: 1, color: colors.text, ...type.body },
  chips: { flexDirection: "row-reverse", gap: space.sm, paddingHorizontal: space.lg, paddingVertical: space.sm },
  chip: { paddingHorizontal: space.md, paddingVertical: 7, borderRadius: radius.pill, backgroundColor: colors.surface, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border },
  chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
  chipText: { ...type.hint, color: colors.textMuted, fontWeight: "700" },
  chipTextOn: { color: colors.primaryText },
  tile: { flex: 1, backgroundColor: colors.surface, borderRadius: radius.card, padding: space.sm, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border },
  mock: { height: 150, padding: 12, gap: 8, overflow: "hidden" },
  mockTopRow: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: 2 },
  mockBar: { height: 12, width: "45%", borderRadius: 6 },
  mockDot: { width: 16, height: 16, borderRadius: 8 },
  mockCard: { padding: 9, gap: 6 },
  mockLine: { height: 6, borderRadius: 3 },
  mockBtn: { height: 22, width: "55%", marginTop: 2 },
  tileFooter: { flexDirection: "row-reverse", alignItems: "center", gap: space.xs, paddingHorizontal: 4, paddingTop: space.sm },
  tileTitle: { ...type.body, color: colors.text, fontWeight: "800", textAlign: "right" },
  tileSub: { ...type.hint, color: colors.textMuted, textAlign: "right" },
  eye: { width: 30, height: 30, alignItems: "center", justifyContent: "center" },
  empty: { ...type.body, color: colors.textMuted, textAlign: "center", marginTop: space.xxl },
});
