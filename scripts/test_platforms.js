// Native fetch is available in Node 18+

// CONFIGURATION
const SUPABASE_URL = "https://vexxxtdbvtjttyaapfjf.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZleHh4dGRidnRqdHR5YWFwZmpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4ODM1NjcsImV4cCI6MjA4MDQ1OTU2N30.ofoLKSQis9OoEE-0qfMMdCVgbDKAp4TEdcvrLRmQOYs";
const PARSER_ENDPOINT = `${SUPABASE_URL}/functions/v1/parse`;

// TEST CASES (20 Platforms)
const TEST_CASES = [
    // BATCH 1: SOCIAL MEDIA
    { url: "https://www.instagram.com/p/C3_r6y_Lj5U/", expectedType: ["webview", "image"], name: "Instagram" },
    { url: "https://www.facebook.com/zuck/posts/10115655685243621", expectedType: ["webview", "article"], name: "Facebook" },
    { url: "https://www.tiktok.com/@tiktok/video/7296424541603581214", expectedType: ["webview", "video"], name: "TikTok" },
    { url: "https://www.linkedin.com/posts/satyanadella_openai-partnerships-activity-7132645678901234567-AbCd", expectedType: ["webview", "article"], name: "LinkedIn" },
    { url: "https://www.pinterest.com/pin/184084703512345678/", expectedType: ["webview", "image"], name: "Pinterest" },
    { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", expectedType: ["video"], name: "YouTube" },
    { url: "https://vimeo.com/76979871", expectedType: ["video"], name: "Vimeo" },
    { url: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT", expectedType: ["audio"], name: "Spotify" },
    { url: "https://music.apple.com/us/album/halo/205469036?i=205469041", expectedType: ["audio", "webview"], name: "Apple Music" },
    { url: "https://soundcloud.com/octobersveryown/drake-push-ups", expectedType: ["audio"], name: "SoundCloud" },
    { url: "https://github.com/swiftlang/swift", expectedType: ["article", "code"], name: "GitHub" },
    { url: "https://stackoverflow.com/questions/14415881/why-is-processing-a-sorted-array-faster-than-processing-an-unsorted-array", expectedType: ["article"], name: "StackOverflow" },
    { url: "https://www.figma.com/community/file/1035203688168086460", expectedType: ["webview", "design"], name: "Figma" },
    { url: "https://www.notion.so/blog/introducing-notion-ai", expectedType: ["webview", "article"], name: "Notion" },
    { url: "https://trello.com/b/nC8QJJoZ/trello-development-roadmap", expectedType: ["webview"], name: "Trello" },
    { url: "https://www.atlassian.com/software/jira", expectedType: ["webview", "article"], name: "Jira" }, // Jira is often marketing site or login
    { url: "https://medium.com/@ev/welcome-to-medium-9e53ca408c48", expectedType: ["article", "webview"], name: "Medium" },
    { url: "https://lenny.substack.com/p/how-to-hire-a-product-manager", expectedType: ["article", "webview"], name: "Substack" },
    { name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Artificial_intelligence", expectedType: ["webview", "article"] }, 
    { name: "IMDb", url: "https://www.imdb.com/title/tt0111161/", expectedType: ["webview", "article", "video"] },
    { name: "Amazon", url: "https://www.amazon.com/dp/B08F6CV6Z8", expectedType: "webview|product" }
];

async function runTests() {
    console.log("🚀 Starting Metadata Extraction Tests for 20 Platforms...\n");
    let passed = 0;
    let failed = 0;

    for (const test of TEST_CASES) {
        process.stdout.write(`Testing ${test.name.padEnd(15)} ... `);
        
        try {
            const response = await fetch(PARSER_ENDPOINT, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${SUPABASE_ANON_KEY}`
                },
                body: JSON.stringify({ url: test.url, skip_cache: true }) // FORCE NO CACHE
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${await response.text()}`);
            }

            const data = await response.json();
            
            // Validation Logic
            const hasTitle = data.title && data.title.length > 0 && data.title !== "null";
            const validTitle = hasTitle && !data.title.includes(data.domain) && data.title !== "x.com"; // Basic generic check
            const typeMatch = test.expectedType.includes(data.type);

            if (data.success && validTitle && typeMatch) {
                console.log(`✅ PASS [Title: "${data.title.substring(0, 30)}..." | Type: ${data.type}]`);
                passed++;
            } else {
                console.log(`❌ FAIL`);
                console.log(`   Expected Type: ${test.expectedType}, Got: ${data.type}`);
                console.log(`   Title: ${data.title}`);
                console.log(`   Error: ${JSON.stringify(data.error || "Validation Failed")}`);
                failed++;
            }

        } catch (error) {
            console.log(`🔥 ERROR: ${error.message}`);
            failed++;
        }
        // Small delay to simply be nice to the API
        await new Promise(r => setTimeout(r, 500));
    }

    console.log(`\n---------------------------------------------------`);
    console.log(`📊 RESULTS: ${passed}/${TEST_CASES.length} Passed`);
    console.log(`---------------------------------------------------`);
}

runTests();
