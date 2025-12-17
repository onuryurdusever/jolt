#!/bin/bash

# Usage: ./scripts/debug_parser_live.sh <ANON_KEY>

PROJECT_REF="vexxxtdbvtjttyaapfjf"
FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/parse"
ANON_KEY=$1

if [ -z "$ANON_KEY" ]; then
    echo "❌ Missing Anon Key"
    exit 1
fi

test_url() {
    NAME=$1
    URL=$2
    echo "---------------------------------------------------"
    echo "Testing $NAME..."
    echo "URL: $URL"
    
    RESPONSE=$(curl -s -X POST $FUNCTION_URL \
      -H "Authorization: Bearer $ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"url\":\"$URL\"}")
    
    TYPE=$(echo "$RESPONSE" | grep -o '"type":"[^"]*"' | cut -d":" -f2 | tr -d '"')
    TITLE=$(echo "$RESPONSE" | grep -o '"title":"[^"]*"' | cut -d":" -f2 | tr -d '"')
    HTML_LEN=${#RESPONSE}
    
    echo "Type: $TYPE"
    echo "Title: $TITLE"
    
    # Check if content_html is null
    if echo "$RESPONSE" | grep -q '"content_html":null'; then
        echo "Content HTML: NULL ❌"
    else
        echo "Content HTML: Present ✅"
    fi
}

test_url "Wikipedia" "https://en.wikipedia.org/wiki/Artificial_intelligence"
test_url "Reddit" "https://www.reddit.com/r/technology/comments/18j0z5h/example_post/"
test_url "Medium" "https://medium.com/@ev/welcome-to-medium-9e53ca408c48"
test_url "Twitter" "https://twitter.com/elonmusk/status/1608273870901096454"
