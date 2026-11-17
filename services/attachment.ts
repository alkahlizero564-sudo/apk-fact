// The reference images the owner attaches to their app description. Held here (not in navigation params, which must
// stay small) so the home screen, the wizard and the AI steps all see the same pictures.
import * as ImagePicker from "expo-image-picker";
import * as ImageManipulator from "expo-image-manipulator";
import { AiImage } from "./instantPreview";

export type RefPic = { uri: string; image: AiImage };

let pics: RefPic[] = [];

export function setRefPics(p: RefPic[]) {
  pics = p;
}

export function getRefPics(): RefPic[] {
  return pics;
}

/** Older callers: set a single image, or clear. */
export function setRefImage(im: AiImage | null) {
  pics = im ? [{ uri: "", image: im }] : [];
}

export function getRefImage(): AiImage | null {
  return pics[0]?.image ?? null;
}

/** All attached images as the array the AI helpers expect (empty when none). */
export function refImages(): AiImage[] {
  return pics.map((p) => p.image);
}

// ---------- Picking: one place for every screen (home, create, pair, chat) ----------

/** How many reference pictures the owner can attach to one description. */
export const MAX_PICS = 20;

// Phone photos are several MB each; sent as-is, 20 of them would pass Gemini's request limit (~20 MB) and slow
// every AI step. Each picture is scaled to at most this width and re-compressed (~100–250 KB), and the total is capped.
const MAX_WIDTH = 1024;
const MAX_TOTAL_BASE64 = 12 * 1024 * 1024;

/**
 * Opens the gallery for up to `room` pictures and returns them scaled down, ready for the AI.
 * Throws an Arabic message when permission is refused. Returns [] when the owner cancels.
 */
export async function pickRefPics(room: number, already: RefPic[] = []): Promise<RefPic[]> {
  if (room <= 0) return [];
  const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!perm.granted) throw new Error("نحتاج إذن الوصول للصور لإرفاق صور مرجعية.");
  const res = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    quality: 1,
    allowsMultipleSelection: true,
    selectionLimit: room,
  });
  if (res.canceled) return [];
  let total = already.reduce((n, p) => n + p.image.data.length, 0);
  const out: RefPic[] = [];
  for (const a of (res.assets ?? []).slice(0, room)) {
    const resize = a.width && a.width > MAX_WIDTH ? [{ resize: { width: MAX_WIDTH } }] : [];
    const r = await ImageManipulator.manipulateAsync(a.uri, resize, {
      compress: 0.6,
      format: ImageManipulator.SaveFormat.JPEG,
      base64: true,
    });
    if (!r.base64) continue;
    if (total + r.base64.length > MAX_TOTAL_BASE64) break; // keep the request under the AI's size limit
    total += r.base64.length;
    out.push({ uri: r.uri, image: { data: r.base64, mime: "image/jpeg" } });
  }
  return out;
}
