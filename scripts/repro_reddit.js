const SUPABASE_URL = "https://vexxxtdbvtjttyaapfjf.supabase.co";
const PARSER_ENDPOINT = `${SUPABASE_URL}/functions/v1/parse`;
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZleHh4dGRidnRqdHR5YWFwZmpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4ODM1NjcsImV4cCI6MjA4MDQ1OTU2N30.ofoLKSQis9OoEE-0qfMMdCVgbDKAp4TEdcvrLRmQOYs";

const target = "https://www.reddit.com/r/programming/comments/1y7h65/how_i_explained_rest_to_my_wife/";

async function test() {
    // Test oEmbed
    const oembedUrl = `https://www.reddit.com/oembed?url=${encodeURIComponent(target)}`;
    console.log(`Using oEmbed: ${oembedUrl}`);
    
    try {
        const res = await fetch(oembedUrl, {
            headers: {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
        });
        console.log(`Status: ${res.status}`);
        if(res.ok) {
            const json = await res.json();
            console.log("oEmbed Data:", JSON.stringify(json, null, 2));
        } else {
             console.log("oEmbed Failed");
        }
    } catch(e) { console.log(e); }

    // Also test Parser
    console.log(`\nTesting Parser: ${target}`);
    const res = await fetch(PARSER_ENDPOINT, {
        method: "POST",
        headers: { 
            "Content-Type": "application/json",
            "Authorization": `Bearer ${SUPABASE_ANON_KEY}`
        },
        body: JSON.stringify({ url: target, skip_cache: true })
    });
    
    const data = await res.json();
    console.log("Parser Result:", JSON.stringify(data, null, 2));
}

test();
