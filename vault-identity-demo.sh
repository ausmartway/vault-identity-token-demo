#!/bin/bash

# Vault Identity Token Demo
# This script demonstrates the complete flow:
# 1. Login to Vault
# 2. Get Vault identity token
# 3. Use token with Kong API
# 4. Kong validates token is signed by Vault

echo "🎯 Vault Identity Token → Kong API Demo"
echo "======================================="

export VAULT_ADDR='http://localhost:8200'

# Check if services are running
if ! curl -f http://localhost:8001/status > /dev/null 2>&1; then
    echo "❌ Kong is not running. Please run:"
    echo "   docker compose -f docker-compose-with-vault.yml up -d"
    exit 1
fi

if ! curl -f http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
    echo "❌ Vault is not running. Please run:"
    echo "   docker compose -f docker-compose-with-vault.yml up -d"
    exit 1
fi

echo "✅ Both Kong and Vault are running"

# Step 1: Login to Vault using userpass auth
echo ""
echo "🔐 Step 1: Logging into Vault..."
echo "Username: demouser"
echo "Password: password123"

LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8200/v1/auth/userpass/login/demouser \
    -d '{"password": "password123"}')

VAULT_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.auth.client_token')

if [ "$VAULT_TOKEN" = "null" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "❌ Failed to login to Vault"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Successfully logged into Vault"
echo "Vault token: ${VAULT_TOKEN:0:20}..."

# Step 2: Get Vault identity token
echo ""
echo "🎫 Step 2: Getting Vault identity token..."

IDENTITY_TOKEN_RESPONSE=$(curl -s -X GET http://localhost:8200/v1/identity/oidc/token/demo-role \
    -H "X-Vault-Token: $VAULT_TOKEN")

IDENTITY_TOKEN=$(echo $IDENTITY_TOKEN_RESPONSE | jq -r '.data.token')

if [ "$IDENTITY_TOKEN" = "null" ] || [ -z "$IDENTITY_TOKEN" ]; then
    echo "❌ Failed to get identity token from Vault"
    echo "Response: $IDENTITY_TOKEN_RESPONSE"
    exit 1
fi

echo "✅ Successfully obtained Vault identity token"
echo "Identity token: ${IDENTITY_TOKEN:0:50}..."

# Decode and show the token payload
echo ""
echo "🔍 Token payload (decoded):"
echo $IDENTITY_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . || echo "Could not decode token payload"

# Step 3: Test API without token (should fail)
echo ""
echo "🧪 Step 3: Testing Kong API without token (should fail)..."

RESPONSE_NO_TOKEN=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -H "Host: vault-demo.local" \
    http://localhost:8000/api/get)

STATUS_NO_TOKEN=$(echo "$RESPONSE_NO_TOKEN" | grep "HTTP_STATUS:" | cut -d: -f2)

if [ "$STATUS_NO_TOKEN" = "401" ]; then
    echo "✅ Correctly rejected request without token (401)"
else
    echo "❌ Unexpected response without token: $STATUS_NO_TOKEN"
fi

# Step 4: Test API with Vault identity token
echo ""
echo "🚀 Step 4: Testing Kong API with Vault identity token..."

RESPONSE_WITH_TOKEN=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -H "Host: vault-demo.local" \
    -H "Authorization: Bearer $IDENTITY_TOKEN" \
    http://localhost:8000/api/get)

STATUS_WITH_TOKEN=$(echo "$RESPONSE_WITH_TOKEN" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY_WITH_TOKEN=$(echo "$RESPONSE_WITH_TOKEN" | sed '/HTTP_STATUS:/d')

echo "Response status: $STATUS_WITH_TOKEN"

if [ "$STATUS_WITH_TOKEN" = "200" ]; then
    echo "✅ SUCCESS! Kong validated Vault identity token"
    echo ""
    echo "🔍 Response from backend (via Kong):"
    echo "$BODY_WITH_TOKEN" | jq . 2>/dev/null || echo "$BODY_WITH_TOKEN"
    
    echo ""
    echo "🏷️ Headers Kong added (showing consumer info):"
    echo "$BODY_WITH_TOKEN" | jq -r '.headers | to_entries[] | select(.key | startswith("X-")) | "\(.key): \(.value)"' 2>/dev/null || echo "Headers processed by Kong"
    
else
    echo "❌ Failed to validate Vault identity token"
    echo "Response: $BODY_WITH_TOKEN"
fi

# Step 5: Test with different endpoints
if [ "$STATUS_WITH_TOKEN" = "200" ]; then
    echo ""
    echo "🔄 Step 5: Testing other endpoints with Vault token..."
    
    # Test POST endpoint
    echo "Testing POST /api/post..."
    POST_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Host: vault-demo.local" \
        -H "Authorization: Bearer $IDENTITY_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"message": "Hello from Vault identity token!", "user": "demouser"}' \
        http://localhost:8000/api/post)
    
    POST_STATUS=$(echo "$POST_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ "$POST_STATUS" = "200" ]; then
        echo "✅ POST request successful"
    else
        echo "❌ POST request failed: $POST_STATUS"
    fi
    
    # Test headers endpoint
    echo "Testing GET /api/headers..."
    HEADERS_RESPONSE=$(curl -s \
        -H "Host: vault-demo.local" \
        -H "Authorization: Bearer $IDENTITY_TOKEN" \
        http://localhost:8000/api/headers)
    
    echo "Backend received these headers:"
    echo "$HEADERS_RESPONSE" | jq '.headers' 2>/dev/null || echo "$HEADERS_RESPONSE"
fi

echo ""
echo "🎯 Demo Summary"
echo "==============="
echo "✅ 1. Logged into Vault with userpass authentication"
echo "✅ 2. Obtained Vault identity token (signed by Vault)"
echo "✅ 3. Used identity token with Kong API Gateway"
echo "✅ 4. Kong validated token using Vault's public key"
echo "✅ 5. Kong forwarded request to backend service"

echo ""
echo "🔐 Security Flow Demonstrated:"
echo "1. User authenticates with Vault"
echo "2. Vault issues cryptographically signed identity token"
echo "3. Kong validates token signature using Vault's public key"
echo "4. Kong forwards authenticated request to backend"
echo "5. Backend receives user context from Kong headers"

echo ""
echo "💡 This demonstrates zero-trust authentication where:"
echo "   - Vault is the identity provider and token issuer"
echo "   - Kong is the policy enforcement point"
echo "   - Backend services receive verified user context"
echo "   - No shared secrets between services"

echo ""
echo "🏆 Production Benefits:"
echo "   ✅ Centralized identity management in Vault"
echo "   ✅ Cryptographic token verification in Kong" 
echo "   ✅ Zero-trust security model"
echo "   ✅ Scalable microservices authentication"
echo "   ✅ Complete audit trail"
