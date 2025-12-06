/**
 * Fetch method indicates how the content was retrieved
 */
export type FetchMethod = 
  | 'api'          // Official API (GitHub, Wikipedia, etc.)
  | 'oembed'       // oEmbed endpoint
  | 'readability'  // HTML parsed with Readability
  | 'meta-only'    // Only metadata extracted (OG tags)
  | 'webview';     // Must be shown in WebView

/**
 * Error information when parsing fails or content is restricted
 */
export interface ParseError {
  code: ParseErrorCode;
  message: string;
  fallback: 'webview' | 'meta-only' | 'retry' | 'reject';
}

export type ParseErrorCode = 
  | 'PAYWALL'
  | 'PROTECTED'
  | 'LOGIN_REQUIRED'
  | 'CONSENT_WALL'
  | 'TIMEOUT'
  | 'SIZE_LIMIT'
  | 'ENCODING'
  | 'ROBOTS_BLOCKED'
  | 'RATE_LIMITED'
  | 'NOT_FOUND'
  | 'NETWORK_ERROR'
  | 'PARSE_FAILED';

/**
 * Result from parsing a URL
 */
export interface ParseResult {
  // Content type
  type: string;
  
  // Basic content
  title: string;
  excerpt: string | null;
  content_html: string | null;
  cover_image: string | null;
  reading_time_minutes: number;
  domain: string;
  
  // Platform-specific metadata
  metadata: Record<string, string> | null;
  
  // New fields for v3.0
  
  /** Content requires authentication/login */
  protected?: boolean;
  
  /** Content is behind a paywall */
  paywalled?: boolean;
  
  /** How the content was fetched */
  fetchMethod?: FetchMethod;
  
  /** Confidence score 0.0-1.0 for content quality */
  confidence?: number;
  
  /** Error information if parsing failed or content is restricted */
  error?: ParseError;
  
  /** Final URL after redirects */
  finalUrl?: string;
  
  /** Whether robots.txt was respected */
  robotsCompliant?: boolean;
}

/**
 * Strategy interface for platform-specific parsing
 */
export interface ParsingStrategy {
  name: string;
  matches(url: string): boolean;
  parse(url: string, html?: string, clientIP?: string): Promise<ParseResult>;
}

/**
 * Helper to create a webview fallback result
 */
export function createWebviewFallback(
  url: string, 
  title: string,
  options: {
    protected?: boolean;
    paywalled?: boolean;
    error?: ParseError;
    excerpt?: string;
    coverImage?: string;
  } = {}
): ParseResult {
  const domain = new URL(url).hostname;
  return {
    type: 'webview',
    title: title || domain,
    excerpt: options.excerpt || null,
    content_html: null,
    cover_image: options.coverImage || null,
    reading_time_minutes: 0,
    domain,
    metadata: null,
    protected: options.protected,
    paywalled: options.paywalled,
    fetchMethod: 'webview',
    confidence: 0.3,
    error: options.error
  };
}

/**
 * Helper to create a meta-only result
 */
export function createMetaOnlyResult(
  url: string,
  title: string,
  excerpt: string | null,
  coverImage: string | null,
  options: {
    paywalled?: boolean;
    error?: ParseError;
  } = {}
): ParseResult {
  const domain = new URL(url).hostname;
  return {
    type: 'webview',
    title,
    excerpt,
    content_html: null,
    cover_image: coverImage,
    reading_time_minutes: 0,
    domain,
    metadata: null,
    paywalled: options.paywalled,
    fetchMethod: 'meta-only',
    confidence: 0.5,
    error: options.error
  };
}
