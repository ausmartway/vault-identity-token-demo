#!/bin/bash

# Kong API Testing Script
# This script provides various test scenarios for Kong API Gateway

BASE_URL="http://localhost:8000"
ADMIN_URL="http://localhost:8001"
HOST_HEADER="api.local"

echo "🧪 Kong API Gateway Test Suite"
echo "================================"

# Function to test endpoint
test_endpoint() {
    local description="$1"
    local url="$2"
    local headers="$3"
    local expected_status="$4"
    
    echo ""
    echo "Testing: $description"
    echo "URL: $url"
    echo "Headers: $headers"
    
    if [ -n "$headers" ]; then
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Host: $HOST_HEADER" $headers "$url")
    else
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Host: $HOST_HEADER" "$url")
    fi
    
    status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_STATUS:/d')
    
    if [ "$status" = "$expected_status" ]; then
        echo "✅ PASS (Status: $status)"
    else
        echo "❌ FAIL (Expected: $expected_status, Got: $status)"
    fi
    
    if [ ${#body} -lt 500 ]; then
        echo "Response: $body"
    else
        echo "Response: [Large response truncated]"
    fi
    echo "---"
}

# Test 1: Unauthenticated request (should fail)
test_endpoint "Unauthenticated request" "$BASE_URL/api/get" "" "401"

# Test 2: Invalid JWT token (should fail)
test_endpoint "Invalid JWT token" "$BASE_URL/api/get" "-H \"Authorization: Bearer invalid.jwt.token\"" "401"

# Test 3: Get JWT credentials from Kong
echo ""
echo "🔑 Fetching JWT credentials from Kong..."
CONSUMER_JWT=$(curl -s "$ADMIN_URL/consumers/testuser/jwt")
JWT_KEY=$(echo $CONSUMER_JWT | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
JWT_SECRET=$(echo $CONSUMER_JWT | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)

if [ -n "$JWT_KEY" ] && [ -n "$JWT_SECRET" ]; then
    echo "✅ JWT credentials found"
    echo "Key: $JWT_KEY"
    echo "Secret: $JWT_SECRET"
    
    # Generate valid JWT token
    echo ""
    echo "🎫 Generating valid JWT token..."
    VALID_TOKEN=$(python3 -c "
import jwt
from datetime import datetime, timedelta
payload = {
    'iss': '$JWT_KEY',
    'exp': int((datetime.utcnow() + timedelta(hours=1)).timestamp()),
    'iat': int(datetime.utcnow().timestamp()),
    'sub': 'testuser',
    'role': 'user'
}
print(jwt.encode(payload, '$JWT_SECRET', algorithm='HS256'))
" 2>/dev/null)
    
    if [ -n "$VALID_TOKEN" ]; then
        echo "✅ Valid token generated"
        
        # Test 4: Valid JWT token (should succeed)
        test_endpoint "Valid JWT token" "$BASE_URL/api/get" "-H \"Authorization: Bearer $VALID_TOKEN\"" "200"
        
        # Test 5: Different endpoints with valid token
        test_endpoint "POST request with JWT" "$BASE_URL/api/post" "-H \"Authorization: Bearer $VALID_TOKEN\" -X POST -d '{\"test\":\"data\"}' -H \"Content-Type: application/json\"" "200"
        
        test_endpoint "User info endpoint" "$BASE_URL/api/user-agent" "-H \"Authorization: Bearer $VALID_TOKEN\"" "200"
        
        # Test 6: Expired token
        echo ""
        echo "🕒 Generating expired JWT token..."
        EXPIRED_TOKEN=$(python3 -c "
import jwt
from datetime import datetime, timedelta
payload = {
    'iss': '$JWT_KEY',
    'exp': int((datetime.utcnow() - timedelta(hours=1)).timestamp()),
    'iat': int(datetime.utcnow().timestamp()),
    'sub': 'testuser',
    'role': 'user'
}
print(jwt.encode(payload, '$JWT_SECRET', algorithm='HS256'))
" 2>/dev/null)
        
        test_endpoint "Expired JWT token" "$BASE_URL/api/get" "-H \"Authorization: Bearer $EXPIRED_TOKEN\"" "401"
        
    else
        echo "❌ Failed to generate JWT token"
    fi
else
    echo "❌ No JWT credentials found. Run setup-kong.sh first."
fi

# Test Kong Admin API
echo ""
echo "🔧 Testing Kong Admin API..."
test_endpoint "Kong status" "$ADMIN_URL/status" "" "200"
test_endpoint "List services" "$ADMIN_URL/services" "" "200"
test_endpoint "List routes" "$ADMIN_URL/routes" "" "200"

echo ""
echo "✅ Test suite completed!"
echo ""
echo "📋 Summary:"
echo "- Kong Admin API: http://localhost:8001"
echo "- Kong Manager: http://localhost:8002"
echo "- API Gateway: http://localhost:8000"
echo "- Test Backend: http://localhost:8080"
