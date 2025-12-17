import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";

/**
 * Trello Strategy - Protected Content
 * 
 * Trello cards are often private. We try the public API first,
 * if that fails we mark as protected and show in WebView.
 * 
 * Policy: Try public API, fallback to protected webview
 */
export class TrelloStrategy implements ParsingStrategy {
  name = "Trello";

  matches(url: string): boolean {
    return /trello\.com\/[bc]\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Use .json suffix strategy (works for public Boards and Cards)
      const jsonUrl = `${url.split('?')[0]}.json`;
      
      const response = await fetch(jsonUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
      });

      if (!response.ok) {
         // Fallback to webview if private
         return createWebviewFallback(url, "Trello Board/Card", { protected: true });
      }

      const data = await response.json();
      
      // Data structure: { name: "Title", desc: "Description", ... }
      // Works for both Card and Board
      
      return {
        type: "webview",
        title: data.name || "Trello",
        excerpt: data.desc ? data.desc.substring(0, 300) : "Trello Board/Card",
        content_html: null,
        cover_image: data.prefs?.backgroundImage || data.cover?.sharedSourceUrl || undefined, 
        reading_time_minutes: 1,
        domain: "trello.com",
        metadata: {
          platform: "trello",
          id: data.id
        }
      };
    } catch (error) {
      console.error("Trello strategy failed:", error);
      return createWebviewFallback(url, "Trello", { protected: true });
    }
  }
}
