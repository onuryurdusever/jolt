import { ParsingStrategy, ParseResult } from "./base.ts";

export class FigmaStrategy implements ParsingStrategy {
  name = "Figma";

  matches(url: string): boolean {
    return /figma\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const oembedUrl = `https://www.figma.com/api/oembed?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Figma oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      return {
        type: "image", // Figma is visual
        title: data.title || "Figma Design",
        excerpt: `Design by ${data.author_name}`,
        content_html: data.html, // iframe
        cover_image: data.thumbnail_url,
        reading_time_minutes: 1,
        domain: "figma.com",
        metadata: {
          platform: "figma",
          author_name: data.author_name
        }
      };
    } catch (error) {
      console.error("Figma strategy failed:", error);
      throw error;
    }
  }
}
