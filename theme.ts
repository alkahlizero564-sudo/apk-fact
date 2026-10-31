// "Aurora" dark theme. Every screen reads its colors from here.
export const colors = {
  bg: "#07080E",
  surface: "#10121B",
  surfaceAlt: "#171A26",
  field: "#0B0D15",
  border: "#22263A",
  text: "#F3F5FB",
  textMuted: "#9097AD",
  primary: "#6E4BFF",
  primaryPressed: "#5B3AEB",
  primarySoft: "#1C1840",
  primaryText: "#FFFFFF",
  accent: "#2DD4BF",
  okBg: "#0E2A22",
  okText: "#4ADE80",
  errorBg: "#3A1418",
  errorText: "#F87171",
  infoBg: "#151937",
  infoBorder: "#2A3163",
  infoText: "#A9B6FF",
  warnText: "#FBBF24",
};

// Brand gradient for the header card and primary buttons (white text passes AA on both ends).
export const gradient = ["#6E4BFF", "#2563EB"] as const;

// Brand color of each code language, used for its badge and picker card.
export const langColors = {
  html: "#F06529",
  flutter: "#42A5F5",
  python: "#FFD43B",
  kotlin: "#A97BFF",
};

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 40 };

export const radius = { field: 14, button: 16, card: 22, pill: 999 };

export const type = {
  hero: { fontSize: 30, fontWeight: "800" as const, letterSpacing: 0.3 },
  screenTitle: { fontSize: 22, fontWeight: "700" as const },
  sectionTitle: { fontSize: 18, fontWeight: "700" as const },
  label: { fontSize: 14, fontWeight: "600" as const },
  body: { fontSize: 15, lineHeight: 22 },
  hint: { fontSize: 13, lineHeight: 19 },
};
