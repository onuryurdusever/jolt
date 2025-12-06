import { ParsingStrategy, ParseResult } from "./base.ts";

export class HackerNewsStrategy implements ParsingStrategy {
  name = "Hacker News";

  matches(url: string): boolean {
    return /news\.ycombinator\.com\/item/.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const match = url.match(/id=([0-9]+)/);
      const id = match ? match[1] : null;

      if (!id) throw new Error("No HN ID found");

      const response = await fetch(`https://hacker-news.firebaseio.com/v0/item/${id}.json`);
      const data = await response.json();

      return {
        type: "article",
        title: data.title,
        excerpt: `Hacker News discussion with ${data.descendants} comments`,
        content_html: data.text || `<a href="${data.url}">${data.title}</a>`,
        cover_image: undefined,
        reading_time_minutes: 2,
        domain: "news.ycombinator.com",
        metadata: {
          platform: "hackernews",
          author: data.by,
          score: data.score?.toString(),
          comments: data.descendants?.toString()
        }
      };
    } catch (error) {
      console.error("HN strategy failed:", error);
      throw error;
    }
  }
}
