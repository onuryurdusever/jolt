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
    return /trello\.com\/c\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    const match = url.match(/trello\.com\/c\/([a-zA-Z0-9]+)/);
    const cardId = match ? match[1] : null;

    if (!cardId) {
      return createWebviewFallback(url, "Trello Card", { protected: true });
    }

    try {
      // Try public API first
      const apiUrl = `https://trello.com/1/cards/${cardId}?fields=name,desc,shortUrl`;
      const response = await fetch(apiUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)"
        }
      });
      
      if (!response.ok) {
        // Private card - return protected webview
        return {
          type: "webview",
          title: `Trello Card (${cardId})`,
          excerpt: "This Trello card requires authentication to view",
          content_html: null,
          cover_image: undefined,
          reading_time_minutes: 0,
          domain: "trello.com",
          metadata: {
            platform: "trello",
            card_id: cardId
          },
          protected: true,
          fetchMethod: "webview",
          confidence: 0.3,
          error: {
            code: "LOGIN_REQUIRED",
            message: "Trello card is private or requires authentication",
            fallback: "webview"
          }
        };
      }

      const data = await response.json();

      // Public card - still return as webview but not protected
      return {
        type: "webview",
        title: data.name || "Trello Card",
        excerpt: data.desc ? data.desc.substring(0, 200) : "Trello Card",
        content_html: null, // Don't store Trello content
        cover_image: undefined,
        reading_time_minutes: 1,
        domain: "trello.com",
        metadata: {
          platform: "trello",
          card_id: cardId
        },
        protected: false,
        fetchMethod: "api",
        confidence: 0.7
      };
    } catch (error) {
      console.error("Trello strategy failed:", error);
      return createWebviewFallback(url, `Trello Card (${cardId})`, { protected: true });
    }
  }
}
