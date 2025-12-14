import { ParsingStrategy, ParseResult } from "./base.ts";

export class AppleMusicStrategy implements ParsingStrategy {
  name = "Apple Music";

  matches(url: string): boolean {
    return /music\.apple\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Apple Music pages are well-structured with OpenGraph, but we want to ensure
      // we treat it as audio and generate an embed code if possible.
      // We'll fetch the page to get metadata.
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)"
        }
      });
      
      if (!response.ok) {
        throw new Error(`Apple Music fetch failed: ${response.status}`);
      }

      const html = await response.text();
      
      // Basic regex extraction for metadata since we don't have a DOM parser in Deno edge functions easily
      // without importing a library like cheerio or linkedom. 
      // For now, we'll use simple regex for key OG tags.
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`));
        return match ? match[1] : null;
      };

      const title = getMeta("og:title") || "Apple Music";
      const description = getMeta("og:description") || "";
      const image = getMeta("og:image");
      
      // Try to extract duration from HTML (Apple Music sometimes includes it in JSON-LD or meta)
      let readingTime = 5; // Default for audio/music
      try {
        // Look for duration in seconds in JSON-LD or meta tags
        const durationMatch = html.match(/"duration":\s*"?(\d+)"?/i) || 
                              html.match(/duration["']?\s*[:=]\s*["']?(\d+)/i) ||
                              html.match(/<meta[^>]+property=["']music:duration["'][^>]+content=["'](\d+)["']/i);
        if (durationMatch && durationMatch[1]) {
          const seconds = parseInt(durationMatch[1]);
          readingTime = Math.ceil(seconds / 60);
        }
      } catch (e) {
        // Ignore errors, use default
      }
      
      // Construct embed URL
      // Convert https://music.apple.com/us/album/... to https://embed.music.apple.com/us/album/...
      const embedUrl = url.replace("music.apple.com", "embed.music.apple.com");
      const iframe = `<iframe allow="autoplay *; encrypted-media *; fullscreen *; clipboard-write" frameborder="0" height="450" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="${embedUrl}"></iframe>`;

      return {
        type: "audio",
        title: title,
        excerpt: description,
        content_html: iframe,
        cover_image: image || null,
        reading_time_minutes: readingTime,
        domain: "music.apple.com",
        metadata: {
          platform: "apple_music",
          embed_url: embedUrl
        }
      };
    } catch (error) {
      console.error("Apple Music strategy failed:", error);
      throw error;
    }
  }
}
