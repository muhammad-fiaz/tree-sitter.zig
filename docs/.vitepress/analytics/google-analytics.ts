// Google Analytics integration. GA_ID lives in seo/metadata.ts.
import { GA_ID } from "../seo/metadata";

export interface AnalyticsEvent {
  event: string;
  [key: string]: unknown;
}

declare global {
  interface Window {
    dataLayer: unknown[];
    gtag?: (...args: unknown[]) => void;
  }
}

export function trackEvent(name: string, params: Record<string, unknown> = {}): void {
  if (typeof window === "undefined") return;
  if (typeof window.gtag === "function") {
    window.gtag("event", name, params);
  } else {
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({ event: name, ...params });
  }
}

export function trackPageView(path: string): void {
  trackEvent("page_view", { page_path: path });
}

export function trackExampleView(name: string): void {
  trackEvent("example_view", { example: name });
}

export function trackApiReferenceView(name: string): void {
  trackEvent("api_reference_view", { api: name });
}

export function trackCodeCopy(block: string): void {
  trackEvent("code_copy", { code_block: block });
}

export function trackSearch(query: string): void {
  trackEvent("search", { search_term: query });
}

export function trackGithubClick(): void {
  trackEvent("github_click", {});
}

export function trackExternalLinkClick(url: string): void {
  trackEvent("external_link_click", { url });
}

export { GA_ID };
