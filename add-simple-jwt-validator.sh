#!/bin/bash

# Add Simple JWT Validator to Kong
echo "🛡️ Adding Simple JWT Claim Validator to Kong..."
echo "==============================================="

# Read the simple Lua script
LUA_SCRIPT=$(cat simple-jwt-validator.lua)

# Add the pre-function plugin
echo "Adding sandbox-safe pre-function plugin..."

curl -i -X POST http://localhost:8001/services/vault-demo-service/plugins \
  --data "name=pre-function" \
  --data-urlencode "config.access[1]=$LUA_SCRIPT"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Simple JWT validator added successfully!"
    echo ""
    echo "🔍 Validation Features:"
    echo "  • Audience validation: 'spiff://kong-api-gateway'"
    echo "  • Department authorization: engineering, security, devops"
    echo "  • Custom headers: X-User-Department, X-User-Role, X-User-Entity, X-User-ID"
    echo ""
    echo "🧪 Test with: ./vault-identity-demo-interactive.sh"
else
    echo "❌ Failed to add JWT validator"
fi
