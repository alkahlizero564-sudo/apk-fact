// Unfinished work survives errors and closing APK Fact: the create and pair screens save what the owner has
// entered (name, description, choices, approved list) while they work, and offer to continue it next time.
import { useEffect, useRef } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";

const PREFIX = "draft:";

export async function loadDraft<T>(key: string): Promise<(T & { savedAt: number }) | null> {
  try {
    const v = await AsyncStorage.getItem(PREFIX + key);
    const d = v ? JSON.parse(v) : null;
    // Week-old drafts are dropped.
    return d && Date.now() - (d.savedAt ?? 0) < 7 * 24 * 3600 * 1000 ? d : null;
  } catch {
    return null;
  }
}

export async function clearDraft(key: string) {
  try {
    await AsyncStorage.removeItem(PREFIX + key);
  } catch {}
}

/** Saves `value` (debounced) while `enabled`; nothing is saved while `enabled` is false. */
export function useAutoSave(key: string, value: object, enabled: boolean) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const json = JSON.stringify(value);
  useEffect(() => {
    if (!enabled) return;
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      AsyncStorage.setItem(PREFIX + key, JSON.stringify({ ...JSON.parse(json), savedAt: Date.now() })).catch(() => {});
    }, 800);
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [key, json, enabled]);
}
