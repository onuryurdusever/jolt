
// Native fetch in Node 18+

const TARGETS = [
    { name: "Trello JSON", url: "https://trello.com/b/nC8QJJoZ/trello-development-roadmap.json" },
    { name: "Apple Music", url: "https://music.apple.com/us/album/halo/205469036?i=205469041" },
    { name: "Substack", url: "https://lennysnewsletter.com/p/how-to-hire-a-product-manager" }
];

const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

async function debug() {
    for (const t of TARGETS) {
        console.log(`\n🔍 Debugging ${t.name}: ${t.url}`);
        
        try {
            const res = await fetch(t.url, {
                headers: { 
                    "User-Agent": UA,
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }
            });
            console.log(`PROBE Status: ${res.status}`);
            
            if (res.ok) {
                const contentType = res.headers.get("content-type");
                if (contentType && contentType.includes("json")) {
                    const json = await res.json();
                    console.log("PROBE JSON Data:", JSON.stringify(json).substring(0, 200) + "...");
                } else {
                    const html = await res.text();
                    const title = html.match(/<title>(.*?)<\/title>/)?.[1];
                    console.log(`PROBE HTML Title: ${title}`);
                }
            }
        } catch (e) { console.log(`PROBE Error: ${e.message}`); }
    }
}

debug();
