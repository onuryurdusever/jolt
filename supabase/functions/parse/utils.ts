// Simple article extraction (without Mozilla Readability)
export function extractArticle(html: string, url: string) {
  try {
    // Extract title
    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i)
    const title = titleMatch ? titleMatch[1].trim() : ''

    // Extract main content (look for common article tags)
    const contentMatch = html.match(/<article[^>]*>([\s\S]*?)<\/article>/i) ||
                        html.match(/<main[^>]*>([\s\S]*?)<\/main>/i) ||
                        html.match(/<div[^>]*class="[^"]*content[^"]*"[^>]*>([\s\S]*?)<\/div>/i)
    
    if (!contentMatch) return null

    let content = contentMatch[1]
    
    // Remove script and style tags
    content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    
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
