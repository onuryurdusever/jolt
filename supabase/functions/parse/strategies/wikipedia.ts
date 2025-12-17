import { ParsingStrategy, ParseResult } from "./base.ts";
import { estimateReadingTime } from "../utils.ts";

/**
 * Wikipedia Strategy
 * 
 * Uses Wikipedia mobile-sections API to extract clean article content
 * without needing to scrape the HTML.
 */
export class WikipediaStrategy implements ParsingStrategy {
  name = "Wikipedia";

  matches(url: string): boolean {
    return /wikipedia\.org\/wiki\//.test(url);
  }

  async parse(url: string, html?: string): Promise<ParseResult> {
    try {
      // Extract title from URL
      const match = url.match(/wiki\/([^#?]+)/);
      const title = match ? decodeURIComponent(match[1]) : null;

      if (!title) throw new Error("No Wikipedia title found");

      // Need to handle language subdomain
      const langMatch = url.match(/([a-z]{2,3})\.wikipedia\.org/);
      const lang = langMatch ? langMatch[1] : "en";

      // Use mobile-sections API to get clean content
      const apiUrl = `https://${lang}.wikipedia.org/api/rest_v1/page/mobile-sections/${title}`;
      const response = await fetch(apiUrl);
      
      if (!response.ok) throw new Error("Wikipedia API failed");

      const data = await response.json();
      const lead = data.lead;
      
      // Build HTML from sections
      let contentHtml = `<h1>${lead.displaytitle || lead.normalizedtitle}</h1>`;
      
      // Add description if available
      if (lead.description) {
        contentHtml += `<p><em>${lead.description}</em></p>`;
      }
      
      // Add lead section text
      contentHtml += lead.sections?.[0]?.text || "";
      
      // Add remaining sections (limit to first 5 for performance)
      const remainingSections = data.remaining?.sections || [];
      for (let i = 0; i < Math.min(remainingSections.length, 5); i++) {
        const section = remainingSections[i];
        if (section.text) {
          contentHtml += `<h${section.toclevel + 1}>${section.line}</h${section.toclevel + 1}>`;
          contentHtml += section.text;
        }
      }

      return {
        type: "article",
        title: lead.displaytitle || lead.normalizedtitle,
        excerpt: lead.description || lead.extract,
        content_html: contentHtml,
        cover_image: lead.image?.urls?.["640"] || lead.thumbnail?.source,
        reading_time_minutes: estimateReadingTime(contentHtml.replace(/<[^>]+>/g, ' ')),
        domain: `${lang}.wikipedia.org`,
        metadata: {
          platform: "wikipedia",
          page_id: lead.id?.toString()
        },
        fetchMethod: "api",
        confidence: 1.0,
        robotsCompliant: true
      };
    } catch (error) {
      console.error("Wikipedia strategy failed:", error);
      throw error; // Let DefaultStrategy handle fallback
    }
  }
}
