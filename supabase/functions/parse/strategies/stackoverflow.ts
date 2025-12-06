import { ParsingStrategy, ParseResult } from "./base.ts";

export class StackOverflowStrategy implements ParsingStrategy {
  name = "Stack Overflow";

  matches(url: string): boolean {
    return /stackoverflow\.com\/questions\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      const match = url.match(/questions\/([0-9]+)/);
      const id = match ? match[1] : null;

      if (!id) throw new Error("No Question ID found");

      const apiUrl = `https://api.stackexchange.com/2.3/questions/${id}?site=stackoverflow&filter=!9_bDDxJY5`; // filter includes body
      const response = await fetch(apiUrl);
      const data = await response.json();
      const question = data.items?.[0];

      if (!question) throw new Error("Question not found");

      return {
        type: "article", // or "code"
        title: question.title,
        excerpt: `Stack Overflow question by ${question.owner.display_name}`,
        content_html: question.body,
        cover_image: question.owner.profile_image,
        reading_time_minutes: 5,
        domain: "stackoverflow.com",
        metadata: {
          platform: "stackoverflow",
          score: question.score?.toString(),
          tags: question.tags?.join(","),
          is_answered: question.is_answered?.toString()
        }
      };
    } catch (error) {
      console.error("StackOverflow strategy failed:", error);
      throw error;
    }
  }
}
