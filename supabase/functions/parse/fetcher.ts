/**
 * Unified Fetcher Service
 * 
 * Centralized HTTP fetching with:
 * - Generic User-Agent (no spoofing)
 * - Hybrid size limiting (Content-Length check + streaming abort)
 * - Timeout handling (10s default)
 * - Redirect chain tracking (max 3 hops)
 * - Private IP blocking (SSRF protection)
 * - Charset detection (header + meta tag)
 * - Upstash Redis integration (rate limiting, robots.txt cache)
 */

import { Redis } from "https://deno.land/x/upstash_redis@v1.22.0/mod.ts";

// =============================================================================
// CONFIGURATION
// =============================================================================

const CONFIG = {
  // User-Agent: Generic, honest, no domain until announced
  USER_AGENT: "Mozilla/5.0 (compatible; ReadabilityBot/1.0)",
  
  // Size limits
  MAX_HTML_SIZE: 5 * 1024 * 1024,      // 5MB for HTML
  MAX_FILE_SIZE: 10 * 1024 * 1024,     // 10MB for files (PDF, etc.)
  
  // Timeouts
  FETCH_TIMEOUT_MS: 10000,              // 10 seconds
  OEMBED_TIMEOUT_MS: 3000,              // 3 seconds for oEmbed
  
  // Redirect limits
  MAX_REDIRECTS: 3,
  
  // Rate limiting (per hour)
  RATE_LIMIT_PER_IP: 100,
  RATE_LIMIT_PER_DOMAIN: 60,            // per minute
  
  // Robots.txt cache TTL
  ROBOTS_CACHE_TTL: 24 * 60 * 60,       // 24 hours
  
  // Encoding
  REPLACEMENT_CHAR_THRESHOLD: 0.05,     // 5% threshold for bad encoding
  
  // Supported encodings by TextDecoder
  SUPPORTED_ENCODINGS: [
    'utf-8', 'utf-16', 'utf-16le', 'utf-16be',
    'iso-8859-1', 'iso-8859-2', 'iso-8859-15',
    'windows-1250', 'windows-1251', 'windows-1252', 'windows-1254',
    'koi8-r', 'koi8-u', 'macintosh'
  ]
};

// =============================================================================
// TYPES
// =============================================================================

export interface FetchResult {
  success: boolean;
  html?: string;
  url: string;                          // Final URL after redirects
  redirectChain: string[];
  charset?: string;
  contentType?: string;
  error?: FetchError;
}

export interface FetchError {
  code: FetchErrorCode;
  message: string;
}

export type FetchErrorCode = 
  | 'TIMEOUT'
  | 'SIZE_LIMIT'
  | 'PRIVATE_IP'
  | 'TOO_MANY_REDIRECTS'
  | 'REDIRECT_LOOP'
  | 'NETWORK_ERROR'
  | 'RATE_LIMITED'
  | 'ROBOTS_BLOCKED'
  | 'INVALID_URL'
  | 'ENCODING_ERROR'
  | 'HTTP_ERROR';

export interface FetchOptions {
  timeout?: number;
  maxSize?: number;
  followRedirects?: boolean;
  checkRobots?: boolean;
  userAgent?: string;
}

// =============================================================================
// PRIVATE IP DETECTION (SSRF Protection)
// =============================================================================

const PRIVATE_IP_RANGES = [
  // IPv4 Private Ranges
  /^10\./,                              // 10.0.0.0/8
  /^172\.(1[6-9]|2[0-9]|3[0-1])\./,    // 172.16.0.0/12
  /^192\.168\./,                        // 192.168.0.0/16
  /^127\./,                             // 127.0.0.0/8 (localhost)
  /^169\.254\./,                        // 169.254.0.0/16 (link-local)
  /^0\./,                               // 0.0.0.0/8
  
  // AWS/Cloud Metadata
  /^169\.254\.169\.254/,                // AWS metadata endpoint
  /^100\.(6[4-9]|[7-9][0-9]|1[0-2][0-7])\./,  // AWS VPC
  
  // IPv6 Private Ranges (simplified)
  /^::1$/,                              // localhost
  /^fe80:/i,                            // link-local
  /^fc00:/i,                            // unique local
  /^fd00:/i,                            // unique local
];

function isPrivateIP(hostname: string): boolean {
  return PRIVATE_IP_RANGES.some(range => range.test(hostname));
}

function isValidURL(urlString: string): { valid: boolean; url?: URL; error?: string } {
  try {
    const url = new URL(urlString);
    
    // Only allow http and https
    if (!['http:', 'https:'].includes(url.protocol)) {
      return { valid: false, error: 'Invalid protocol. Only HTTP(S) allowed.' };
    }
    
    // Check for private IP in hostname
    if (isPrivateIP(url.hostname)) {
      return { valid: false, error: 'Private IP addresses are not allowed.' };
    }
    
    return { valid: true, url };
  } catch {
    return { valid: false, error: 'Invalid URL format.' };
  }
}

