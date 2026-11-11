// The reference image the owner attaches to their app description. Held here (not in navigation params, which must
// stay small) so the understanding, design and instant-preview steps can send it to the AI as a visual guide.
import { AiImage } from "./instantPreview";

let current: AiImage | null = null;

export function setRefImage(im: AiImage | null) {
  current = im;
}

export function getRefImage(): AiImage | null {
  return current;
}

/** The attached image as the array the AI helpers expect (empty when none). */
export function refImages(): AiImage[] {
  return current ? [current] : [];
}
