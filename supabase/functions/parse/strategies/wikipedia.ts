import { ParsingStrategy, ParseResult } from "./base.ts";

export class WikipediaStrategy implements ParsingStrategy {
  name = "Wikipedia";

  matches(url: string): boolean {
    return /wikipedia\.org\/wiki\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Extract title from URL
      const match = url.match(/wiki\/([^#?]+)/);
      const title = match ? match[1] : null;

      if (!title) throw new Error("No Wikipedia title found");

      // Use REST API for summary
      // Need to handle language subdomain
      const langMatch = url.match(/([a-z]{2,3})\.wikipedia\.org/);
      const lang = langMatch ? langMatch[1] : "en";

      const apiUrl = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${title}`;
      const response = await fetch(apiUrl);
      
      if (!response.ok) throw new Error("Wikipedia API failed");

      const data = await response.json();

      return {
        type: "article",
        title: data.title,
        excerpt: data.extract,
        content_html: data.extract_html || `<p>${data.extract}</p>`,
        cover_image: data.thumbnail?.source,
        reading_time_minutes: 5, // Wikipedia articles vary, but summary is short
        domain: `${lang}.wikipedia.org`,
        metadata: {
          platform: "wikipedia",
          page_id: data.pageid?.toString()
        }
      };
    } catch (error) {
      console.error("Wikipedia strategy failed:", error);
      throw error;
    }
  }
}
