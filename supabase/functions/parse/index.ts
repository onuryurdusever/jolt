// Jolt Parser Edge Function v3.0
// 
// Features:
// - Strategy Pattern for platform-specific parsing
// - Unified Fetcher with rate limiting, robots.txt, SSRF protection
// - HTML Sanitization for XSS prevention
// - Quality Gate for consent walls, paywalls, login detection
// - Upstash Redis for rate limiting and caching

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { StrategyRegistry } from "./strategies/index.ts"
import { DefaultStrategy } from "./strategies/default.ts"
import { ParseResult } from "./strategies/base.ts"
import { getClientIP } from "./fetcher.ts"
import { sanitizeURL } from "./sanitizer.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Cache TTL: 24 hours (reduced from 7 days for copyright compliance)
const CACHE_TTL_HOURS = 24;

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { url, user_id, skip_cache } = await req.json()

    if (!url) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: { code: 'INVALID_URL', message: 'Missing required field: url' }
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate and sanitize URL
    let sanitizedUrl: string;
    try {
      const parsed = new URL(url);
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error('Invalid protocol');
      }
      sanitizedUrl = sanitizeURL(url);
    } catch {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: { code: 'INVALID_URL', message: 'Invalid URL format' }
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📥 Parse request for: ${sanitizedUrl} (skip_cache: ${!!skip_cache})`)
    
    // Get client IP for rate limiting
    const clientIP = getClientIP(req);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Check cache (24 hour TTL) - unless skipped
    const urlHash = await generateURLHash(sanitizedUrl)
    let cached = null;
    
    if (!skip_cache) {
      const expiryDate = new Date()
      expiryDate.setHours(expiryDate.getHours() - CACHE_TTL_HOURS)

      const { data } = await supabase
        .from('parsed_cache')
        .select('*')
        .eq('url_hash', urlHash)
        .gt('created_at', expiryDate.toISOString())
        .single()
        
      cached = data;
    }

    if (cached) {
      // CACHE HEALING: Aggressive
      // If cached result is for an SPA domain and has a generic title, FORCE INVALIDATION.
      // We don't rely on fetch_method here because old cached rows might not have it.
      
      const domain = (cached.domain || "").toLowerCase();
      const title = (cached.title || "").toLowerCase();
      
      const isSPADomain = domain.includes('x.com') || 
                          domain.includes('twitter.com') || 
                          domain.includes('reddit.com');
                          
      const isGenericTitle = title === domain || 
                             ['x.com', 'twitter.com', 'reddit.com', 'x', 'twitter', 'reddit'].includes(title);
      
      if (isSPADomain && isGenericTitle) {
        console.log(`♻️ Cache invalidation: Generic title '${cached.title}' for SPA '${domain}'. Re-fetching.`);
        cached = null;
      }
    }

    if (cached) {
      console.log(`✅ Cache hit for: ${sanitizedUrl}`)
      return new Response(
        JSON.stringify({ 
          ...cached, 
          cached: true,
          success: true 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // EARLY CHECK: SPA Domain Routing
    // Sites that require JavaScript get "Original View" (webview) intentionally
    const { isSPADomain, getSPAWebViewReason, getSPAMetadata } = await import('./spa_domains.ts');
    
    if (isSPADomain(sanitizedUrl)) {
      const domain = new URL(sanitizedUrl).hostname;
      const webviewReason = getSPAWebViewReason(sanitizedUrl);
      
      console.log(`🌐 SPA domain detected: ${domain} → Original View (${webviewReason})`);
      
      // Fetch metadata (title/image) lightly
      const { title, cover_image } = await getSPAMetadata(sanitizedUrl);
      
      const spaResult: ParseResult = {
        type: 'webview',
        title: title || domain, // Use domain as fallback
        excerpt: null,
        content_html: null,
        cover_image: cover_image,
        reading_time_minutes: 0,
        domain,
        metadata: null,
        fetchMethod: 'spa-bypass',
        confidence: 1.0,
        webviewReason,
        finalUrl: sanitizedUrl,
        robotsCompliant: true
      };
      
      // Cache SPA bypass result too (avoid redundant checks)
      await supabase.from('parsed_cache').insert({
        url_hash: urlHash,
        ...spaResult
      });
      
      return new Response(
        JSON.stringify({ ...spaResult, success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse content using Strategy Pattern
    const registry = new StrategyRegistry()
    const strategy = registry.getStrategy(sanitizedUrl)
    console.log(`🔍 Using strategy: ${strategy.name}`)

    
    let parsed: ParseResult;
    try {
      parsed = await strategy.parse(sanitizedUrl, undefined, clientIP, user_id)
    } catch (e) {
      // If a specific strategy fails, fallback to Default strategy
      // This ensures we always try to get at least some metadata (title, image)
      if (strategy.name !== 'Default') {
        console.warn(`⚠️ Strategy ${strategy.name} failed (${e instanceof Error ? e.message : 'Unknown'}), falling back to Default strategy`);
        const defaultStrategy = new DefaultStrategy();
        parsed = await defaultStrategy.parse(sanitizedUrl, undefined, clientIP, user_id);
      } else {
        throw e; // If Default fails, we really failed
      }
    }

    // Fallback to favicon if no cover image
    if (!parsed.cover_image) {
      const domain = parsed.domain || new URL(sanitizedUrl).hostname;
      parsed.cover_image = `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
      console.log(`🖼️ Using favicon fallback for cover image`);
    }

    // Prepare cache data
    const cacheData = {
      url_hash: urlHash,
      original_url: sanitizedUrl,
      type: parsed.type,
      title: parsed.title,
      excerpt: parsed.excerpt,
      content_html: parsed.content_html,
      cover_image: parsed.cover_image,
      reading_time_minutes: parsed.reading_time_minutes,
      domain: parsed.domain,
      created_at: new Date().toISOString(),
      metadata: parsed.metadata,
      // New v3.0 fields
      protected: parsed.protected || false,
      paywalled: parsed.paywalled || false,
      fetch_method: parsed.fetchMethod || 'readability',
      confidence: parsed.confidence || 0.5
    }

    // Save to cache (don't await - fire and forget)
    supabase.from('parsed_cache').upsert(cacheData).then(({ error }) => {
      if (error) console.error('Cache save error:', error);
    });

    console.log(`✅ Parsed: ${sanitizedUrl} (type: ${parsed.type}, method: ${parsed.fetchMethod}, confidence: ${parsed.confidence?.toFixed(2)})`)

    // Build response
    const response = {
      success: true,
      cached: false,
      ...parsed
    };

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Parse error:', error)
    
    // Determine error type
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorCode = errorMessage.includes('timeout') ? 'TIMEOUT' :
                      errorMessage.includes('network') ? 'NETWORK_ERROR' :
                      'PARSE_FAILED';
    
    return new Response(
      JSON.stringify({ 
        success: false,
        error: { 
          code: errorCode, 
          message: errorMessage,
          fallback: 'webview'
        }
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Generate SHA-256 hash for URL
async function generateURLHash(url: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(url)
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}