// =============================================================================
// CHARSET DETECTION
// =============================================================================

function extractCharsetFromHeader(contentType: string | null): string | null {
  if (!contentType) return null;
  
  const match = contentType.match(/charset=["']?([^"';\s]+)/i);
  return match ? match[1].toLowerCase() : null;
}

function extractCharsetFromHTML(html: string): string | null {
  // Check <meta charset="...">
  const metaCharset = html.match(/<meta[^>]+charset=["']?([^"'>\s]+)/i);
  if (metaCharset) return metaCharset[1].toLowerCase();
  
  // Check <meta http-equiv="Content-Type" content="...; charset=...">
  const httpEquiv = html.match(/<meta[^>]+http-equiv=["']?Content-Type["']?[^>]+content=["']?[^"']*charset=([^"';\s]+)/i);
  if (httpEquiv) return httpEquiv[1].toLowerCase();
  
  // Alternative order
  const httpEquivAlt = html.match(/<meta[^>]+content=["']?[^"']*charset=([^"';\s]+)[^>]+http-equiv=["']?Content-Type/i);
  if (httpEquivAlt) return httpEquivAlt[1].toLowerCase();
  
  return null;
}

function normalizeCharset(charset: string): string {
  const mapping: Record<string, string> = {
    'iso-8859-9': 'windows-1254',       // Turkish
    'iso-8859-1': 'windows-1252',       // Western European
    'ascii': 'utf-8',
    'us-ascii': 'utf-8',
    'latin1': 'windows-1252',
    'latin-1': 'windows-1252',
  };
  
  return mapping[charset.toLowerCase()] || charset.toLowerCase();
}

function decodeWithCharset(buffer: ArrayBuffer, charset: string): { text: string; success: boolean } {
  const normalized = normalizeCharset(charset);
  
  try {
    const decoder = new TextDecoder(normalized, { fatal: false });
    const text = decoder.decode(buffer);
    
    // Check replacement character ratio
    const replacementCount = (text.match(/\uFFFD/g) || []).length;
    const ratio = replacementCount / text.length;
    
    if (ratio > CONFIG.REPLACEMENT_CHAR_THRESHOLD) {
      return { text, success: false };
    }
    
    return { text, success: true };
  } catch {
    // Fallback to UTF-8
    try {
      const decoder = new TextDecoder('utf-8', { fatal: false });
      return { text: decoder.decode(buffer), success: false };
    } catch {
      return { text: '', success: false };
    }
  }
}

// =============================================================================
// REDIS CLIENT (Lazy initialization)
// =============================================================================

let redisClient: Redis | null = null;

function getRedis(): Redis | null {
  if (redisClient) return redisClient;
  
  const url = Deno.env.get('UPSTASH_REDIS_REST_URL');
  const token = Deno.env.get('UPSTASH_REDIS_REST_TOKEN');
  
  if (!url || !token) {
    console.warn('⚠️ Upstash Redis not configured. Rate limiting disabled.');
    return null;
  }
  
  redisClient = new Redis({ url, token });
  return redisClient;
}

// =============================================================================
// RATE LIMITING
// =============================================================================

async function checkRateLimit(ip: string, domain: string): Promise<{ allowed: boolean; error?: FetchError }> {
  const redis = getRedis();
  if (!redis) return { allowed: true }; // Skip if Redis not configured
  
  try {
    const now = Math.floor(Date.now() / 1000);
    const hourKey = `ratelimit:ip:${ip}:${Math.floor(now / 3600)}`;
    const minuteKey = `ratelimit:domain:${domain}:${Math.floor(now / 60)}`;
    
    // Check IP rate limit (per hour)
    const ipCount = await redis.incr(hourKey);
    if (ipCount === 1) {
      await redis.expire(hourKey, 3600);
    }
    if (ipCount > CONFIG.RATE_LIMIT_PER_IP) {
      return { 
        allowed: false, 
        error: { code: 'RATE_LIMITED', message: 'IP rate limit exceeded. Try again later.' }
      };
    }
    
    // Check domain rate limit (per minute)
    const domainCount = await redis.incr(minuteKey);
    if (domainCount === 1) {
      await redis.expire(minuteKey, 60);
    }
    if (domainCount > CONFIG.RATE_LIMIT_PER_DOMAIN) {
      return { 
        allowed: false, 
        error: { code: 'RATE_LIMITED', message: 'Domain rate limit exceeded. Try again later.' }
      };
    }
    
    return { allowed: true };
  } catch (error) {
    console.error('Redis rate limit error:', error);
    return { allowed: true }; // Fail open if Redis errors
  }
}

// =============================================================================
// ROBOTS.TXT
// =============================================================================

interface RobotsRule {
  disallowed: string[];
  allowed: string[];
}

async function getRobotsRules(domain: string): Promise<RobotsRule | null> {
  const redis = getRedis();
  const cacheKey = `robots:${domain}`;
  
  // Check cache
  if (redis) {
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        return JSON.parse(cached as string);
      }
    } catch (error) {
      console.error('Redis robots cache error:', error);
    }
  }
  
  // Fetch robots.txt
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(`https://${domain}/robots.txt`, {
      signal: controller.signal,
      headers: { 'User-Agent': CONFIG.USER_AGENT }
    });
    
    clearTimeout(timeout);
    
    if (!response.ok) {
      return null; // No robots.txt = everything allowed
    }
    
    const text = await response.text();
    const rules = parseRobotsTxt(text);
    
    // Cache the rules
    if (redis) {
      try {
        await redis.setex(cacheKey, CONFIG.ROBOTS_CACHE_TTL, JSON.stringify(rules));
      } catch (error) {
        console.error('Redis robots cache set error:', error);
      }
    }
    
    return rules;
  } catch {
    return null; // Error fetching = assume allowed
  }
}

function parseRobotsTxt(text: string): RobotsRule {
  const rules: RobotsRule = { disallowed: [], allowed: [] };
  let isRelevantUserAgent = false;
  
  const lines = text.split('\n');
  
  for (const line of lines) {
    const trimmed = line.trim().toLowerCase();
    
    if (trimmed.startsWith('user-agent:')) {
      const agent = trimmed.replace('user-agent:', '').trim();
      isRelevantUserAgent = agent === '*' || agent.includes('readabilitybot');
    } else if (isRelevantUserAgent) {
      if (trimmed.startsWith('disallow:')) {
        const path = line.trim().replace(/^disallow:\s*/i, '').trim();
        if (path) rules.disallowed.push(path);
      } else if (trimmed.startsWith('allow:')) {
        const path = line.trim().replace(/^allow:\s*/i, '').trim();
        if (path) rules.allowed.push(path);
      }
    }
  }
  
  return rules;
}

function isPathAllowed(path: string, rules: RobotsRule): boolean {
  // Check allowed first (more specific)
  for (const allowedPath of rules.allowed) {
    if (path.startsWith(allowedPath)) return true;
  }
  
  // Check disallowed
  for (const disallowedPath of rules.disallowed) {
    if (disallowedPath === '/' || path.startsWith(disallowedPath)) {
      return false;
    }
  }
  
  return true;
}

// =============================================================================
// MAIN FETCH FUNCTION
// =============================================================================

export async function fetchURL(
  urlString: string, 
  options: FetchOptions = {},
  clientIP?: string
): Promise<FetchResult> {
  const {
    timeout = CONFIG.FETCH_TIMEOUT_MS,
    maxSize = CONFIG.MAX_HTML_SIZE,
    followRedirects = true,
    checkRobots = true,
    userAgent = CONFIG.USER_AGENT
  } = options;
  
  // Validate URL
  const validation = isValidURL(urlString);
  if (!validation.valid || !validation.url) {
    return {
      success: false,
      url: urlString,
      redirectChain: [],
      error: { code: 'INVALID_URL', message: validation.error || 'Invalid URL' }
    };
  }
  
  const url = validation.url;
  const domain = url.hostname;
  
  // Rate limiting
  if (clientIP) {
    const rateCheck = await checkRateLimit(clientIP, domain);
    if (!rateCheck.allowed) {
      return {
        success: false,
        url: urlString,
        redirectChain: [],
        error: rateCheck.error
      };
    }
  }
  
  // Robots.txt check
  if (checkRobots) {
    const rules = await getRobotsRules(domain);
    if (rules && !isPathAllowed(url.pathname, rules)) {
      return {
        success: false,
        url: urlString,
        redirectChain: [],
        error: { code: 'ROBOTS_BLOCKED', message: 'Blocked by robots.txt' }
      };
    }
  }
  
  // Fetch with redirect handling
  const redirectChain: string[] = [];
  const visitedUrls = new Set<string>();
  let currentUrl = urlString;
  
  for (let i = 0; i <= CONFIG.MAX_REDIRECTS; i++) {
    // Check for redirect loop
    if (visitedUrls.has(currentUrl)) {
      return {
        success: false,
        url: currentUrl,
        redirectChain,
        error: { code: 'REDIRECT_LOOP', message: 'Redirect loop detected' }
      };
    }
    visitedUrls.add(currentUrl);
    
    // Validate redirect URL
    const redirectValidation = isValidURL(currentUrl);
    if (!redirectValidation.valid) {
      return {
        success: false,
        url: currentUrl,
        redirectChain,
        error: { code: 'INVALID_URL', message: 'Invalid redirect URL' }
      };
    }
    
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);
      
      const response = await fetch(currentUrl, {
        signal: controller.signal,
        redirect: 'manual', // Handle redirects manually
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        }
      });
      
      clearTimeout(timeoutId);
      
      // Handle redirects
      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get('location');
        if (!location) {
          return {
            success: false,
            url: currentUrl,
            redirectChain,
            error: { code: 'HTTP_ERROR', message: 'Redirect without location header' }
          };
        }
        
        // Resolve relative URL
        const nextUrl = new URL(location, currentUrl).href;
        redirectChain.push(currentUrl);
        currentUrl = nextUrl;
        continue;
      }
      
      // Check for too many redirects
      if (i === CONFIG.MAX_REDIRECTS) {
        return {
          success: false,
          url: currentUrl,
          redirectChain,
          error: { code: 'TOO_MANY_REDIRECTS', message: `Exceeded ${CONFIG.MAX_REDIRECTS} redirects` }
        };
      }
      
      // Handle HTTP errors
      if (!response.ok) {
        return {
          success: false,
          url: currentUrl,
          redirectChain,
          error: { code: 'HTTP_ERROR', message: `HTTP ${response.status}: ${response.statusText}` }
        };
      }
      
      // Check Content-Length if available (Pre-flight check)
      const contentLength = response.headers.get('content-length');
      if (contentLength && parseInt(contentLength) > maxSize) {
        return {
          success: false,
          url: currentUrl,
          redirectChain,
          error: { code: 'SIZE_LIMIT', message: `Content too large: ${contentLength} bytes (max: ${maxSize})` }
        };
      }
      
      // Stream with size limit
      const contentType = response.headers.get('content-type');
      const headerCharset = extractCharsetFromHeader(contentType);
      
      // Read body with streaming size check
      const reader = response.body?.getReader();
      if (!reader) {
        return {
          success: false,
          url: currentUrl,
          redirectChain,
          error: { code: 'NETWORK_ERROR', message: 'No response body' }
        };
      }
      
      const chunks: Uint8Array[] = [];
      let totalSize = 0;
      
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        totalSize += value.length;
        if (totalSize > maxSize) {
          reader.cancel();
          return {
            success: false,
            url: currentUrl,
            redirectChain,
            error: { code: 'SIZE_LIMIT', message: `Content exceeded ${maxSize} bytes during download` }
          };
        }
        
        chunks.push(value);
      }
      
      // Combine chunks
      const buffer = new Uint8Array(totalSize);
      let offset = 0;
      for (const chunk of chunks) {
        buffer.set(chunk, offset);
        offset += chunk.length;
      }
      
      // Decode with charset detection
      let charset = headerCharset || 'utf-8';
      let decoded = decodeWithCharset(buffer.buffer, charset);
      
      // If decoding failed, try to detect from HTML meta tag
      if (!decoded.success && !headerCharset) {
        const tempDecoded = new TextDecoder('utf-8', { fatal: false }).decode(buffer);
        const metaCharset = extractCharsetFromHTML(tempDecoded);
        if (metaCharset && metaCharset !== 'utf-8') {
          decoded = decodeWithCharset(buffer.buffer, metaCharset);
          charset = metaCharset;
        }
      }
      
      return {
        success: true,
        html: decoded.text,
        url: currentUrl,
        redirectChain,
        charset,
        contentType: contentType || undefined
      };
      
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return {
          success: false,
          url: currentUrl,
          redirectChain,
          error: { code: 'TIMEOUT', message: `Request timed out after ${timeout}ms` }
        };
      }
      
      return {
        success: false,
        url: currentUrl,
        redirectChain,
        error: { code: 'NETWORK_ERROR', message: error instanceof Error ? error.message : 'Unknown error' }
      };
    }
  }
  
  // Should never reach here
  return {
    success: false,
    url: currentUrl,
    redirectChain,
    error: { code: 'NETWORK_ERROR', message: 'Unexpected error in fetch loop' }
  };
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

export function getClientIP(request: Request): string | undefined {
  // Try various headers for client IP (behind proxies)
  return request.headers.get('x-forwarded-for')?.split(',')[0].trim() ||
         request.headers.get('x-real-ip') ||
         request.headers.get('cf-connecting-ip') ||  // Cloudflare
         undefined;
}

export { CONFIG as FETCHER_CONFIG };
