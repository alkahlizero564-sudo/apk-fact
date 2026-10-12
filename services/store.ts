import AsyncStorage from "@react-native-async-storage/async-storage";
import { GenerationResult } from "./generate";

export type AppSlot = "1" | "2";

function key(slot: AppSlot) {
  return `LAST_GENERATION_${slot}`;
}

export async function saveGeneration(slot: AppSlot, result: GenerationResult) {
  await AsyncStorage.setItem(key(slot), JSON.stringify(result));
}

export async function loadGeneration(slot: AppSlot): Promise<GenerationResult | null> {
  const raw = await AsyncStorage.getItem(key(slot));
  return raw ? JSON.parse(raw) : null;
}
