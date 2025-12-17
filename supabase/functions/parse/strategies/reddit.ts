import { ParsingStrategy, ParseResult } from "./base.ts";

export class RedditStrategy implements ParsingStrategy {
  name = "Reddit";

  matches(url: string): boolean {
    return /reddit\.com\//.test(url) || /redd\.it\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Reddit allows appending .json to get data
      // Use old.reddit.com as it often has less aggressive bot protection/rate limiting
      const urlObj = new URL(url);
      urlObj.hostname = "old.reddit.com";
      // Ensure path doesn't end in slash before appending .json
      let path = urlObj.pathname;
      if (path.endsWith("/")) {
        path = path.slice(0, -1);
      }
      urlObj.pathname = path + ".json";
      
      const jsonUrl = urlObj.toString();

      const response = await fetch(jsonUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
      });
      
      if (!response.ok) {
        throw new Error(`Reddit API failed: ${response.status}`);
      }

      const data = await response.json();
      // Reddit JSON structure is complex. Usually an array where first element is the post listing.
      const post = data[0]?.data?.children?.[0]?.data;

      if (!post) {
        throw new Error("Could not parse Reddit data");
      }

      const isVideo = post.is_video;
      const isImage = post.post_hint === "image";
      
      let contentHtml = post.selftext_html 
        ? post.selftext_html.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
        : "";

      if (isImage) {
        contentHtml = `<img src="${post.url}" alt="${post.title}" />` + contentHtml;
      } else if (isVideo && post.media?.reddit_video?.fallback_url) {
        contentHtml = `<video src="${post.media.reddit_video.fallback_url}" controls></video>` + contentHtml;
      } else if (post.url && !post.url.includes(post.permalink)) {
        // Link post
        contentHtml = `<a href="${post.url}" class="link-card">${post.url}</a>` + contentHtml;
      }

      return {
        type: isVideo ? "video" : (isImage ? "image" : "article"),
        title: post.title,
        excerpt: post.selftext ? post.selftext.substring(0, 200) + "..." : `Posted by u/${post.author} in r/${post.subreddit}`,
        content_html: contentHtml,
        cover_image: post.thumbnail !== "self" && post.thumbnail !== "default" ? post.thumbnail : undefined,
        reading_time_minutes: Math.ceil((post.selftext?.length || 0) / 1000) || 1,
        domain: "reddit.com",
        metadata: {
          platform: "reddit",
          subreddit: post.subreddit,
          author: post.author,
          upvotes: post.ups?.toString(),
          comments: post.num_comments?.toString()
        }
      };
    } catch (error) {
      console.error("Reddit strategy failed:", error);
      throw error;
    }
  }
}
