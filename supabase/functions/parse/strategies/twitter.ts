import { ParsingStrategy, ParseResult } from "./base.ts";
import { extractArticle } from "../utils.ts";

export class TwitterStrategy implements ParsingStrategy {
  name = "Twitter";

  matches(url: string): boolean {
    const pattern = /^(https?:\/\/)?(www\.)?(twitter\.com|x\.com)\/.+$/;
    return pattern.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Use publish.twitter.com for oEmbed
      const oembedUrl = `https://publish.twitter.com/oembed?url=${encodeURIComponent(url)}&omit_script=true`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        throw new Error(`Twitter oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      const domain = url.includes("x.com") ? "x.com" : "twitter.com";

      // Parse the HTML from oEmbed using our Readability-based extractor
      // We pass the original URL as context
      const article = extractArticle(data.html, url);

      return {
        type: "article", // CHANGED: Return 'article' so iOS uses ReaderView
        title: `Tweet by ${data.author_name}`,
        excerpt: article?.excerpt || data.html.replace(/<[^>]+>/g, '').substring(0, 200),
        content_html: article?.content || data.html, // Use parsed content if avail, else raw HTML
        cover_image: null,
        reading_time_minutes: 1, // Short read
        domain: domain,
        metadata: {
          platform: "twitter",
          author_name: data.author_name,
          author_url: data.author_url,
          provider_url: data.provider_url,
          tweet_id: url.split("/status/")[1]?.split("?")[0] || ""
        }
      };
    } catch (error) {
      console.error("Twitter strategy failed:", error);
      throw error;
    }
  }
}
