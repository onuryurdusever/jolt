import { ParsingStrategy, ParseResult } from "./base.ts";

export class SoundCloudStrategy implements ParsingStrategy {
  name = "SoundCloud";

  matches(url: string): boolean {
    return /soundcloud\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://soundcloud.com/oembed?format=json&url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`SoundCloud oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      // Calculate duration from oEmbed if available, otherwise default
      let readingTime = 5; // Default
      if (data.duration) {
        readingTime = Math.ceil(data.duration / 60); // Convert seconds to minutes
      }

      return {
        type: "audio",
        title: data.title,
        excerpt: data.description || `Listen to ${data.title} by ${data.author_name}`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: readingTime,
        domain: "soundcloud.com",
        metadata: {
          platform: "soundcloud",
          author_name: data.author_name,
          author_url: data.author_url,
          ...(data.duration && { duration_seconds: data.duration.toString() })
        }
      };
    } catch (error) {
      console.error("SoundCloud strategy failed:", error);
      throw error;
    }
  }
}
