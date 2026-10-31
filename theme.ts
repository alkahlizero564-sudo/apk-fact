// Modern dark theme ("Midnight"). Every screen reads its colors from here.
export const colors = {
  bg: "#0B0F1A",
  surface: "#141A29",
  surfaceAlt: "#1B2236",
  field: "#0F1422",
  border: "#262F45",
  text: "#EEF1F8",
  textMuted: "#8B93A7",
  primary: "#6D5DFC",
  primaryPressed: "#5B4BE8",
  primarySoft: "#211D4A",
  primaryText: "#FFFFFF",
  accent: "#22D3EE",
  okBg: "#0F2E22",
  okText: "#4ADE80",
  errorBg: "#3A1418",
  errorText: "#F87171",
  infoBg: "#181D3A",
  infoBorder: "#2E3566",
  infoText: "#A5B4FC",
  warnText: "#FBBF24",
};

// Brand color of each code language, used for its badge and picker card.
export const langColors = {
  html: "#F06529",
  flutter: "#42A5F5",
  python: "#FFD43B",
};

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 40 };

export const radius = { field: 12, button: 14, card: 20, pill: 999 };

export const type = {
  hero: { fontSize: 28, fontWeight: "800" as const, letterSpacing: 0.3 },
  screenTitle: { fontSize: 22, fontWeight: "700" as const },
  sectionTitle: { fontSize: 18, fontWeight: "700" as const },
  label: { fontSize: 14, fontWeight: "600" as const },
  body: { fontSize: 15, lineHeight: 22 },
  hint: { fontSize: 13, lineHeight: 19 },
};
