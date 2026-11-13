// Holds the design the owner picked from the gallery, so CreateScreen can start the app from it without passing a
// big object through navigation params. CreateScreen reads it when opened with templateId === GALLERY_PICK.
import { Template } from "./templates";
import { Lang } from "./langs";

export const GALLERY_PICK = "__gallery_pick__";

let picked: Template | null = null;

export function setGalleryPick(t: Template | null) {
  picked = t;
}

export function getGalleryPick(): Template | null {
  return picked;
}

// A pair design picked from the gallery: PairScreen takes it once when it opens.
export type PairStart = { base: string; lang: Lang; description: string };
let pairPicked: PairStart | null = null;

export function setGalleryPairPick(p: PairStart | null) {
  pairPicked = p;
}

/** Returns the picked pair design and clears it (so reopening the pair screen later starts empty). */
export function takeGalleryPairPick(): PairStart | null {
  const p = pairPicked;
  pairPicked = null;
  return p;
}
