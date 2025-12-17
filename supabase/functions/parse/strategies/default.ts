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

  async parse(url: string, html?: string, clientIP?: string, userId?: string): Promise<ParseResult> {
    const domain = new URL(url).hostname;
    let fetchResult: FetchResult | null = null;
    
    // If HTML wasn't provided, fetch it using unified fetcher
    if (!html) {
      fetchResult = await fetchURL(url, {
        timeout: FETCHER_CONFIG.FETCH_TIMEOUT_MS,
        maxSize: FETCHER_CONFIG.MAX_HTML_SIZE,
        checkRobots: true
      }, clientIP, userId);
      
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
    
    console.log(`🔍 Readability for ${domain}:`, articleResult ? `SUCCESS (${articleResult.textContent?.length || 0} chars)` : 'NULL');
    
    if (articleResult) {
      // Run quality check just for logging/metadata, but DON'T BLOCK
      const quality = checkContentQuality(html, articleResult.textContent);
      
      if (!quality.isValid) {
        console.log(`⚠️ Quality warning for ${domain}: ${quality.issues.join(', ')} (ignoring and serving article)`)  ;
      }
      
      // Sanitize the content HTML
      const sanitized = sanitizeHTML(articleResult.content);
      
      console.log(`🧹 Sanitizer for ${domain}: input=${articleResult.content?.length || 0} chars, output=${sanitized.html?.length || 0} chars`);
      
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
        confidence: 1.0, // Force high confidence so iOS app trusts it
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
      // Calculate reading time from extracted text
      const readingTime = estimateReadingTime(textContent);
      
      return {
        type: 'webview',
        title: sanitizeTitle(metaResult.title),
        excerpt: metaResult.description,
        content_html: null,
        cover_image: metaResult.image,
        reading_time_minutes: readingTime,
        domain,
        metadata: null,
        fetchMethod: 'meta-only',
        confidence: Math.min(quality.confidence, 0.5),
        paywalled: quality.detectedWalls.paywall,
        protected: quality.detectedWalls.login,
        finalUrl: fetchResult?.url
      };
    }

    // TIER 4: Fallback to webview - still try to estimate reading time
    const textContent = html ? html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim() : '';
    const readingTime = estimateReadingTime(textContent);
    
    return {
      type: 'webview',
      title: extractTitleFromURL(url),
      excerpt: null,
      content_html: null,
      cover_image: null,
      reading_time_minutes: readingTime,
      domain,
      metadata: null,
      fetchMethod: 'webview',
      confidence: 0.2,
      finalUrl: fetchResult?.url
    };
  }
}
