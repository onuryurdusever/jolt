import { ParsingStrategy, ParseResult, createWebviewFallback } from "./base.ts";

/**
 * Jira Strategy - Protected Content
 * 
 * Jira tickets require authentication. We extract ticket ID from URL
 * and mark as protected. Content should be viewed in WebView.
 * 
 * Policy: Tier 3 (Protected) - Never process on server, client-side only
 */
export class JiraStrategy implements ParsingStrategy {
  name = "Jira";

  matches(url: string): boolean {
    return /atlassian\.net\/browse\//.test(url) || /jira\..*\/browse\//.test(url);
  }

  async parse(url: string): Promise<ParseResult> {
    // Extract ticket ID from URL
    const match = url.match(/browse\/([A-Z0-9]+-\d+)/);
    const ticketId = match ? match[1] : "Jira Ticket";
    
    // Extract domain
    let domain = "jira.atlassian.net";
    try {
      domain = new URL(url).hostname;
    } catch {}

    // Jira always requires authentication
    // Never attempt to fetch or process content
    return {
      type: "webview",
      title: ticketId,
      excerpt: "Jira Ticket - Login required to view",
      content_html: null, // Never store Jira content
      cover_image: undefined,
      reading_time_minutes: 0,
      domain: domain,
      metadata: {
        platform: "jira",
        ticket_id: ticketId
      },
      protected: true,
      fetchMethod: "webview",
      confidence: 0.3,
      error: {
        code: "LOGIN_REQUIRED",
        message: "Jira tickets require authentication",
        fallback: "webview"
      }
    };
  }
}
