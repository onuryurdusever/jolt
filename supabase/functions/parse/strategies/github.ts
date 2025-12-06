import { ParsingStrategy, ParseResult } from "./base.ts";

export class GitHubStrategy implements ParsingStrategy {
  name = "GitHub";

  matches(url: string): boolean {
    return /github\.com\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    try {
      // Handle repo URLs: github.com/owner/repo
      const repoMatch = url.match(/github\.com\/([^\/]+)\/([^\/]+)/);
      
      if (repoMatch && !url.includes("/issues/") && !url.includes("/pull/")) {
        const owner = repoMatch[1];
        const repo = repoMatch[2];
        const apiUrl = `https://api.github.com/repos/${owner}/${repo}`;
        
        const response = await fetch(apiUrl, {
          headers: { "User-Agent": "Mozilla/5.0 (compatible; ReadabilityBot/1.0)" }
        });
        
        if (response.ok) {
          const data = await response.json();
          return {
            type: "code",
            title: data.full_name,
            excerpt: data.description || "GitHub Repository",
            content_html: `<div class="github-repo"><h3>${data.full_name}</h3><p>${data.description}</p><p>⭐ ${data.stargazers_count} | 🍴 ${data.forks_count}</p></div>`,
            cover_image: data.owner.avatar_url,
            reading_time_minutes: 5,
            domain: "github.com",
            metadata: {
              platform: "github",
              stars: data.stargazers_count?.toString(),
              forks: data.forks_count?.toString(),
              language: data.language
            }
          };
        }
      }
      
      // Fallback for issues/PRs or if API fails
      // We can use a simple fetch and regex for OG tags as fallback
      // But for now, let's just return a basic structure if API fails
      // Or throw to let DefaultStrategy handle it? 
      // Actually, if we match the URL, we should handle it.
      
      return {
        type: "code",
        title: "GitHub",
        excerpt: "View on GitHub",
        content_html: `<a href="${url}">View on GitHub</a>`,
        cover_image: null,
        reading_time_minutes: 1,
        domain: "github.com",
        metadata: { platform: "github" }
      };

    } catch (error) {
      console.error("GitHub strategy failed:", error);
      throw error;
    }
  }
}
