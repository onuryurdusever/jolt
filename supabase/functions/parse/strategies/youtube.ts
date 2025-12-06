import { ParsingStrategy, ParseResult } from "./base.ts";

export class YouTubeStrategy implements ParsingStrategy {
  name = "YouTube";

  matches(url: string): boolean {
    const pattern = /^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+$/;
    return pattern.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // 1. Get basic metadata from oEmbed (reliable for title, author, embed code)
      const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`;
      const oembedResponse = await fetch(oembedUrl);
      
      if (!oembedResponse.ok) {
        throw new Error(`YouTube oEmbed failed: ${oembedResponse.status}`);
      }

      const data = await oembedResponse.json();
      const domain = "youtube.com";

      // Extract video ID
      let videoId = "";
      if (url.includes("youtu.be/")) {
        videoId = url.split("youtu.be/")[1].split("?")[0];
      } else if (url.includes("v=")) {
        videoId = url.split("v=")[1].split("&")[0];
      }

      // 2. Try to get duration by scraping the page
      // YouTube pages contain <meta itemprop="duration" content="PT24M10S">
      let durationMinutes = 10; // Default
      let durationStr = "";

      try {
        // Note: We use honest UA. Duration scraping may fail - that's acceptable.
        // oEmbed provides reliable title/author. Duration is optional.
        const pageResponse = await fetch(url, {
          headers: {
            "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)",
            "Accept-Language": "en-US,en;q=0.9"
          }
        });
        
        if (pageResponse.ok) {
          const html = await pageResponse.text();
          
          // Method 1: Look for lengthSeconds in JSON (ytInitialPlayerResponse)
          // This is often more reliable as it's part of the player config
          const lengthMatch = html.match(/"lengthSeconds":"(\d+)"/);
          
          if (lengthMatch && lengthMatch[1]) {
            const seconds = parseInt(lengthMatch[1]);
            durationMinutes = Math.ceil(seconds / 60);
            // Construct ISO string for metadata
            const h = Math.floor(seconds / 3600);
            const m = Math.floor((seconds % 3600) / 60);
            const s = seconds % 60;
            durationStr = `PT${h}H${m}M${s}S`;
            console.log(`✅ Found duration via lengthSeconds: ${seconds}s (${durationMinutes}m)`);
          } else {
            // Method 2: Fallback to itemprop="duration"
            const durationMatch = html.match(/itemprop="duration" content="([^"]+)"/);
            if (durationMatch && durationMatch[1]) {
              durationStr = durationMatch[1]; // e.g., PT24M10S
              durationMinutes = this.parseDuration(durationStr);
              console.log(`✅ Found duration via itemprop: ${durationStr}`);
            } else {
              console.log("⚠️ Could not find duration in YouTube page");
            }
          }
        }
      } catch (e) {
        console.warn("Failed to scrape YouTube duration:", e);
      }

      return {
        type: "video",
        title: data.title,
        excerpt: `Video by ${data.author_name}`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: durationMinutes,
        domain: domain,
        metadata: {
          platform: "youtube",
          video_id: videoId,
          author_name: data.author_name,
          author_url: data.author_url,
          provider_url: data.provider_url,
          thumbnail_height: data.thumbnail_height?.toString(),
          thumbnail_width: data.thumbnail_width?.toString(),
          duration_iso: durationStr
        }
      };
    } catch (error) {
      console.error("YouTube strategy failed:", error);
      throw error; // Let the fallback handle it
    }
  }

  private parseDuration(duration: string): number {
    // Parse ISO 8601 duration (PT1H2M10S)
    const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
    if (!match) return 10;

    const hours = parseInt(match[1] || "0");
    const minutes = parseInt(match[2] || "0");
    const seconds = parseInt(match[3] || "0");

    let totalMinutes = (hours * 60) + minutes;
    if (seconds > 30) totalMinutes += 1;
    
    return totalMinutes > 0 ? totalMinutes : 1;
  }
}
