import { ParsingStrategy, ParseResult } from "./base.ts";

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

      return {
        type: "social",
        title: `Tweet by ${data.author_name}`,
        excerpt: data.html.replace(/<[^>]+>/g, '').substring(0, 200), // Strip HTML for excerpt
        content_html: data.html,
        cover_image: null, // Twitter oEmbed doesn't provide image directly usually
        reading_time_minutes: 2,
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
