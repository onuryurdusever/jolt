import { ParsingStrategy, ParseResult, createWebviewFallback, createMetaOnlyResult } from "./base.ts";
import { detectSubstackPaywall } from "../quality.ts";

/**
 * Substack Strategy - Article with Paywall Detection
 * 
 * Substack newsletters can have free and paid tiers.
 * We detect paywalled content and return appropriate response.
 */
export class SubstackStrategy implements ParsingStrategy {
  name = "Substack";

  matches(url: string): boolean {
    return /substack\.com\//.test(url) || /\.substack\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
      });
      
      if (!response.ok) {
        throw new Error(`Substack fetch failed: ${response.status}`);
      }
      
      const html = await response.text();
      
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`, 'i'));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || "Substack Article";
      const description = getMeta("og:description") || "";
      const image = getMeta("og:image");
      const author = getMeta("article:author") || getMeta("og:site_name");
      
      // Extract text for paywall check
      const textContent = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
      
      // Detect paywall
      const isPaywalled = detectSubstackPaywall(html, textContent.length);
      
      if (isPaywalled) {
        return createMetaOnlyResult(url, title, description, image, {
          paywalled: true,
          error: {
            code: "PAYWALL",
            message: "This post is for paid subscribers only",
            fallback: "webview"
          }
        });
      }

      // Substack content is often protected, return meta-only
      // Let user open in webview for full reading
      return {
        type: "article",
        title: title,
        excerpt: description,
        content_html: null, // Don't scrape content
        cover_image: image || undefined,
        reading_time_minutes: 5,
        domain: new URL(url).hostname,
        metadata: {
          platform: "substack",
          author: author || undefined
        },
        fetchMethod: "meta-only",
        confidence: 0.6
      };
    } catch (error) {
      console.error("Substack strategy failed:", error);
      return createWebviewFallback(url, "Substack Article");
    }
  }
}
