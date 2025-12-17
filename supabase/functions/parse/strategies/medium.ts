import { ParsingStrategy, ParseResult, createWebviewFallback, createMetaOnlyResult } from "./base.ts";
import { detectMediumPaywall } from "../quality.ts";
import { extractArticle, estimateReadingTime, sanitizeTitle } from "../utils.ts";
import { sanitizeHTML } from "../sanitizer.ts";

/**
 * Medium Strategy - Article with Paywall Detection
 * 
 * Medium has a metered paywall. We detect it and return appropriate response.
 * Free articles get full metadata, paywalled articles get meta-only.
 */
export class MediumStrategy implements ParsingStrategy {
  name = "Medium";

  matches(url: string): boolean {
    return /medium\.com\//.test(url) || /.*\.medium\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
      });
      
      if (!response.ok) {
        throw new Error(`Medium fetch failed: ${response.status}`);
      }

      const html = await response.text();
      
      // Extract text content for paywall check
      const textContent = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
      
      // Detect paywall
      const isPaywalled = detectMediumPaywall(html, textContent.length);
      
      // Basic Metadata Extraction since we have the HTML
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`, 'i'));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || "Medium Article";
      const description = getMeta("og:description") || "";
      const image = getMeta("og:image");
      const author = getMeta("article:author");

      if (isPaywalled) {
        // Return meta-only for paywalled content
        return createMetaOnlyResult(url, title, description, image, {
          paywalled: true,
          error: {
            code: "PAYWALL",
            message: "This article is for Medium members only",
            fallback: "webview"
          }
        });
      }

      // If NOT paywalled, extract generic article content
      const articleResult = extractArticle(html, url);
      
      if (articleResult) {
          const sanitized = sanitizeHTML(articleResult.content);
          
          return {
            type: "article",
            title: sanitizeTitle(articleResult.title || title),
            excerpt: articleResult.excerpt || description,
            content_html: sanitized.html,
            cover_image: image || null,
            reading_time_minutes: estimateReadingTime(articleResult.textContent),
            domain: "medium.com",
            metadata: {
              platform: "medium",
              ...(author && { author })
            },
            fetchMethod: "readability",
            confidence: 0.95
          };
      }

      // Fallback if extraction failed but page loaded
      return {
        type: "article",
        title: title,
        excerpt: description,
        content_html: null, // Default strategy MIGHT try again, but let's be honest about failure
        cover_image: image || null,
        reading_time_minutes: 5,
        domain: "medium.com",
        metadata: {
          platform: "medium",
          ...(author && { author })
        },
        fetchMethod: "meta-only",
        confidence: 0.7
      };

    } catch (error) {
      console.error("Medium strategy failed:", error);
      return createWebviewFallback(url, "Medium Article");
    }
  }
}
