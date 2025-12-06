import { ParsingStrategy, ParseResult } from "./base.ts";

export class VimeoStrategy implements ParsingStrategy {
  name = "Vimeo";

  matches(url: string): boolean {
    return /vimeo\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://vimeo.com/api/oembed.json?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Vimeo oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      const domain = "vimeo.com";

      return {
        type: "video",
        title: data.title,
        excerpt: data.description || `Video by ${data.author_name}`,
        content_html: data.html,
        cover_image: data.thumbnail_url,
        reading_time_minutes: data.duration ? Math.ceil(data.duration / 60) : 10,
        domain: domain,
        metadata: {
          platform: "vimeo",
          video_id: data.video_id?.toString(),
          duration: data.duration?.toString(),
          author_name: data.author_name,
          width: data.width?.toString(),
          height: data.height?.toString()
        }
      };
    } catch (error) {
      console.error("Vimeo strategy failed:", error);
      throw error;
    }
  }
}
