import { ParsingStrategy, ParseResult } from "./base.ts";

export class YouTubeStrategy implements ParsingStrategy {
  name = "YouTube";

  matches(url: string): boolean {
    const pattern = /^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+$/;
    return pattern.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const domain = "youtube.com";
      let data: any = null;

      // 1. Try official oEmbed
      try {
        const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`;
        const response = await fetch(oembedUrl);
        if (response.ok) {
          data = await response.json();
        }
      } catch (e) {
        console.warn("YouTube official oEmbed failed, trying fallback:", e);
      }

      // 2. Fallback: Try noembed.com (often works when official one is strict)
      if (!data) {
        try {
          const noembedUrl = `https://noembed.com/embed?url=${encodeURIComponent(url)}`;
          const response = await fetch(noembedUrl);
          if (response.ok) {
            data = await response.json();
            if (data.error) data = null; // noembed returns 200 with error json sometimes
          }
        } catch (e) {
          console.warn("Noembed fallback failed:", e);
        }
      }

      // 3. Fallback: Manual scraping if oEmbeds fail
      if (!data) {
        console.warn("All oEmbeds failed, falling back to manual scraping");
        // Throwing error here will trigger the DefaultStrategy fallback in index.ts
        // which is better than returning a broken result
        throw new Error("YouTube oEmbeds failed");
      }

      // Extract video ID
      let videoId = "";
      if (url.includes("youtu.be/")) {
        videoId = url.split("youtu.be/")[1].split("?")[0];
      } else if (url.includes("v=")) {
        videoId = url.split("v=")[1].split("&")[0];
      }

      // 4. Try to get duration
      let durationMinutes = 10; // Default
      let durationStr = "";

      // Method A: YouTube Data API v3 (Official, Compliant, Primary)
      const apiKey = Deno.env.get("YOUTUBE_API_KEY");
      if (apiKey) {
        try {
          const apiUrl = `https://www.googleapis.com/youtube/v3/videos?id=${videoId}&part=contentDetails&key=${apiKey}`;
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout

          const response = await fetch(apiUrl, { signal: controller.signal });
          clearTimeout(timeoutId);

          if (response.ok) {
            const data = await response.json();
            if (data.items && data.items.length > 0 && data.items[0].contentDetails?.duration) {
              durationStr = data.items[0].contentDetails.duration;
              durationMinutes = this.parseDuration(durationStr);
              console.log(`✅ YouTube API v3: Got duration ${durationMinutes} min for ${videoId}`);
            }
          } else {
            console.warn(`YouTube API v3 error: ${response.status}`);
          }
        } catch (e) {
          console.warn("YouTube API v3 failed or timed out:", e);
        }
      } else {
        console.warn("YOUTUBE_API_KEY not set, skipping official API");
      }

      // Method B: Manual Scraping (Fallback if API fails or key not set)
      if (durationMinutes === 10) {
          try {
            // use a real desktop UA to look like a normal user
            const pageResponse = await fetch(url, {
              headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
                "Accept-Language": "en-US,en;q=0.9",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
              }
            });
            
            if (pageResponse.ok) {
              const html = await pageResponse.text();
              
              // Method 1: Look for lengthSeconds in JSON (ytInitialPlayerResponse)
              const lengthMatch = html.match(/"lengthSeconds":"(\d+)"/);
              // Method 2: approxDurationMs (often in microformat)
              const approxMatch = html.match(/"approxDurationMs":"(\d+)"/);
              
              let seconds = 0;

              if (lengthMatch && lengthMatch[1]) {
                seconds = parseInt(lengthMatch[1]);
              } else if (approxMatch && approxMatch[1]) {
                seconds = Math.floor(parseInt(approxMatch[1]) / 1000);
              } else {
                 // Method 3: Fallback to itemprop="duration"
                 const durationMatch = html.match(/itemprop="duration" content="([^"]+)"/);
                 if (durationMatch && durationMatch[1]) {
                   durationStr = durationMatch[1];
                   durationMinutes = this.parseDuration(durationStr);
                 }
              }

              if (seconds > 0) {
                 durationMinutes = Math.ceil(seconds / 60);
                 durationStr = `PT${Math.floor(seconds/60)}M${seconds%60}S`;
              }
            }
          } catch (e) {
            console.warn("Failed to scrape YouTube duration:", e);
          }
      }

      return {
        type: "video",
        title: data.title || "YouTube Video",
        excerpt: data.author_name ? `Video by ${data.author_name}` : null,
        content_html: data.html || null,
        cover_image: data.thumbnail_url || `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
        reading_time_minutes: durationMinutes,
        domain: domain,
        metadata: {
          platform: "youtube",
          video_id: videoId,
          author_name: data.author_name,
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
