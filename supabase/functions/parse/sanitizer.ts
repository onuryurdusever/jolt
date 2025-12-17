/**
 * HTML Sanitizer
 * 
 * Cleans HTML content for safe rendering using REGEX (reliable, fast, no DOM parsing complexity)
 */

// =============================================================================
// CONFIGURATION
// ================================================================================

const IFRAME_WHITELIST = [
  'youtube.com', 'youtube-nocookie.com', 'youtu.be',
  'player.vimeo.com',
  'open.spotify.com',
  'w.soundcloud.com',
  'platform.twitter.com',
  'instagram.com',
  'tiktok.com' 
];

// =============================================================================
// TYPES
// =============================================================================

export interface SanitizeOptions {
  allowIframes?: boolean;
  iframeWhitelist?: string[];
  removeImages?: boolean;
}

export interface SanitizeResult {
  html: string;
  removedElements: {
    scripts: number;
    iframes: number;
    eventHandlers: number;
    dangerousUrls: number;
    forms: number;
    objects: number;
  };
  hasUnsafeContent: boolean;
}

// =============================================================================
// MAIN SANITIZER (Regex-based for reliability)
// =============================================================================

export function sanitizeHTML(html: string, options: SanitizeOptions = {}): SanitizeResult {
  const {
    allowIframes = true,
    iframeWhitelist = IFRAME_WHITELIST,
    removeImages = false,
  } = options;
  
  const stats = {
    scripts: 0,
    iframes: 0,
    eventHandlers: 0,
    dangerousUrls: 0,
    forms: 0,
    objects: 0
  };

  if (!html) return { html: '', removedElements: stats, hasUnsafeContent: false };
  
  let sanitized = html;
  
  // 1. Remove <script> tags
  const scriptMatches = sanitized.match(/<script[\s\S]*?<\/script>/gi);
  stats.scripts = scriptMatches?.length || 0;
  sanitized = sanitized.replace(/<script[\s\S]*?<\/script>/gi, '');
  sanitized = sanitized.replace(/<script[^>]*>/gi, '');
  
  // 2. Remove <noscript>
  sanitized = sanitized.replace(/<noscript[\s\S]*?<\/noscript>/gi, '');
  
  // 3. Remove <object>, <embed>, <applet>
  const objectMatches = sanitized.match(/<(object|embed|applet)[\s\S]*?<\/(object|embed|applet)>/gi);
  stats.objects = objectMatches?.length || 0;
  sanitized = sanitized.replace(/<(object|embed|applet)[\s\S]*?<\/(object|embed|applet)>/gi, '');
  sanitized = sanitized.replace(/<(object|embed|applet)[^>]*>/gi, '');
  
// 4. Remove event handlers (on*)
  const eventHandlerPattern = /\s+on\w+\s*=\s*["'][^"']*["']/gi;
  const eventMatches = sanitized.match(eventHandlerPattern);
  stats.eventHandlers = eventMatches?.length || 0;
  sanitized = sanitized.replace(eventHandlerPattern, '');
  sanitized = sanitized.replace(/\s+on\w+\s*=\s*[^\s>]+/gi, '');
  
  // 5. Remove dangerous URL schemes
  const jsUrlPattern = /\bhref\s*=\s*["']?\s*javascript:[^"'\s>]*/gi;
  const jsUrlMatches = sanitized.match(jsUrlPattern);
  stats.dangerousUrls += jsUrlMatches?.length || 0;
  sanitized = sanitized.replace(jsUrlPattern, 'href="#"');
  sanitized = sanitized.replace(/\bsrc\s*=\s*["']?\s*javascript:[^"'\s>]*/gi, 'src=""');
  
  // 6. Remove data: URLs (except safe images)
  sanitized = sanitized.replace(
    /\bsrc\s*=\s*["']data:(?!image\/(png|jpeg|jpg|gif|webp))[^"']*["']/gi,
    (match) => {
      stats.dangerousUrls++;
      return 'src=""';
    }
  );
  
  // 7. Harden links (add rel="noopener noreferrer")
  sanitized = sanitized.replace(
    /<a\s+([^>]*)>/gi,
    (match, attrs) => {
      if (!attrs.includes('rel=')) {
        return `<a ${attrs} rel="noopener noreferrer">`;
      }
      return match;
    }
  );
  
  // 8. Handle iframes
  if (allowIframes) {
    sanitized = sanitized.replace(
      /<iframe([^>]*)src=["']([^"']+)["']([^>]*)>/gi,
      (match, before, src, after) => {
        const isWhitelisted = iframeWhitelist.some(domain => src.includes(domain));
        if (isWhitelisted) {
          const hasSandbox = /sandbox/i.test(match);
          if (!hasSandbox) {
            return `<iframe${before}src="${src}"${after} sandbox="allow-scripts allow-same-origin allow-popups">`;
          }
          return match;
        }
        stats.iframes++;
        return `<!-- iframe removed: ${src} -->`;
      }
    );
  } else {
    const iframeMatches = sanitized.match(/<iframe[\s\S]*?<\/iframe>/gi);
    stats.iframes = iframeMatches?.length || 0;
    sanitized = sanitized.replace(/<iframe[\s\S]*?<\/iframe>/gi, '');
    sanitized = sanitized.replace(/<iframe[^>]*>/gi, '');
  }
  
  // 9. Optionally remove images
  if (removeImages) {
    sanitized = sanitized.replace(/<img[^>]*>/gi, '');
  }
  
  // 10. Remove forms
  const formMatches = sanitized.match(/<form[\s\S]*?<\/form>/gi);
  stats.forms = formMatches?.length || 0;
  sanitized = sanitized.replace(
    /<form([^>]*)>/gi,
    (match, attrs) => {
      return `<form${attrs.replace(/action\s*=\s*["'][^"']*["']/gi, 'action="#"')} onsubmit="return false;">`;
    }
  );
  
  // 11. Remove dangerous meta tags
  sanitized = sanitized.replace(/<meta[^>]*http-equiv\s*=\s*["']?refresh["']?[^>]*>/gi, '');
  sanitized = sanitized.replace(/<base[^>]*>/gi, '');

  const hasUnsafeContent = stats.scripts > 0 || stats.dangerousUrls > 0 || stats.objects > 0;

  return {
    html: sanitized,
    removedElements: stats,
    hasUnsafeContent
  };
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function getDomain(url: string): string {
  try {
    const parsed = new URL(url, 'https://example.com');
    return parsed.hostname;
  } catch {
    return 'unknown';
  }
}

/**
 * Light sanitization for metadata (titles, excerpts)
 * Removes HTML tags but keeps text content
 */
export function sanitizeText(text: string): string {
  return text
    .replace(/<[^>]+>/g, '') // Remove all HTML tags
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim();
}

/**
 * Sanitize URLs - remove tracking parameters
 */
export function sanitizeURL(url: string): string {
  try {
    const parsed = new URL(url);
    
    // Common tracking parameters to remove
    const trackingParams = [
      'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
      'fbclid', 'gclid', 'gclsrc', 'dclid',
      'mc_cid', 'mc_eid',
      '_ga', '_gl',
      'ref', 'ref_src', 'ref_url',
      'source', 'via',
      'at_medium', 'at_campaign',
      'spm', 'share_token',
      'spm', 'share_token',
      'si', 'feature', // Spotify, YouTube
      'token', 'access_token', 'auth', 'key', 'password' // Security Hardening
    ];
    
    for (const param of trackingParams) {
      parsed.searchParams.delete(param);
    }
    
    return parsed.toString();
  } catch {
    return url;
  }
}

/**
 * Add image error handler for broken images
 */
export function injectImageFallbackScript(): string {
  return `
<script>
document.querySelectorAll('img').forEach(function(img) {
  img.onerror = function() {
    this.onerror = null;
    this.style.opacity = '0.3';
    this.style.filter = 'grayscale(100%)';
    this.alt = 'Image could not be loaded';
    this.classList.add('broken-image');
  };
});
</script>
`;
}

/**
 * CSS for broken images
 */
export function getImageFallbackCSS(): string {
  return `
.broken-image {
  position: relative;
  min-height: 100px;
  background: #1a1a1a;
  border: 1px dashed #333;
}
.broken-image::after {
  content: '📷 Image unavailable';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  color: #666;
  font-size: 12px;
}
`;
}
