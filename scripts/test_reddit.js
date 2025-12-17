const url = "https://www.reddit.com/r/apple/";
const targetJsonUrl = "https://www.reddit.com/r/apple.json";

// Logic to test
console.log(`Requesting: ${targetJsonUrl}`);

fetch(targetJsonUrl, {
    headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
})
.then(async res => {
    console.log(`Status: ${res.status}`);
    if (res.ok) {
        const data = await res.json();
        // Check structure
        const post = data[0]?.data?.children?.[0]?.data;
        if (post) {
            console.log("Title:", post.title);
            console.log("Subreddit:", post.subreddit_name_prefixed);
        } else {
            console.log("Structure mismatch:", JSON.stringify(data).slice(0, 200));
        }
    } else {
        console.log("Failed:", await res.text());
    }
})
.catch(console.error);
