import { ParsingStrategy } from "./base.ts";
import { YouTubeStrategy } from "./youtube.ts";
import { TwitterStrategy } from "./twitter.ts";
import { SpotifyStrategy } from "./spotify.ts";
import { VimeoStrategy } from "./vimeo.ts";
import { AppleMusicStrategy } from "./apple_music.ts";
import { TwitchStrategy } from "./twitch.ts";
import { TikTokStrategy } from "./tiktok.ts";
import { SoundCloudStrategy } from "./soundcloud.ts";
import { RedditStrategy } from "./reddit.ts";
import { LinkedInStrategy } from "./linkedin.ts";
import { InstagramStrategy } from "./instagram.ts";
import { FacebookStrategy } from "./facebook.ts";
import { MediumStrategy } from "./medium.ts";
import { SubstackStrategy } from "./substack.ts";
import { HackerNewsStrategy } from "./hackernews.ts";
import { GitHubStrategy } from "./github.ts";
import { StackOverflowStrategy } from "./stackoverflow.ts";
import { FigmaStrategy } from "./figma.ts";
import { NotionStrategy } from "./notion.ts";
import { TrelloStrategy } from "./trello.ts";
import { JiraStrategy } from "./jira.ts";
import { WikipediaStrategy } from "./wikipedia.ts";
import { AmazonStrategy } from "./amazon.ts";
import { IMDbStrategy } from "./imdb.ts";
import { PinterestStrategy } from "./pinterest.ts";
import { DefaultStrategy } from "./default.ts";

export class StrategyRegistry {
  private strategies: ParsingStrategy[] = [];

  constructor() {
    // Register strategies in order of specificity
    this.strategies.push(new YouTubeStrategy());
    this.strategies.push(new TwitterStrategy());
    this.strategies.push(new SpotifyStrategy());
    this.strategies.push(new VimeoStrategy());
    this.strategies.push(new AppleMusicStrategy());
    this.strategies.push(new TwitchStrategy());
    this.strategies.push(new TikTokStrategy());
    this.strategies.push(new SoundCloudStrategy());

    // Keep media strategies (they use APIs, SPA-safe)
    // Note: Twitter disabled - oEmbed unreliable, SPA domain routing handles it
    // this.strategies.push(new TwitterStrategy());
    
    // DISABLE text/social HTML strategies (most are SPA)
    this.strategies.push(new RedditStrategy());
    this.strategies.push(new LinkedInStrategy());
    this.strategies.push(new InstagramStrategy());
    this.strategies.push(new FacebookStrategy());
    this.strategies.push(new MediumStrategy());
    this.strategies.push(new SubstackStrategy());
    this.strategies.push(new HackerNewsStrategy());
    this.strategies.push(new GitHubStrategy());
    this.strategies.push(new StackOverflowStrategy());
    this.strategies.push(new FigmaStrategy());
    this.strategies.push(new NotionStrategy());
    this.strategies.push(new TrelloStrategy());
    this.strategies.push(new JiraStrategy());
    this.strategies.push(new WikipediaStrategy());
    this.strategies.push(new AmazonStrategy());
    this.strategies.push(new IMDbStrategy());
    this.strategies.push(new PinterestStrategy());
    
    // Default strategy must be last
    this.strategies.push(new DefaultStrategy());
  }

  getStrategy(url: string): ParsingStrategy {
    return this.strategies.find(s => s.matches(url)) || new DefaultStrategy();
  }
}
