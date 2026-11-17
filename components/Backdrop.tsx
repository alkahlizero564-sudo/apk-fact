// The glass theme's backdrop: a deep diagonal gradient with three soft colored glows. Drawn once behind every screen
// (App.tsx wraps each screen), so screens keep a transparent root and their glass cards show it through.
// React Native has no blur filter, so each glow is many faint stacked circles fading outwards.
import React from "react";
import { View, StyleSheet, useWindowDimensions } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { backdrop } from "../theme";

// Many faint stacked circles: each adds ~2.7% of the color, so the center reaches ~32% and the edge fades out
// smoothly (a few large hard-edged rings would show visible bands).
const RINGS = 14;
function Glow({ color, size, top, left }: { color: string; size: number; top: number; left: number }) {
  return (
    <View pointerEvents="none" style={{ position: "absolute", top, left, width: size, height: size }}>
      {Array.from({ length: RINGS }, (_, i) => {
        const d = size * (1 - i / RINGS);
        return (
          <View
            key={i}
            style={{
              position: "absolute",
              top: (size - d) / 2,
              left: (size - d) / 2,
              width: d,
              height: d,
              borderRadius: d / 2,
              backgroundColor: color + "07",
            }}
          />
        );
      })}
    </View>
  );
}

export default function Backdrop() {
  const { width: w, height: h } = useWindowDimensions();
  const [violet, cyan, pink] = backdrop.glows;
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <LinearGradient colors={backdrop.colors as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={StyleSheet.absoluteFill} />
      <Glow color={violet} size={w * 1.15} top={-w * 0.55} left={w * 0.25} />
      <Glow color={cyan} size={w * 0.95} top={h * 0.38} left={-w * 0.55} />
      <Glow color={pink} size={w * 0.9} top={h * 0.78} left={w * 0.45} />
    </View>
  );
}
