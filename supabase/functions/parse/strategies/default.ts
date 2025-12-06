import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";
import { 
  extractArticle, 
  scrapeMetaTags, 
  extractCoverImage, 
  estimateReadingTime, 
  sanitizeTitle, 
  extractTitleFromURL 
} from "../utils.ts";
import { fetchURL, FetchResult, FETCHER_CONFIG } from "../fetcher.ts";
import { sanitizeHTML } from "../sanitizer.ts";
import { checkContentQuality, isLoginRedirect } from "../quality.ts";
import { tryOEmbed } from "./oembed.ts";

/**
 * Default Strategy - Fallback Parser
 * 
 * Used when no platform-specific strategy matches.
 * Implements the full 4-tier parsing pipeline:
 * 
 * Tier 1: oEmbed (if discovery tag found)
 * Tier 2: Readability-style article extraction
 * Tier 3: Meta tags only
 * Tier 4: WebView fallback
 * 
 * Includes quality gates for:
 * - Cookie consent walls
 * - Paywall detection
 * - Login redirects
 * - Minimum content thresholds
 */
export class DefaultStrategy implements ParsingStrategy {
  name = "Default";

  matches(url: string): boolean {
    return true; // Fallback for everything
  }

  async parse(url: string, html?: string, clientIP?: string): Promise<ParseResult> {
    const domain = new URL(url).hostname;
    let fetchResult: FetchResult | null = null;
    
    // If HTML wasn't provided, fetch it using unified fetcher
    if (!html) {
      fetchResult = await fetchURL(url, {
        timeout: FETCHER_CONFIG.FETCH_TIMEOUT_MS,
        maxSize: FETCHER_CONFIG.MAX_HTML_SIZE,
        checkRobots: true
      }, clientIP);
      
      if (!fetchResult.success) {
        console.error(`Default strategy fetch failed: ${fetchResult.error?.message}`);
        
        // Map fetch error to appropriate response
        return createWebviewFallback(url, extractTitleFromURL(url), {
          error: {
            code: fetchResult.error?.code === 'ROBOTS_BLOCKED' ? 'PROTECTED' : 
                  fetchResult.error?.code === 'RATE_LIMITED' ? 'RATE_LIMITED' :
                  fetchResult.error?.code === 'TIMEOUT' ? 'TIMEOUT' : 'NETWORK_ERROR',
            message: fetchResult.error?.message || 'Failed to fetch content',
            fallback: 'webview'
          }
        });
      }
      
      html = fetchResult.html!;
      
      // Check for login redirect
      if (isLoginRedirect(url, fetchResult.url)) {
        return createWebviewFallback(url, extractTitleFromURL(url), {
          protected: true,
          error: {
            code: 'LOGIN_REQUIRED',
            message: 'This page requires authentication',
            fallback: 'webview'
          }
        });
      }
    }
    
    // TIER 1: Try oEmbed if discovery tag found
    const oembedResult = await tryOEmbed(url, html);
    if (oembedResult) {
      console.log(`✅ oEmbed success for ${domain}`);
      return oembedResult;
    }
    
    // TIER 2: Try article extraction
    const articleResult = extractArticle(html, url);
    
    if (articleResult && articleResult.content.length > 200) {
      // Run quality check on extracted content
      const quality = checkContentQuality(html, articleResult.textContent);
      
      if (!quality.isValid) {
        console.log(`⚠️ Quality check failed for ${domain}: ${quality.issues.join(', ')}`);
        
        // Handle different quality issues
        if (quality.detectedWalls.consent) {
          return createWebviewFallback(url, sanitizeTitle(articleResult.title) || extractTitleFromURL(url), {
            error: {
              code: 'CONSENT_WALL',
              message: 'Cookie consent required',
              fallback: 'webview'
            }
          });
        }
        
        if (quality.detectedWalls.paywall) {
          const metaResult = scrapeMetaTags(html);
          return {
            type: 'webview',
            title: sanitizeTitle(articleResult.title) || sanitizeTitle(metaResult.title) || extractTitleFromURL(url),
            excerpt: metaResult.description || articleResult.excerpt,
            content_html: null,
            cover_image: extractCoverImage(html) || metaResult.image,
            reading_time_minutes: 0,
            domain,
            metadata: null,
            paywalled: true,
            fetchMethod: 'meta-only',
            confidence: quality.confidence,
            error: {
              code: 'PAYWALL',
              message: 'Content behind paywall',
              fallback: 'webview'
            }
          };
        }
        
        if (quality.detectedWalls.login) {
          return createWebviewFallback(url, sanitizeTitle(articleResult.title) || extractTitleFromURL(url), {
            protected: true,
            error: {
              code: 'LOGIN_REQUIRED',
              message: 'Login required to view content',
              fallback: 'webview'
            }
          });
        }
        
        // For other quality issues, still try to serve content if recommendation allows
        if (quality.recommendation === 'WEBVIEW') {
          const metaResult = scrapeMetaTags(html);
          return createWebviewFallback(url, sanitizeTitle(metaResult.title) || extractTitleFromURL(url), {
            error: {
              code: 'PARSE_FAILED',
              message: 'Content quality too low',
              fallback: 'webview'
            }
          });
        }
      }
      
      // Sanitize the content HTML
      const sanitized = sanitizeHTML(articleResult.content);
      
      if (sanitized.hasUnsafeContent) {
        console.log(`⚠️ Unsafe content removed from ${domain}: scripts=${sanitized.removedElements.scripts}, handlers=${sanitized.removedElements.eventHandlers}`);
      }
      
      return {
        type: 'article',
        title: sanitizeTitle(articleResult.title),
        excerpt: articleResult.excerpt,
        content_html: sanitized.html,
        cover_image: extractCoverImage(html),
        reading_time_minutes: estimateReadingTime(articleResult.textContent),
        domain,
        metadata: null,
        fetchMethod: 'readability',
        confidence: quality.confidence,
        finalUrl: fetchResult?.url,
        robotsCompliant: true
      };
    }

    // TIER 3: Try OpenGraph Meta Tags
    const metaResult = scrapeMetaTags(html);
    if (metaResult.title) {
      // Still run quality check
      const textContent = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
      const quality = checkContentQuality(html, textContent);
      
      return {
        type: 'webview',
        title: sanitizeTitle(metaResult.title),
        excerpt: metaResult.description,
        content_html: null,
        cover_image: metaResult.image,
        reading_time_minutes: 0,
        domain,
        metadata: null,
        fetchMethod: 'meta-only',
        confidence: Math.min(quality.confidence, 0.5),
        paywalled: quality.detectedWalls.paywall,
        protected: quality.detectedWalls.login,
        finalUrl: fetchResult?.url
      };
    }

    // TIER 4: Fallback to webview
    return {
      type: 'webview',
      title: extractTitleFromURL(url),
      excerpt: null,
      content_html: null,
      cover_image: null,
      reading_time_minutes: 0,
      domain,
      metadata: null,
      fetchMethod: 'webview',
      confidence: 0.2,
      finalUrl: fetchResult?.url
    };
  }
}
