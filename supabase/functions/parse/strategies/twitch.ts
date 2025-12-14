import { ParsingStrategy, ParseResult } from "./base.ts";

export class TwitchStrategy implements ParsingStrategy {
  name = "Twitch";

  matches(url: string): boolean {
    return /twitch\.tv\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Twitch oEmbed endpoint
      const oembedUrl = `https://www.twitch.tv/services/oembed?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Twitch oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      // Calculate duration from oEmbed if available, otherwise default to 30 min for streams
      let readingTime = 30; // Default for live streams
      if (data.duration) {
        readingTime = Math.ceil(data.duration / 60); // Convert seconds to minutes
      }

      return {
        type: "video",
        title: data.title || "Twitch Stream",
        excerpt: `Watch ${data.author_name} on Twitch`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: readingTime,
        domain: "twitch.tv",
        metadata: {
          platform: "twitch",
          author_name: data.author_name,
          author_url: data.author_url,
          ...(data.duration && { duration_seconds: data.duration.toString() })
        }
      };
    } catch (error) {
      console.error("Twitch strategy failed:", error);
      throw error;
    }
  }
}
