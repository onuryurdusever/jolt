import { ParsingStrategy, ParseResult } from "./base.ts";

export class SpotifyStrategy implements ParsingStrategy {
  name = "Spotify";

  matches(url: string): boolean {
    return url.includes("open.spotify.com");
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://open.spotify.com/oembed?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Spotify oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      const domain = "spotify.com";

      // Calculate duration from oEmbed if available, otherwise default
      let readingTime = 5; // Default
      if (data.duration) {
        readingTime = Math.ceil(data.duration / 60); // Convert seconds to minutes
      }

      return {
        type: "audio",
        title: data.title,
        excerpt: `Listen on Spotify`,
        content_html: data.html, // Embed iframe
        cover_image: data.thumbnail_url,
        reading_time_minutes: readingTime,
        domain: domain,
        metadata: {
          platform: "spotify",
          spotify_uri: url, // or extract from oEmbed if available
          thumbnail_url: data.thumbnail_url,
          provider_name: data.provider_name,
          ...(data.duration && { duration_seconds: data.duration.toString() })
        }
      };
    } catch (error) {
      console.error("Spotify strategy failed:", error);
      throw error;
    }
  }
}
