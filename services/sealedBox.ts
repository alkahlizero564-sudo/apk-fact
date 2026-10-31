// libsodium "sealed box" (crypto_box_seal), the format GitHub requires for Actions secrets.
// Kept free of Expo imports so it can be tested in Node; the caller sets nacl's random source.
import nacl from "tweetnacl";
import { blake2b } from "blakejs";

function concat(a: Uint8Array, b: Uint8Array) {
  const out = new Uint8Array(a.length + b.length);
  out.set(a);
  out.set(b, a.length);
  return out;
}

export function sealedBox(message: Uint8Array, recipientPublicKey: Uint8Array): Uint8Array {
  const eph = nacl.box.keyPair();
  const nonce = blake2b(concat(eph.publicKey, recipientPublicKey), undefined, nacl.box.nonceLength);
  return concat(eph.publicKey, nacl.box(message, nonce, recipientPublicKey, eph.secretKey));
}

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

export function toBase64(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i += 3) {
    const n = (bytes[i] << 16) | ((bytes[i + 1] ?? 0) << 8) | (bytes[i + 2] ?? 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63];
    out += i + 1 < bytes.length ? B64[(n >> 6) & 63] : "=";
    out += i + 2 < bytes.length ? B64[n & 63] : "=";
  }
  return out;
}

export function fromBase64(s: string): Uint8Array {
  const clean = s.replace(/[^A-Za-z0-9+/]/g, "");
  const out: number[] = [];
  for (let i = 0; i < clean.length; i += 4) {
    const n =
      (B64.indexOf(clean[i]) << 18) |
      (B64.indexOf(clean[i + 1]) << 12) |
      ((B64.indexOf(clean[i + 2]) & 63) << 6) |
      (B64.indexOf(clean[i + 3]) & 63);
    out.push((n >> 16) & 255);
    if (clean[i + 2] !== undefined) out.push((n >> 8) & 255);
    if (clean[i + 3] !== undefined) out.push(n & 255);
  }
  return new Uint8Array(out);
}

export function utf8(s: string): Uint8Array {
  return new Uint8Array(unescape(encodeURIComponent(s)).split("").map((c) => c.charCodeAt(0)));
}

/** Encrypt a secret value for GitHub with the repository's base64 public key. */
export function encryptSecret(value: string, publicKeyB64: string): string {
  return toBase64(sealedBox(utf8(value), fromBase64(publicKeyB64)));
}
