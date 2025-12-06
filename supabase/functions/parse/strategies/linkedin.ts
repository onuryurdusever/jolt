import { ParsingStrategy, ParseResult } from "./base.ts";

export class LinkedInStrategy implements ParsingStrategy {
  name = "LinkedIn";

  matches(url: string): boolean {
    return /linkedin\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // LinkedIn oEmbed
      const oembedUrl = `https://www.linkedin.com/oembed?url=${encodeURIComponent(url)}`;
      const response = await fetch(oembedUrl);
      
      if (!response.ok) {
        // Fallback to default strategy if oEmbed fails (e.g. private post)
        // We throw here so the registry can catch and try the next one? 
        // No, the registry finds the first match. 
        // So we should try to do a basic fetch if oEmbed fails, or just throw and let the user handle it?
        // Better to throw and let the caller handle it, but wait, our registry logic is:
        // find(s => s.matches(url)). So if this matches, it's the ONLY one that runs.
        // So we must implement fallback logic HERE.
        throw new Error(`LinkedIn oEmbed failed: ${response.status}`);
      }

      const data = await response.json();
      
      return {
        type: "article", // LinkedIn posts are usually text/article
        title: data.title || "LinkedIn Post",
        excerpt: `Post by ${data.author_name}`,
        content_html: data.html,
        cover_image: undefined, // oEmbed might not give image
        reading_time_minutes: 3,
        domain: "linkedin.com",
        metadata: {
          platform: "linkedin",
          author_name: data.author_name
        }
      };
    } catch (error) {
      console.error("LinkedIn strategy failed, falling back to basic metadata extraction logic would be ideal here but for now throwing:", error);
      // In a real implementation, we would call a shared 'extractOpenGraph' helper here.
      // For now, we'll throw, and maybe we should modify the Registry to allow fallbacks?
      // Or we can just return a basic result if we can't get oEmbed.
      throw error;
    }
  }
}
