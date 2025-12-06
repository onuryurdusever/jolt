import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";

/**
 * Notion Strategy - Protected Content
 * 
 * Notion pages typically require authentication. We extract minimal metadata
 * and mark as protected. Content should be viewed in WebView where user
 * can authenticate if needed.
 * 
 * Policy: Tier 3 (Protected) - Never process on server, client-side only
 */
export class NotionStrategy implements ParsingStrategy {
  name = "Notion";

  matches(url: string): boolean {
    return /notion\.site\//.test(url) || /notion\.so\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)"
        }
      });
      
      // Don't process if login required
      if (!response.ok || response.status === 401 || response.status === 403) {
        return createWebviewFallback(url, "Notion Page", {
          protected: true,
          error: {
            code: "PROTECTED",
            message: "This Notion page requires authentication",
            fallback: "webview"
          }
        });
      }
      
      const html = await response.text();
      
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`, 'i'));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || "Notion Page";
      const description = getMeta("og:description");
      const image = getMeta("og:image");

      // Always return as webview + protected
      // Notion content should never be processed server-side
      return {
        type: "webview",
        title: title,
        excerpt: description || "View this page on Notion",
        content_html: null, // Never store Notion content
        cover_image: image || undefined,
        reading_time_minutes: 0,
        domain: "notion.so",
        metadata: {
          platform: "notion"
        },
        protected: true,
        fetchMethod: "webview",
        confidence: 0.5,
        error: {
          code: "PROTECTED",
          message: "Notion content should be viewed in browser",
          fallback: "webview"
        }
      };
    } catch (error) {
      console.error("Notion strategy failed:", error);
      return createWebviewFallback(url, "Notion Page", { protected: true });
    }
  }
}
