/**
 * HTML Sanitizer
 * 
 * Cleans HTML content for safe rendering:
 * - Removes <script> tags
 * - Removes <iframe> tags (except whitelisted domains)
 * - Removes on* event handlers (onclick, onload, etc.)
 * - Removes javascript: URLs
 * - Removes <style> tags with @import (potential tracking)
 * - Removes data: URLs in images (potential XSS)
 * - Removes <object>, <embed>, <applet> tags
 * - Removes <form> action URLs to external domains
 */

// =============================================================================
// CONFIGURATION
// =============================================================================

const IFRAME_WHITELIST = [
  // Video platforms
  'youtube.com',
  'youtube-nocookie.com',
  'player.vimeo.com',
  'www.dailymotion.com',
  'player.twitch.tv',
  
  // Audio platforms
  'open.spotify.com',
  'w.soundcloud.com',
  'embed.music.apple.com',
  
  // Social embeds
  'platform.twitter.com',
  'www.instagram.com',
  'www.facebook.com',
  
  // Productivity
  'www.figma.com',
  'codepen.io',
  'codesandbox.io',
  'stackblitz.com',
  
  // Maps
  'www.google.com/maps',
  'maps.google.com',
  
  // Documents
  'docs.google.com',
  'onedrive.live.com',
];

// =============================================================================
// TYPES
// =============================================================================

