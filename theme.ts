// "Glass Gradient" theme. Every screen reads its colors from here.
// Screens are transparent (colors.bg) and sit on one gradient backdrop with colored glows (components/Backdrop.tsx);
// cards, fields, chips and bars are frosted glass: a translucent white fill with a thin light border.
export const colors = {
  base: "#070A1F", // opaque deep navy under every screen (and wherever something must not be see-through)
  bg: "transparent", // screen roots: the glass backdrop shows through
  surface: "rgba(255,255,255,0.07)",
  surfaceAlt: "rgba(255,255,255,0.12)",
  field: "rgba(255,255,255,0.06)",
  border: "rgba(255,255,255,0.14)",
  text: "#F4F6FF",
  textMuted: "#9AA3CF",
  primary: "#8B5CF6",
  primaryPressed: "#7C3AED",
  primarySoft: "rgba(139,92,246,0.20)",
  primaryText: "#FFFFFF",
  accent: "#22D3EE",
  okBg: "rgba(52,211,153,0.14)",
  okText: "#34D399",
  errorBg: "rgba(248,113,113,0.14)",
  errorText: "#FCA5A5",
  infoBg: "rgba(96,165,250,0.12)",
  infoBorder: "rgba(96,165,250,0.35)",
  infoText: "#A5C8FF",
  warnText: "#FCD34D",

  // Glass kit
  glass: "rgba(255,255,255,0.07)", // cards, rows, fields
  glassStrong: "rgba(255,255,255,0.13)", // secondary buttons, pressed states, raised chips
  glassBorder: "rgba(255,255,255,0.14)", // hairlines and card edges
  glassBorderStrong: "rgba(255,255,255,0.28)", // focused / emphasized edges
  glassBar: "rgba(10,13,38,0.88)", // sticky bars and sheets: glass, but opaque enough to read over scrolling content
  softText: "#D5DAF7",
  faint: "#6F78A8",
  glow: "#8B5CF6", // shadow color of glowing primary elements
};

// Brand gradient: primary buttons, the new-app button, active tab, hero.
export const gradient = ["#8B5CF6", "#6366F1", "#22D3EE"] as const;

// The screen backdrop: a deep gradient with three soft colored glows (components/Backdrop.tsx).
export const backdrop = {
  colors: ["#0D1240", "#070A1F", "#1A0B33"] as const,
  glows: ["#8B5CF6", "#22D3EE", "#EC4899"] as const,
};

// Brand color of each code language, used for its badge and picker card.
export const langColors = {
  html: "#FB7A45",
  react: "#61DAFB",
  flutter: "#5AB2FF",
  python: "#FFD43B",
  kotlin: "#B794FF",
};

export const space = { xs: 4, sm: 8, md: 12, lg: 18, xl: 26, xxl: 44 };

export const radius = { field: 18, button: 999, card: 26, pill: 999 };

export const type = {
  hero: { fontSize: 32, fontWeight: "800" as const, letterSpacing: 0.2 },
  screenTitle: { fontSize: 24, fontWeight: "800" as const },
  sectionTitle: { fontSize: 18, fontWeight: "800" as const },
  label: { fontSize: 14, fontWeight: "700" as const },
  body: { fontSize: 15, lineHeight: 23 },
  hint: { fontSize: 13, lineHeight: 20 },
};
