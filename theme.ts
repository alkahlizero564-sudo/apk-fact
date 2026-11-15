// "Midnight Black" theme. Every screen reads its colors from here.
export const colors = {
  bg: "#000000",
  surface: "#0C0C0F",
  surfaceAlt: "#151519",
  field: "#08080A",
  border: "#1F1F26",
  text: "#F5F5F7",
  textMuted: "#8A8A94",
  primary: "#7C5CFF",
  primaryPressed: "#6747F0",
  primarySoft: "#17142E",
  primaryText: "#FFFFFF",
  accent: "#2DD4BF",
  okBg: "#0A1F18",
  okText: "#4ADE80",
  errorBg: "#2A0F12",
  errorText: "#F87171",
  infoBg: "#0F1226",
  infoBorder: "#262B52",
  infoText: "#A9B6FF",
  warnText: "#FBBF24",
};

// Brand gradient for primary buttons.
export const gradient = ["#7C5CFF", "#3B82F6"] as const;

// Brand color of each code language, used for its badge and picker card.
export const langColors = {
  html: "#F06529",
  react: "#61DAFB",
  flutter: "#42A5F5",
  python: "#FFD43B",
  kotlin: "#A97BFF",
};

export const space = { xs: 4, sm: 8, md: 12, lg: 18, xl: 26, xxl: 44 };

export const radius = { field: 16, button: 18, card: 24, pill: 999 };

export const type = {
  hero: { fontSize: 30, fontWeight: "800" as const, letterSpacing: 0.3 },
  screenTitle: { fontSize: 22, fontWeight: "700" as const },
  sectionTitle: { fontSize: 18, fontWeight: "700" as const },
  label: { fontSize: 14, fontWeight: "600" as const },
  body: { fontSize: 15, lineHeight: 23 },
  hint: { fontSize: 13, lineHeight: 20 },
};
