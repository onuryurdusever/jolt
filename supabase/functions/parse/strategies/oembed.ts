/**
 * Generic oEmbed Strategy
 * 
 * Handles any site that supports oEmbed through:
 * 1. Discovery tag parsing (<link rel="alternate" type="application/json+oembed">)
 * 2. Hardcoded endpoints for major platforms
 * 
 * Fallback: If oEmbed fails, returns meta-only result
 */

import { ParsingStrategy, ParseResult, createWebviewFallback, createMetaOnlyResult } from "./base.ts";
import { FETCHER_CONFIG } from "../fetcher.ts";

// =============================================================================
// HARDCODED OEMBED ENDPOINTS
// =============================================================================

interface OEmbedProvider {
  name: string;
  patterns: RegExp[];
  endpoint: string;
  type: string;
}

const OEMBED_PROVIDERS: OEmbedProvider[] = [
  // Video
  {
    name: "YouTube",
    patterns: [/youtube\.com\/watch/, /youtu\.be\//],
    endpoint: "https://www.youtube.com/oembed",
    type: "video"
  },
  {
    name: "Vimeo",
    patterns: [/vimeo\.com\/\d+/],
    endpoint: "https://vimeo.com/api/oembed.json",
    type: "video"
  },
  {
    name: "Dailymotion",
    patterns: [/dailymotion\.com\/video/],
    endpoint: "https://www.dailymotion.com/services/oembed",
    type: "video"
  },
  {
    name: "TikTok",
    patterns: [/tiktok\.com\/@[^\/]+\/video/],
    endpoint: "https://www.tiktok.com/oembed",
    type: "video"
  },
  
  // Audio
  {
    name: "Spotify",
    patterns: [/open\.spotify\.com\/(track|album|playlist|episode)/],
    endpoint: "https://open.spotify.com/oembed",
    type: "audio"
  },
  {
    name: "SoundCloud",
    patterns: [/soundcloud\.com\/[^\/]+\//],
    endpoint: "https://soundcloud.com/oembed",
    type: "audio"
  },
  
  // Social
  {
    name: "Twitter",
    patterns: [/twitter\.com\/[^\/]+\/status/, /x\.com\/[^\/]+\/status/],
    endpoint: "https://publish.twitter.com/oembed",
    type: "social"
  },
  
  // Images
  {
    name: "Flickr",
    patterns: [/flickr\.com\/photos\//],
    endpoint: "https://www.flickr.com/services/oembed/",
    type: "social"
  },
  
  // Slides/Docs
  {
    name: "SlideShare",
    patterns: [/slideshare\.net\//],
    endpoint: "https://www.slideshare.net/api/oembed/2",
    type: "article"
  },
  {
    name: "Speaker Deck",
    patterns: [/speakerdeck\.com\//],
    endpoint: "https://speakerdeck.com/oembed.json",
    type: "article"
  },
  
  // Code
  {
    name: "CodePen",
    patterns: [/codepen\.io\/[^\/]+\/pen/],
    endpoint: "https://codepen.io/api/oembed",
    type: "code"
  },
  {
    name: "Gist",
    patterns: [/gist\.github\.com\//],
    endpoint: "https://gist.github.com/oembed",
    type: "code"
  },
  
  // Design
  {
    name: "Figma",
    patterns: [/figma\.com\/(file|proto)/],
    endpoint: "https://www.figma.com/api/oembed",
    type: "design"
  },
  {
    name: "Dribbble",
    patterns: [/dribbble\.com\/shots\//],
    endpoint: "https://dribbble.com/oauth/oembed",
    type: "design"
  }
];

// =============================================================================
// OEMBED RESPONSE TYPE
// =============================================================================

interface OEmbedResponse {
  type: "photo" | "video" | "link" | "rich";
  version?: string;
  title?: string;
  author_name?: string;
  author_url?: string;
  provider_name?: string;
  provider_url?: string;
  thumbnail_url?: string;
  thumbnail_width?: number;
  thumbnail_height?: number;
  html?: string;
  width?: number;
  height?: number;
  url?: string; // For photo type
  duration?: number; // In seconds, some providers include this
}

// =============================================================================
// GENERIC OEMBED STRATEGY
// =============================================================================

export class OEmbedStrategy implements ParsingStrategy {
  name = "oEmbed";
  
  // This strategy is used as a fallback, not matched directly
  matches(url: string): boolean {
    return false; // Don't auto-match, called explicitly
  }
  
  /**
   * Check if a URL has a known oEmbed provider
   */
  static hasProvider(url: string): boolean {
    return OEMBED_PROVIDERS.some(provider => 
      provider.patterns.some(pattern => pattern.test(url))
    );
  }
  
  /**
   * Get provider for a URL
   */
  static getProvider(url: string): OEmbedProvider | null {
    return OEMBED_PROVIDERS.find(provider =>
      provider.patterns.some(pattern => pattern.test(url))
    ) || null;
  }
  
  async parse(url: string, html?: string): Promise<ParseResult> {
    // 1. Try hardcoded provider first
    const provider = OEmbedStrategy.getProvider(url);
    if (provider) {
      const result = await this.fetchOEmbed(url, provider.endpoint, provider.type);
      if (result) return result;
    }
    
    // 2. Try discovery from HTML
    if (html) {
      const discoveredEndpoint = this.discoverOEmbedEndpoint(html);
      if (discoveredEndpoint) {
        const result = await this.fetchOEmbed(url, discoveredEndpoint, "article");
        if (result) return result;
      }
    }
    
    // 3. Fallback to meta-only
    return this.createFallbackResult(url, html);
  }
  
  /**
   * Discover oEmbed endpoint from HTML
   */
  private discoverOEmbedEndpoint(html: string): string | null {
    // Look for <link rel="alternate" type="application/json+oembed" href="...">
    const jsonMatch = html.match(
      /<link[^>]+type=["']application\/json\+oembed["'][^>]+href=["']([^"']+)["']/i
    );
    if (jsonMatch) return jsonMatch[1];
    
    // Alternative order
    const altMatch = html.match(
      /<link[^>]+href=["']([^"']+)["'][^>]+type=["']application\/json\+oembed["']/i
    );
    if (altMatch) return altMatch[1];
    
    // XML format (fallback)
    const xmlMatch = html.match(
      /<link[^>]+type=["']text\/xml\+oembed["'][^>]+href=["']([^"']+)["']/i
    );
    if (xmlMatch) return xmlMatch[1];
    
    return null;
  }
  
  /**
   * Fetch oEmbed data from endpoint
   */
  private async fetchOEmbed(
    url: string, 
    endpoint: string, 
    defaultType: string
  ): Promise<ParseResult | null> {
    try {
      const oembedUrl = endpoint.includes("?") 
        ? `${endpoint}&url=${encodeURIComponent(url)}&format=json`
        : `${endpoint}?url=${encodeURIComponent(url)}&format=json`;
      
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), FETCHER_CONFIG.OEMBED_TIMEOUT_MS);
      
      const response = await fetch(oembedUrl, {
        signal: controller.signal,
        headers: {
          "User-Agent": FETCHER_CONFIG.USER_AGENT,
          "Accept": "application/json"
        }
      });
      
      clearTimeout(timeout);
      
      if (!response.ok) {
        console.warn(`oEmbed fetch failed for ${url}: ${response.status}`);
        return null;
      }
      
      const data: OEmbedResponse = await response.json();
      
      // Map oEmbed type to our types
      const type = this.mapOEmbedType(data.type, defaultType);
      
      // Calculate reading time
      let readingTime = 3;
      if (data.duration) {
        readingTime = Math.ceil(data.duration / 60);
      }
      
      return {
        type,
        title: data.title || "Untitled",
        excerpt: data.author_name 
          ? `By ${data.author_name}${data.provider_name ? ` on ${data.provider_name}` : ''}`
          : data.provider_name || null,
        content_html: data.html || null,
        cover_image: data.thumbnail_url || (data.type === "photo" ? data.url : null) || null,
        reading_time_minutes: readingTime,
        domain: new URL(url).hostname,
        metadata: {
          platform: data.provider_name?.toLowerCase() || "oembed",
          ...(data.author_name && { author_name: data.author_name }),
          ...(data.author_url && { author_url: data.author_url }),
          ...(data.provider_name && { provider_name: data.provider_name }),
          ...(data.duration && { duration_seconds: data.duration.toString() })
        },
        fetchMethod: "oembed",
        confidence: 0.8
      };
      
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        console.warn(`oEmbed timeout for ${url}`);
      } else {
        console.warn(`oEmbed error for ${url}:`, error);
      }
      return null;
    }
  }
  
  /**
   * Map oEmbed type to our content types
   */
  private mapOEmbedType(oembedType: string, defaultType: string): string {
    switch (oembedType) {
      case "video": return "video";
      case "photo": return "social";
      case "rich": return defaultType;
      case "link": return "article";
      default: return defaultType;
    }
  }
  
  /**
   * Create fallback result when oEmbed fails
   */
  private createFallbackResult(url: string, html?: string): ParseResult {
    // Try to extract basic meta tags
    if (html) {
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta[^>]+(?:property|name)=["']${name}["'][^>]+content=["']([^"']*)["']`, 'i'));
        return match ? match[1] : null;
      };
      
      const title = getMeta("og:title") || getMeta("twitter:title");
      const description = getMeta("og:description") || getMeta("twitter:description");
      const image = getMeta("og:image") || getMeta("twitter:image");
      
      if (title) {
        return createMetaOnlyResult(url, title, description, image);
      }
    }
    
    return createWebviewFallback(url, new URL(url).hostname);
  }
}

/**
 * Try to get oEmbed result for a URL
 * Returns null if oEmbed is not available or fails
 */
export async function tryOEmbed(url: string, html?: string): Promise<ParseResult | null> {
  const strategy = new OEmbedStrategy();
  
  // Only try if we have a known provider or discovery might work
  const hasProvider = OEmbedStrategy.hasProvider(url);
  const hasDiscoveryTag = html?.includes("oembed");
  
  if (!hasProvider && !hasDiscoveryTag) {
    return null;
  }
  
  const result = await strategy.parse(url, html);
  
  // Check if we got a real result (not just fallback)
  if (result.fetchMethod === "oembed") {
    return result;
  }
  
  return null;
}
