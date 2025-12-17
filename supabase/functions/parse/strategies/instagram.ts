import { ParsingStrategy, ParseResult } from "./base.ts";

export class InstagramStrategy implements ParsingStrategy {
  name = "Instagram";

  matches(url: string): boolean {
    return /instagram\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Extract ID
      // https://www.instagram.com/p/Code/
      // https://www.instagram.com/reel/Code/
      const match = url.match(/instagram\.com\/(?:p|reel|tv)\/([a-zA-Z0-9_-]+)/);
      const id = match ? match[1] : null;

      if (!id) {
        throw new Error("Could not extract Instagram ID");
      }

      const embedUrl = `https://www.instagram.com/p/${id}/embed`;
      const iframe = `<iframe src="${embedUrl}" width="400" height="480" frameborder="0" scrolling="no" allowtransparency="true"></iframe>`;

      // Try to fetch metadata via scraping
      // Instagram is hard to scrape, but sometimes we get lucky with OG tags
      let title = "Instagram Post";
      let excerpt = "View on Instagram";
      let author = "";
      let image = undefined;

      try {
        // Use Chrome UA to look like a real user
        const response = await fetch(url, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
          }
        });

        if (response.ok) {
          const html = await response.text();
          
          // Parse OG tags
          const getMeta = (name: string) => {
            const match = html.match(new RegExp(`<meta property="${name}" content="([^"]*)"`));
            return match ? this.decodeHtmlEntities(match[1]) : null;
          };

          const ogTitle = getMeta("og:title");
          const ogDesc = getMeta("og:description");
          const ogImage = getMeta("og:image");

          if (ogTitle && ogTitle !== "Instagram") {
            const userMatch = ogTitle.match(/(.*) \(@([^\)]+)\) on Instagram/);
            if (userMatch) {
              author = userMatch[2];
              const name = userMatch[1];
              title = `${name} (@${author})`;
            } else {
              title = ogTitle;
            }

            // Extract caption from title if present (after ": ")
            if (ogTitle.includes(": \"")) {
              excerpt = ogTitle.split(": \"")[1].replace(/"$/, "");
            } else if (ogDesc) {
              excerpt = ogDesc;
            }
          }

          if (ogImage) {
            image = ogImage;
          }
        }
      } catch (e) {
        console.warn("Failed to scrape Instagram metadata:", e);
      }

      return {
        type: "image", // Or video, but we treat IG as visual
        title: title,
        excerpt: excerpt,
        content_html: iframe,
        cover_image: image,
        reading_time_minutes: 1,
        domain: "instagram.com",
        metadata: {
          platform: "instagram",
          post_id: id,
          author_username: author
        }
      };
    } catch (error) {
      console.error("Instagram strategy failed:", error);
      throw error;
    }
  }

  private decodeHtmlEntities(text: string): string {
    if (!text) return "";
    return text
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(dec))
      .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  }
}
