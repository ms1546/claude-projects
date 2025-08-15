#!/bin/bash

# ODPT API Test Script
# This script tests the ODPT API connection

echo "Testing ODPT API..."

# Check if ODPT_API_KEY is set
if [ -z "$ODPT_API_KEY" ]; then
    echo "❌ ERROR: ODPT_API_KEY environment variable is not set"
    echo "Please set it with: export ODPT_API_KEY='your-api-key'"
    exit 1
fi

echo "✅ ODPT_API_KEY is set"

# Test API endpoint - Search for Tokyo Station
echo ""
echo "Testing station search for '東京'..."
curl -s -X GET "https://api-tokyochallenge.odpt.org/api/v4/odpt:Station?acl:consumerKey=${ODPT_API_KEY}&dc:title=東京" | jq '.[0] | {title: .["dc:title"], railway: .["odpt:railway"], operator: .["odpt:operator"]}'

# Test API endpoint - Get JR Yamanote Line info
echo ""
echo "Testing railway info for JR Yamanote Line..."
curl -s -X GET "https://api-tokyochallenge.odpt.org/api/v4/odpt:Railway?acl:consumerKey=${ODPT_API_KEY}&owl:sameAs=odpt.Railway:JR-East.Yamanote" | jq '.[0] | {title: .["dc:title"], operator: .["odpt:operator"]}'

echo ""
echo "✅ API tests completed"