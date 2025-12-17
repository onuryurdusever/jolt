import { parseHTML } from "npm:linkedom";
import { Readability } from "npm:@mozilla/readability@0.5.0";

// Article extraction using Mozilla Readability with LinkeDOM
export function extractArticle(html: string, url: string) {
  try {
    const { document } = parseHTML(html);
    
    if (!document) throw new Error("LinkeDOM parsing failed");

    // Add required location object for Readability to resolve relative URLs
    // @ts-ignore: Adding mock location to document
    document.location = new URL(url);

    const reader = new Readability(document);
    const article = reader.parse();

    if (!article) return null;

    return {
      title: article.title,
      content: article.content,
      textContent: article.textContent,
      excerpt: article.excerpt
    };
  } catch (error) {
    console.error("Readability parse error:", error);
    return null;
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
