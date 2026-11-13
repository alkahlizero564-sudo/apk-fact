// Holds the design the owner picked from the gallery, so CreateScreen can start the app from it without passing a
// big object through navigation params. CreateScreen reads it when opened with templateId === GALLERY_PICK.
import { Template } from "./templates";

export const GALLERY_PICK = "__gallery_pick__";

let picked: Template | null = null;

export function setGalleryPick(t: Template | null) {
  picked = t;
}

export function getGalleryPick(): Template | null {
  return picked;
}
