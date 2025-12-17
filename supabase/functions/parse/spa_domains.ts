/**
 * SPA Domain Denylist
 * 
 * Sites that require JavaScript to render content.
 * These bypass parsing and return webview with reason.
 */

const SPA_DOMAINS = new Set([
  // Twitter / X
  'twitter.com',
  'x.com',
  
  // Reddit (Moved to dedicated strategy)
  // 'reddit.com',
  // 'redd.it',
  
  // Note: Wikipedia is NOT in this list - it's parseable via static HTML
]);

/**
 * Check if a URL belongs to a SPA domain that requires JavaScript
 */
export function isSPADomain(url: string): boolean {
  try {
    const hostname = new URL(url).hostname.toLowerCase();
    
    // Check exact match or subdomain match
    for (const domain of SPA_DOMAINS) {
      if (hostname === domain || hostname.endsWith(`.${domain}`)) {
        return true;
      }
    }
    
    return false;
  } catch {
    return false;
  }
}

/**
 * Helper to get webview reason
 */
export function getSPAWebViewReason(url: string): string {
  return 'requires_javascript';
}

// Lightweight metadata extractor for SPA sites using Public APIs
export async function getSPAMetadata(url: string): Promise<{ title: string | null, cover_image: string | null }> {
  try {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname.toLowerCase();
    
    // 1. Twitter / X (Use oEmbed API)
    if (hostname.includes('twitter.com') || hostname.includes('x.com')) {
        const cleanLogUrl = urlObj.origin + urlObj.pathname; // Don't log query params
        console.log(`🐦 Fetching Twitter oEmbed for: ${cleanLogUrl}`);
        try {
            // Fix URL for oEmbed (publish.twitter.com handles both, but safer to use twitter.com)
            // Use fxtwitter structure to parse ID if needed, but publish.twitter.com should work with standard URL
            // IMPORTANT: Must provide User-Agent to avoid 400/403 from Twitter
            const oembedUrl = `https://publish.twitter.com/oembed?url=${encodeURIComponent(url)}`;
            console.log(`🐦 Requesting oEmbed for Twitter`);
            
            const response = await fetch(oembedUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                }
            });
            console.log(`🐦 oEmbed Status: ${response.status}`);
            
            if (response.ok) {
                const data = await response.json();
                console.log(`🐦 oEmbed Data: ${JSON.stringify(data)}`);
                
                // Format: "Elon Musk (@elonmusk) on X" or author_name + snippet
                if (data.author_name) {
                    // Extract text from HTML (simple strip) or just use author
                    // Prefer: "Elon Musk on X: 'Tweet content...'"
                    // But oEmbed text is often truncated. Let's use Author + "on X"
                    return { 
                        title: `${data.author_name} on X`, 
                        cover_image: null 
                    };
                }
            } else {
                console.log(`🐦 oEmbed Failed: ${await response.text()}`);
            }
        } catch (e) {
            console.error(`❌ Twitter oEmbed failed: ${e.message}`);
        }
    }
    
    // 2. Reddit (Use .json API)
    if (hostname.includes('reddit.com') || hostname.includes('redd.it')) {
        console.log(`🤖 Fetching Reddit JSON for: ${url}`);
        try {
            // Ensure no query params interfere, append .json
            // Ensure no query params interfere, append .json
            // Remove trailing slash if present to avoid double slash
            let cleanUrl = url.split('?')[0];
            if (cleanUrl.endsWith('/')) {
                cleanUrl = cleanUrl.slice(0, -1);
            }
            const jsonUrl = `${cleanUrl}.json`;
            console.log(`🤖 Fetching Reddit JSON: ${jsonUrl}`);
            
            const response = await fetch(jsonUrl, {
                headers: { 
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                let post = null;
                
                // DATA STRUCTURES:
                // 1. Post (Array): [{ kind: 'Listing', data: { children: [POST, ...] } }, { ...comments... }]
                // 2. Subreddit/Feed (Object): { kind: 'Listing', data: { children: [POST, ...] } }
                
                if (Array.isArray(data) && data.length > 0) {
                     // It's a Post
                     post = data[0]?.data?.children?.[0]?.data;
                } else if (data && data.kind === 'Listing' && data.data?.children?.length > 0) {
                     // It's a Subreddit (use first post to identify subreddit, or generic)
                     // Ideally we want the subreddit title, but standard JSON is just the feed.
                     // Let's use the subreddit name from the first post.
                     const firstChild = data.data.children[0].data;
                     if (firstChild.subreddit_name_prefixed) {
                         return { 
                             title: firstChild.subreddit_name_prefixed, // e.g. "r/apple"
                             cover_image: null 
                         };
                     }
                }
                
                if (post && post.title) {
                    let finalTitle = post.title;
                    // Add subreddit if available
                    if (post.subreddit_name_prefixed) {
                        finalTitle = `${post.subreddit_name_prefixed}: ${finalTitle}`;
                    }
                    
                    // Try to find image (thumbnail or preview)
                    let image = null;
                    if (post.thumbnail && post.thumbnail.startsWith('http')) {
                        image = post.thumbnail;
                    } else if (post.preview?.images?.[0]?.source?.url) {
                        image = post.preview.images[0].source.url.replace(/&amp;/g, '&');
                    }
                    
                    return { title: finalTitle, cover_image: image };
                }
            }
        } catch (e) {
            console.error(`❌ Reddit JSON failed: ${e.message}`);
        }
    }

    // 3. Generic Fallback (Scraping)
    console.log(`⚡️ Fetching generic SPA metadata for: ${url}`);
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3s timeout
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      },
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
        return { title: null, cover_image: null };
    }
    
    const html = await response.text();
    
    // Try og:title
    let title: string | null = null;
    const ogTitleMatch = html.match(/<meta\s+(?:property|name)=["']og:title["']\s+content=["'](.*?)["']/i);
    if (ogTitleMatch) title = ogTitleMatch[1];
    
    // Fallback to <title>
    if (!title) {
        const titleMatch = html.match(/<title>(.*?)<\/title>/i);
        if (titleMatch) title = titleMatch[1];
    }
    
    // Clean title
    if (title) {
        title = title
            .replace(/ \| X$/, '')
            .replace(/ \/ X$/, '')
            .replace(/ - Reddit$/, '')
            .replace(/&amp;/g, '&')
            .replace(/&quot;/g, '"')
            .replace(/&#x27;/g, "'")
            .trim();
    }
    
    // Try og:image
    let image: string | null = null;
    const ogImageMatch = html.match(/<meta\s+(?:property|name)=["']og:image["']\s+content=["'](.*?)["']/i);
    if (ogImageMatch) image = ogImageMatch[1].replace(/&amp;/g, '&');
    
    return { title, cover_image: image };
    
  } catch (e: any) {
    console.error(`❌ SPA metadata extraction failed: ${e.message}`);
    return { title: null, cover_image: null };
  }
}
