import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";

/**
 * Facebook Strategy - Meta Only with WebView Fallback
 * 
 * Facebook content often requires login. We extract OG metadata
 * but don't attempt content scraping. Most FB content will be
 * shown in WebView for proper authentication.
 */
export class FacebookStrategy implements ParsingStrategy {
  name = "Facebook";

  matches(url: string): boolean {
    return /facebook\.com\//.test(url) || /fb\.watch\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Use Chrome UA - Facebook blocks bots
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }
      });
      
      if (!response.ok) {
        throw new Error(`Facebook fetch failed: ${response.status}`);
      }

      const html = await response.text();
      
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || "Facebook Post";
      const description = getMeta("og:description") || "";
      const image = getMeta("og:image");
      const type = getMeta("og:type") || "website";

      return {
        type: type.includes("video") ? "video" : "article",
        title: title,
        excerpt: description,
        content_html: `<a href="${url}" target="_blank">View on Facebook</a><br/><img src="${image}" />`,
        cover_image: image || null,
        reading_time_minutes: 3,
        domain: "facebook.com",
        metadata: {
          platform: "facebook"
        }
      };
    } catch (error) {
      console.error("Facebook strategy failed:", error);
      throw error;
    }
  }
}
