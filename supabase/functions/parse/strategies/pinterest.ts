import { ParsingStrategy, ParseResult } from "./base.ts";

export class PinterestStrategy implements ParsingStrategy {
  name = "Pinterest";

  matches(url: string): boolean {
    return /pinterest\.com\/pin\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://www.pinterest.com/oembed.json?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Pinterest oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      return {
        type: "image",
        title: data.title || "Pinterest Pin",
        excerpt: `Pin by ${data.author_name}`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: 1,
        domain: "pinterest.com",
        metadata: {
          platform: "pinterest",
          author_name: data.author_name
        }
      };
    } catch (error) {
      console.error("Pinterest strategy failed:", error);
      throw error;
    }
  }
}
