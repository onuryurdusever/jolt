// Simple article extraction (without Mozilla Readability)
export function extractArticle(html: string, url: string) {
  try {
    // Extract title
    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i)
    const title = titleMatch ? titleMatch[1].trim() : ''

    // Extract main content (look for common article tags, ordered by specificity)
    let contentMatch = 
      // Semantic HTML5 tags
      html.match(/<article[^>]*>([\s\S]*?)<\/article>/i) ||
      html.match(/<main[^>]*>([\s\S]*?)<\/main>/i) ||
      // Common class patterns
      html.match(/<div[^>]*class="[^"]*\b(post-content|article-content|entry-content|post-body|article-body)\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i) ||
      html.match(/<div[^>]*class="[^"]*\bcontent\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i) ||
      html.match(/<div[^>]*class="[^"]*\bstory\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i) ||
      // ID patterns
      html.match(/<div[^>]*id="(content|main-content|article|post|story)"[^>]*>([\s\S]*?)<\/div>/i) ||
      // WordPress/Blog patterns
      html.match(/<div[^>]*class="[^"]*\bentry\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i) ||
      html.match(/<section[^>]*class="[^"]*\b(article|content|post)\b[^"]*"[^>]*>([\s\S]*?)<\/section>/i) ||
      // Fallback: look for the largest text block in body
      null;
    
    if (!contentMatch) {
      // Last resort: try to extract body content and find largest paragraph cluster
      const bodyMatch = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
      if (bodyMatch) {
        let body = bodyMatch[1];
        // Remove header, nav, footer, sidebar
        body = body.replace(/<(header|nav|footer|aside|sidebar)[^>]*>[\s\S]*?<\/\1>/gi, '');
        // Remove script and style
        body = body.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
        body = body.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
        body = body.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
        
        // Extract text content
        const textContent = body.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
        
        // If we have meaningful content, return it
        if (textContent.length > 200) {
          const excerpt = textContent.substring(0, 200) + (textContent.length > 200 ? '...' : '');
          return { title, content: body, textContent, excerpt };
        }
      }
      return null;
    }

    // Get the actual content (could be in group 1 or 2 depending on pattern)
    let content = contentMatch[2] || contentMatch[1];
    
    // Remove script and style tags
    content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    content = content.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '')
    
    // Extract text for excerpt
    const textContent = content.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
    const excerpt = textContent.substring(0, 200) + (textContent.length > 200 ? '...' : '')

    return { title, content, textContent, excerpt }
  } catch {
    return null
  }
}

// Scrape OpenGraph meta tags
export function scrapeMetaTags(html: string) {
  const getMetaContent = (pattern: RegExp) => {
    const match = html.match(pattern)
    return match ? match[1] : null
  }

  const title = getMetaContent(/<meta[^>]*property="og:title"[^>]*content="([^"]+)"/i) ||
                getMetaContent(/<meta[^>]*name="twitter:title"[^>]*content="([^"]+)"/i) ||
                getMetaContent(/<title[^>]*>([^<]+)<\/title>/i)

  const description = getMetaContent(/<meta[^>]*property="og:description"[^>]*content="([^"]+)"/i) ||
                     getMetaContent(/<meta[^>]*name="twitter:description"[^>]*content="([^"]+)"/i) ||
                     getMetaContent(/<meta[^>]*name="description"[^>]*content="([^"]+)"/i)

  const image = getMetaContent(/<meta[^>]*property="og:image"[^>]*content="([^"]+)"/i) ||
               getMetaContent(/<meta[^>]*name="twitter:image"[^>]*content="([^"]+)"/i)

  return { title, description, image }
}

// Extract cover image
export function extractCoverImage(html: string): string | null {
  const patterns = [
    /<meta[^>]*property="og:image"[^>]*content="([^"]+)"/i,
    /<meta[^>]*name="twitter:image"[^>]*content="([^"]+)"/i,
  ]

  for (const pattern of patterns) {
    const match = html.match(pattern)
    if (match) return match[1]
  }

  return null
}

// Estimate reading time
export function estimateReadingTime(text: string): number {
  if (!text) return 3 // Default 3 minutes when no content
  const wordsPerMinute = 200
  const wordCount = text.trim().split(/\s+/).length
  const minutes = Math.ceil(wordCount / wordsPerMinute)
  return Math.max(1, minutes)
}

// Sanitize title (remove unwanted characters, clean up)
export function sanitizeTitle(title: string | null): string {
  if (!title) return 'Untitled'
  
  // Remove common site suffixes (e.g., " - Site Name", " | Site Name")
  let cleaned = title.replace(/[\|\-–—]\s*[^\|\-–—]*$/, '').trim()
  
  // If cleaning removed everything, use original
  if (!cleaned) cleaned = title
  
  return cleaned
}

// Extract title from URL path (fallback when no title available)
export function extractTitleFromURL(url: string): string {
  try {
    const parsedURL = new URL(url)
    const path = parsedURL.pathname
    
    // Get the last meaningful segment
    const segments = path.split('/').filter(s => s.length > 0)
    if (segments.length === 0) return parsedURL.hostname
    
    let lastSegment = segments[segments.length - 1]
    
    // Remove file extensions
    lastSegment = lastSegment.replace(/\.[^.]+$/, '')
    
    // Replace dashes and underscores with spaces
    lastSegment = lastSegment.replace(/[-_]/g, ' ')
    
    // Capitalize words
    lastSegment = lastSegment
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ')
    
    return lastSegment || parsedURL.hostname
  } catch {
    return 'Untitled'
  }
}
