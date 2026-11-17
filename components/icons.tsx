// The glass theme uses filled icons everywhere. Screens import Ionicons from here instead of @expo/vector-icons:
// any "<name>-outline" is drawn as the filled "<name>" when that glyph exists, so no screen has to rename its icons.
import React from "react";
import { Ionicons as Base } from "@expo/vector-icons";

type Props = React.ComponentProps<typeof Base>;
const glyphs: Record<string, number> = (Base as any).glyphMap ?? {};

export function filledName(name: string): string {
  if (name.endsWith("-outline")) {
    const f = name.slice(0, -"-outline".length);
    if (f in glyphs) return f;
  }
  return name;
}

export function Ionicons(props: Props) {
  return <Base {...props} name={filledName(String(props.name)) as Props["name"]} />;
}
Ionicons.glyphMap = glyphs;
