// Google AdSense integration. ADSENSE_CLIENT_ID lives in seo/metadata.ts.
import { ADSENSE_CLIENT_ID } from "../seo/metadata";

export const ADSENSE_ENABLED = true;
export const ADSENSE_SRC = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`;

declare global {
  interface Window {
    adsbygoogle: unknown[];
  }
}

export function pushAdSlot(): void {
  if (typeof window === "undefined" || !ADSENSE_ENABLED) return;
  try {
    window.adsbygoogle = window.adsbygoogle || [];
    window.adsbygoogle.push({});
  } catch {
    // Ad blockers or SSR: never break documentation rendering.
  }
}

export { ADSENSE_CLIENT_ID };
