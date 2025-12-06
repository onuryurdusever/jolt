// Jolt Parser Edge Function v3.0
// 
// Features:
// - Strategy Pattern for platform-specific parsing
// - Unified Fetcher with rate limiting, robots.txt, SSRF protection
// - HTML Sanitization for XSS prevention
// - Quality Gate for consent walls, paywalls, login detection
// - Upstash Redis for rate limiting and caching

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { StrategyRegistry } from "./strategies/index.ts"
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
    const { url, user_id } = await req.json()

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

    console.log(`📥 Parse request for: ${sanitizedUrl}`)
    
    // Get client IP for rate limiting
    const clientIP = getClientIP(req);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Check cache (24 hour TTL)
    const urlHash = await generateURLHash(sanitizedUrl)
    const expiryDate = new Date()
    expiryDate.setHours(expiryDate.getHours() - CACHE_TTL_HOURS)

    const { data: cached } = await supabase
      .from('parsed_cache')
      .select('*')
      .eq('url_hash', urlHash)
      .gt('created_at', expiryDate.toISOString())
      .single()

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

    // Parse content using Strategy Pattern
    const registry = new StrategyRegistry()
    const strategy = registry.getStrategy(sanitizedUrl)
    console.log(`🔍 Using strategy: ${strategy.name}`)
    
    const parsed = await strategy.parse(sanitizedUrl, undefined, clientIP)

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
