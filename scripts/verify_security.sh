#!/bin/bash

# Jolt Security Verification Script
# Usage: ./scripts/verify_security.sh <SUPABASE_ANON_KEY>

PROJECT_REF="vexxxtdbvtjttyaapfjf"
FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/parse"
ANON_KEY=$1

if [ -z "$ANON_KEY" ]; then
    echo "❌ Error: Missing Supabase Anon Key"
    echo "Usage: ./scripts/verify_security.sh <YOUR_ANON_KEY>"
    echo "You can find this in Supabase Dashboard -> Project Settings -> API"
    exit 1
fi

echo "🔒 Starting Security Probe on $FUNCTION_URL..."
echo "---------------------------------------------------"

# 1. Test Valid URL (Should Success)
echo "1️⃣  Testing Valid URL (example.com)..."
RESPONSE=$(curl -s -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}')

if echo "$RESPONSE" | grep -q "Example Domain"; then
    echo "✅ PASS: Valid URL fetched successfully."
else
    echo "⚠️  WARN: Valid URL failed. Response: $RESPONSE"
fi
echo ""

# 2. Test SSRF - Localhost (Should Block)
echo "2️⃣  Testing SSRF Attack (127.0.0.1)..."
RESPONSE=$(curl -s -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://127.0.0.1"}')

if echo "$RESPONSE" | grep -q "Private IP" || echo "$RESPONSE" | grep -q "SSRF"; then
    echo "✅ PASS: Localhost blocked successfully."
else
    echo "❌ FAIL: Localhost NOT blocked! Response: $RESPONSE"
fi
echo ""

# 3. Test SSRF - AWS Metadata (Should Block)
echo "3️⃣  Testing AWS Metadata Attack (169.254.169.254)..."
RESPONSE=$(curl -s -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://169.254.169.254"}')

if echo "$RESPONSE" | grep -q "Private IP" || echo "$RESPONSE" | grep -q "SSRF"; then
    echo "✅ PASS: AWS Metadata blocked successfully."
else
    echo "❌ FAIL: AWS Metadata NOT blocked! Response: $RESPONSE"
fi
echo ""

# 4. Test Port Scan (Should Block)
echo "4️⃣  Testing Port Restriction (port 8080)..."
RESPONSE=$(curl -s -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://example.com:8080"}')

if echo "$RESPONSE" | grep -q "Port restricted" || echo "$RESPONSE" | grep -q "Invalid URL"; then
    echo "✅ PASS: Port 8080 blocked successfully."
else
    echo "❌ FAIL: Port 8080 NOT blocked! Response: $RESPONSE"
fi

echo "---------------------------------------------------"
echo "Done."
