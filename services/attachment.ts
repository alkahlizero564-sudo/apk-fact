// The reference images the owner attaches to their app description. Held here (not in navigation params, which must
// stay small) so the home screen, the wizard and the AI steps all see the same pictures.
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
