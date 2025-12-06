import { ParsingStrategy, ParseResult } from "./base.ts";

export class IMDbStrategy implements ParsingStrategy {
  name = "IMDb";

  matches(url: string): boolean {
    return /imdb\.com\/title\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)"
        }
      });
      
      if (!response.ok) throw new Error("IMDb fetch failed");
      
      const html = await response.text();
      
      const getMeta = (name: string) => {
        const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`));
        return match ? match[1] : null;
      };

      return {
        type: "video", // Movie/TV Show
        title: getMeta("og:title") || "IMDb Title",
        excerpt: getMeta("og:description") || "",
        content_html: `<a href="${url}">View on IMDb</a>`,
        cover_image: getMeta("og:image") || undefined,
        reading_time_minutes: 2, // Reading the page
        domain: "imdb.com",
        metadata: {
          platform: "imdb"
        }
      };
    } catch (error) {
      console.error("IMDb strategy failed:", error);
      throw error;
    }
  }
}
