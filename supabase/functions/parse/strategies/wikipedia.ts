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

      // Need to handle language subdomain
      const langMatch = url.match(/([a-z]{2,3})\.wikipedia\.org/);
      const lang = langMatch ? langMatch[1] : "en";

      // Use REST API for metadata (title, excerpt, image)
      const apiUrl = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${title}`;
      const response = await fetch(apiUrl);
      
      if (!response.ok) throw new Error("Wikipedia API failed");

      const data = await response.json();

      // Calculate reading time from word count if available
      const wordCount = data.extract?.split(/\s+/).length || 0;
      // Wikipedia articles are typically 5-30 mins, estimate based on topic complexity
      const readingTime = Math.max(5, Math.ceil(wordCount / 200) * 3);

      // IMPORTANT: Return type: webview because Summary API only gives first paragraph
      // The full article should be shown in WebView for complete reading experience
      return {
        type: "webview", // Changed from "article" to ensure full content is shown
        title: data.title,
        excerpt: data.extract,
        content_html: null, // Don't provide truncated content
        cover_image: data.thumbnail?.source,
        reading_time_minutes: readingTime,
        domain: `${lang}.wikipedia.org`,
        metadata: {
          platform: "wikipedia",
          page_id: data.pageid?.toString()
        },
        fetchMethod: "api",
        confidence: 0.9
      };
    } catch (error) {
      console.error("Wikipedia strategy failed:", error);
      throw error;
    }
  }
}