export interface SanitizeOptions {
  allowIframes?: boolean;
  iframeWhitelist?: string[];
  removeImages?: boolean;
  maxImageCount?: number;
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
// MAIN SANITIZER
// =============================================================================

export function sanitizeHTML(html: string, options: SanitizeOptions = {}): SanitizeResult {
  const {
    allowIframes = true,
    iframeWhitelist = IFRAME_WHITELIST,
    removeImages = false,
    maxImageCount = 50
  } = options;
  
  const stats = {
    scripts: 0,
    iframes: 0,
    eventHandlers: 0,
    dangerousUrls: 0,
    forms: 0,
    objects: 0
  };
  
  let sanitized = html;
  
  // 1. Remove <script> tags and their content
  const scriptMatches = sanitized.match(/<script[\s\S]*?<\/script>/gi);
  stats.scripts = scriptMatches?.length || 0;
  sanitized = sanitized.replace(/<script[\s\S]*?<\/script>/gi, '');
  
  // Also remove <script ...> without closing tag
  sanitized = sanitized.replace(/<script[^>]*>/gi, '');
  
  // 2. Remove <noscript> tags (often used for tracking pixels)
  sanitized = sanitized.replace(/<noscript[\s\S]*?<\/noscript>/gi, '');
  
  // 3. Handle <iframe> tags
  if (allowIframes) {
    sanitized = sanitized.replace(
      /<iframe([^>]*)src=["']([^"']+)["']([^>]*)>/gi,
      (match, before, src, after) => {
        const isWhitelisted = iframeWhitelist.some(domain => 
          src.includes(domain) || src.startsWith('//')
        );
        
        if (isWhitelisted) {
          // Keep but add sandbox attribute for security
          const hasSandbox = /sandbox/i.test(match);
          if (!hasSandbox) {
            return `<iframe${before}src="${src}"${after} sandbox="allow-scripts allow-same-origin allow-popups">`;
          }
          return match;
        }
        
        stats.iframes++;
        return `<!-- iframe removed: ${getDomain(src)} -->`;
      }
    );
  } else {
    const iframeMatches = sanitized.match(/<iframe[\s\S]*?<\/iframe>/gi);
    stats.iframes = iframeMatches?.length || 0;
    sanitized = sanitized.replace(/<iframe[\s\S]*?<\/iframe>/gi, '');
    sanitized = sanitized.replace(/<iframe[^>]*>/gi, '');
  }
  
  // 4. Remove <object>, <embed>, <applet> tags
  const objectMatches = sanitized.match(/<(object|embed|applet)[\s\S]*?<\/(object|embed|applet)>/gi);
  stats.objects = objectMatches?.length || 0;
  sanitized = sanitized.replace(/<(object|embed|applet)[\s\S]*?<\/(object|embed|applet)>/gi, '');
  sanitized = sanitized.replace(/<(object|embed|applet)[^>]*>/gi, '');
  
  // 5. Remove on* event handlers from all tags
  const eventHandlerPattern = /\s+on\w+\s*=\s*["'][^"']*["']/gi;
  const eventMatches = sanitized.match(eventHandlerPattern);
  stats.eventHandlers = eventMatches?.length || 0;
  sanitized = sanitized.replace(eventHandlerPattern, '');
  
  // Also handle unquoted event handlers
  sanitized = sanitized.replace(/\s+on\w+\s*=\s*[^\s>]+/gi, '');
  
  // 6. Remove javascript: URLs
  const jsUrlPattern = /\bhref\s*=\s*["']?\s*javascript:[^"'\s>]*/gi;
  const jsUrlMatches = sanitized.match(jsUrlPattern);
  stats.dangerousUrls += jsUrlMatches?.length || 0;
  sanitized = sanitized.replace(jsUrlPattern, 'href="#"');
  
  // Also in src attributes
  sanitized = sanitized.replace(/\bsrc\s*=\s*["']?\s*javascript:[^"'\s>]*/gi, 'src=""');
  
  // 7. Remove data: URLs in images (potential XSS via SVG)
  // Keep data:image/png, data:image/jpeg, data:image/gif, data:image/webp
  sanitized = sanitized.replace(
    /\bsrc\s*=\s*["']data:(?!image\/(png|jpeg|jpg|gif|webp))[^"']*["']/gi,
    (match) => {
      stats.dangerousUrls++;
      return 'src=""';
    }
  );
  
  // 8. Remove vbscript: URLs (IE legacy)
  sanitized = sanitized.replace(/\bhref\s*=\s*["']?\s*vbscript:[^"'\s>]*/gi, 'href="#"');
  
  // 9. Remove <form> tags or neutralize them
  const formMatches = sanitized.match(/<form[\s\S]*?<\/form>/gi);
  stats.forms = formMatches?.length || 0;
  sanitized = sanitized.replace(
    /<form([^>]*)>/gi,
    (match, attrs) => {
      // Remove action attribute or change to #
      return `<form${attrs.replace(/action\s*=\s*["'][^"']*["']/gi, 'action="#"')} onsubmit="return false;">`;
    }
  );
  
  // 10. Remove <style> tags with @import (tracking/fingerprinting)
  sanitized = sanitized.replace(/<style[^>]*>[\s\S]*?@import[\s\S]*?<\/style>/gi, '');
  
  // 11. Remove tracking pixels (1x1 images)
  sanitized = sanitized.replace(
    /<img[^>]*(?:width\s*=\s*["']?1["']?[^>]*height\s*=\s*["']?1["']?|height\s*=\s*["']?1["']?[^>]*width\s*=\s*["']?1["']?)[^>]*>/gi,
    ''
  );
  
  // 12. Remove <base> tag (can redirect all relative URLs)
  sanitized = sanitized.replace(/<base[^>]*>/gi, '');
  
  // 13. Remove <meta http-equiv="refresh"> (auto-redirect)
  sanitized = sanitized.replace(/<meta[^>]*http-equiv\s*=\s*["']?refresh["']?[^>]*>/gi, '');
  
  // 14. Optionally limit image count
  if (maxImageCount > 0) {
    let imageCount = 0;
    sanitized = sanitized.replace(/<img[^>]*>/gi, (match) => {
      imageCount++;
      if (imageCount > maxImageCount) {
        return '<!-- image limit reached -->';
      }
      return match;
    });
  }
  
  // 15. Remove images entirely if requested
  if (removeImages) {
    sanitized = sanitized.replace(/<img[^>]*>/gi, '');
  }
  
  // 16. Remove SVG <use> tags with external references (potential SSRF)
  sanitized = sanitized.replace(/<use[^>]*href\s*=\s*["'](?!#)[^"']*["'][^>]*>/gi, '');
  
  // 17. Remove HTML comments (can contain IE conditional comments)
  sanitized = sanitized.replace(/<!--[\s\S]*?-->/g, '');
  
  const hasUnsafeContent = stats.scripts > 0 || 
                           stats.dangerousUrls > 0 || 
                           stats.objects > 0 ||
                           stats.eventHandlers > 5; // Some threshold
  
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
      'si', 'feature' // Spotify, YouTube
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
