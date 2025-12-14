import { ParsingStrategy, ParseResult } from "./base.ts";

export class TikTokStrategy implements ParsingStrategy {
  name = "TikTok";

  matches(url: string): boolean {
    return /tiktok\.com\/.*\/video\//.test(url) || /vm\.tiktok\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`TikTok oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      // Calculate duration from oEmbed if available, otherwise default to 1 min (typical TikTok length)
      let readingTime = 1; // Default (TikTok videos are typically short)
      if (data.duration) {
        readingTime = Math.ceil(data.duration / 60); // Convert seconds to minutes
      }

      return {
        type: "video",
        title: data.title || "TikTok Video",
        excerpt: `Video by ${data.author_name}`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: readingTime,
        domain: "tiktok.com",
        metadata: {
          platform: "tiktok",
          author_name: data.author_name,
          author_url: data.author_url,
          video_id: data.embed_product_id,
          ...(data.duration && { duration_seconds: data.duration.toString() })
        }
      };
    } catch (error) {
      console.error("TikTok strategy failed:", error);
      throw error;
    }
  }
}
