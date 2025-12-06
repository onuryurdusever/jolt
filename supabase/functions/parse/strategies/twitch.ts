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
      
      return {
        type: "video",
        title: data.title || "Twitch Stream",
        excerpt: `Watch ${data.author_name} on Twitch`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: 30, // Live streams are long
        domain: "twitch.tv",
        metadata: {
          platform: "twitch",
          author_name: data.author_name,
          author_url: data.author_url
        }
      };
    } catch (error) {
      console.error("Twitch strategy failed:", error);
      throw error;
    }
  }
}
