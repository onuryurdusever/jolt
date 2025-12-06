import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";

/**
 * Amazon Strategy - Meta Only
 * 
 * Amazon has aggressive bot protection. We only extract metadata (OG tags)
 * and show a preview card. No content scraping attempted.
 * 
 * Policy: Tier 3 (Meta-Only) - User clicks "View Details" to open Amazon
 */
export class AmazonStrategy implements ParsingStrategy {
  name = "Amazon";

  matches(url: string): boolean {
    return /amazon\.(com|co\.uk|de|jp|fr|it|ca|in|com\.br|com\.mx)\//.test(url) || /amzn\.to\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    // Extract ASIN from URL if possible
    const asinMatch = url.match(/\/dp\/([A-Z0-9]{10})/);
    const asin = asinMatch ? asinMatch[1] : null;
    
    try {
      // Use honest UA - may fail, that's acceptable
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)"
        }
      });
      
      if (!response.ok) {
        // Expected to fail often - return webview fallback
        return createWebviewFallback(url, "Amazon Product", {
          protected: false,
          error: {
            code: "PARSE_FAILED",
            message: "Amazon blocked the request",
            fallback: "webview"
          }
        });
      }
      
      const html = await response.text();
      
      // Only extract meta tags - no content scraping
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta (?:property|name)="${name}" content="([^"]*)"`));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || getMeta("title") || "Amazon Product";
      const description = getMeta("og:description") || getMeta("description") || "";
      const image = getMeta("og:image");

      // Meta-only result - no content_html
      return {
        type: "product",
        title: title,
        excerpt: description,
        content_html: null, // No content - user must open in browser
        cover_image: image || null,
        reading_time_minutes: 0,
        domain: "amazon.com",
        metadata: {
          platform: "amazon",
          ...(asin && { asin })
        },
        fetchMethod: "meta-only",
        confidence: 0.6
      };
    } catch (error) {
      console.error("Amazon strategy failed:", error);
      // Return webview fallback instead of throwing
      return createWebviewFallback(url, asin ? `Amazon Product (${asin})` : "Amazon Product", {
        protected: false
      });
    }
  }
}
