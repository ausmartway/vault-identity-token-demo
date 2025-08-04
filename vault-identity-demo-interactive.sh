#!/bin/bash

# Interactive Vault Identity Token Demo
# Demonstrates complete zero-trust authentication flow

# Source demo-magic.sh for interactive effects
# check if AUTO_PLAY_MODE is set to true, if not, use the default demo-magic.sh other wise add -d -n to the source command
if [ -n "$AUTO_PLAY_MODE" ]; then
    source ./demo-magic.sh -d -n
else
    source ./demo-magic.sh
fi

# Set typing speed for demo effect
TYPE_SPEED=150

# Custom colors for our demo
VAULT_COLOR="\033[0;35m"  # Purple for Vault
KONG_COLOR="\033[0;36m"   # Cyan for Kong
SUCCESS_COLOR="\033[0;32m" # Green for success
ERROR_COLOR="\033[0;31m"   # Red for errors
INFO_COLOR="\033[0;34m"    # Blue for info
YELLOW="\033[0;33m"        # Yellow for highlights

clear

echo -e "${BOLD}${BLUE}🎯 Interactive Vault Identity Token → Kong API Demo${COLOR_RESET}"
echo -e "${BOLD}${BLUE}=================================================${COLOR_RESET}"
echo ""
echo -e "${INFO_COLOR}This demo showcases:${COLOR_RESET}"
echo -e "  ${VAULT_COLOR}🔐 HashiCorp Vault${COLOR_RESET} issuing cryptographically signed identity tokens"
echo -e "  ${KONG_COLOR}🛡️  Kong Gateway${COLOR_RESET} validating JWT tokens and enforcing security policies"
echo -e "  ${SUCCESS_COLOR}🔗 Zero-trust architecture${COLOR_RESET} with no shared secrets between services"
echo -e "  ${YELLOW}✨ SPIFFE-compliant${COLOR_RESET} workload identity with audience claims"
echo ""

p "# First, let's verify our services are running"
curl -f http://localhost:8001/status > /dev/null 2>&1 && curl -f http://localhost:8200/v1/sys/health > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${SUCCESS_COLOR}✅ Both Kong and Vault are running${COLOR_RESET}"
else
    echo -e "${ERROR_COLOR}❌ Services not ready. Please run setup first.${COLOR_RESET}"
    exit 1
fi

echo ""
echo -e "${BOLD}${VAULT_COLOR}🔐 Step 1: Authenticating with Vault${COLOR_RESET}"
echo -e "${INFO_COLOR}We'll use userpass authentication to log into Vault...${COLOR_RESET}"
echo ""

p "# Set Vault environment variable"
export VAULT_ADDR='http://localhost:8200'

p "# Login to Vault using userpass method"
p "# Username: demodeveloper, Password: password123"
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8200/v1/auth/userpass/login/demodeveloper -d '{"password": "password123"}')

p "# Extract the Vault token from response"
VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.auth.client_token')

if [ "$VAULT_TOKEN" = "null" ] || [ -z "$VAULT_TOKEN" ]; then 
    echo -e "${ERROR_COLOR}❌ Failed to login to Vault${COLOR_RESET}"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo -e "${SUCCESS_COLOR}✅ Successfully logged into Vault${COLOR_RESET}"
echo "Vault token: ${VAULT_TOKEN:0:20}..."

echo ""
echo -e "${BOLD}${VAULT_COLOR}🎫 Step 2: Obtaining Vault Identity Token${COLOR_RESET}"
echo -e "${INFO_COLOR}Now we'll request a signed identity token with SPIFFE audience...${COLOR_RESET}"
echo ""

p "# Request identity token from Vault"
pe "IDENTITY_TOKEN_RESPONSE=\$(curl -s -X GET http://localhost:8200/v1/identity/oidc/token/human-identity -H \"X-Vault-Token: \$VAULT_TOKEN\")"

pe "IDENTITY_TOKEN=\$(echo \"\$IDENTITY_TOKEN_RESPONSE\" | jq -r '.data.token')"

if [ "$IDENTITY_TOKEN" = "null" ] || [ -z "$IDENTITY_TOKEN" ]; then 
    echo -e "${ERROR_COLOR}❌ Failed to get identity token from Vault${COLOR_RESET}"
    echo "Response: $IDENTITY_TOKEN_RESPONSE"
    exit 1
fi

echo -e "${SUCCESS_COLOR}✅ Successfully obtained Vault identity token${COLOR_RESET}"
echo "Identity token: ${IDENTITY_TOKEN:0:50}..."

echo ""
echo -e "${INFO_COLOR}🔍 Let's decode the token to see its contents:${COLOR_RESET}"
echo ""

p "# Decode JWT payload to see claims"
pe "echo \"\$IDENTITY_TOKEN\" | python3 decode-jwt.py 2>/dev/null || echo \"Could not decode token payload\""

echo ""
echo -e "${BOLD}${KONG_COLOR}🧪 Step 3: Testing API Security (Without Token)${COLOR_RESET}"
echo -e "${INFO_COLOR}First, let's verify Kong rejects requests without authentication...${COLOR_RESET}"
echo ""

p "# Test API endpoint without any token"
pe "RESPONSE_NO_TOKEN=\$(curl -s -w \"\\nHTTP_STATUS:%{http_code}\" -H \"Host: localhost\" http://localhost:8000/api/get)"

pe "STATUS_NO_TOKEN=\$(echo \"\$RESPONSE_NO_TOKEN\" | grep \"HTTP_STATUS:\" | cut -d: -f2)"

if [ "$STATUS_NO_TOKEN" = "401" ]; then echo -e "${SUCCESS_COLOR}✅ Correctly rejected request without token (401)${COLOR_RESET}"; else echo "${ERROR_COLOR}❌ Unexpected response without token: $STATUS_NO_TOKEN${COLOR_RESET}"; fi

echo ""
echo -e "${BOLD}${KONG_COLOR}🚀 Step 4: Testing API with Vault Identity Token${COLOR_RESET}"
echo -e "${INFO_COLOR}Now let's use our Vault identity token to access the API...${COLOR_RESET}"
echo ""

p "# Test API endpoint with Vault identity token"
RESPONSE_WITH_TOKEN=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Host: localhost" -H "Authorization: Bearer $IDENTITY_TOKEN" http://localhost:8000/api/get)

STATUS_WITH_TOKEN=$(echo "$RESPONSE_WITH_TOKEN" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY_WITH_TOKEN=$(echo "$RESPONSE_WITH_TOKEN" | sed '/HTTP_STATUS:/d')

echo "Response status: $STATUS_WITH_TOKEN"

if [ "$STATUS_WITH_TOKEN" = "200" ]; then 
    echo -e "${SUCCESS_COLOR}✅ SUCCESS! Kong validated Vault identity token${COLOR_RESET}"
    echo ""
    echo -e "${INFO_COLOR}🔍 Response from backend (via Kong):${COLOR_RESET}"
    echo "$BODY_WITH_TOKEN" | jq '.' 2>/dev/null || echo "$BODY_WITH_TOKEN"
    echo ""
    echo -e "${INFO_COLOR}🏷️  Headers Kong added (showing consumer info):${COLOR_RESET}"
    echo "$BODY_WITH_TOKEN" | jq -r '.headers | to_entries[] | select(.key | startswith("X-")) | "\(.key): \(.value)"' 2>/dev/null || echo "Headers processed by Kong"
else 
    echo -e "${ERROR_COLOR}❌ Failed to validate Vault identity token${COLOR_RESET}"
    echo "Response: $BODY_WITH_TOKEN"
fi

echo ""
echo -e "${BOLD}${SUCCESS_COLOR}🔄 Step 5: Testing Additional Endpoints${COLOR_RESET}"
echo -e "${INFO_COLOR}Let's test other HTTP methods to show the complete integration...${COLOR_RESET}"
echo ""

if [ "$STATUS_WITH_TOKEN" = "200" ]; then 
    echo "Testing POST /api/post..."
    POST_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST -H "Host: localhost" -H "Authorization: Bearer $IDENTITY_TOKEN" -H "Content-Type: application/json" -d '{"message": "Hello from Vault identity token!", "user": "demodeveloper"}' http://localhost:8000/api/post)
    POST_STATUS=$(echo "$POST_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    if [ "$POST_STATUS" = "200" ]; then 
        echo -e "${SUCCESS_COLOR}✅ POST request successful${COLOR_RESET}"
    else 
        echo -e "${ERROR_COLOR}❌ POST request failed: $POST_STATUS${COLOR_RESET}"
    fi
    echo ""
    echo "Testing GET /api/headers..."
    HEADERS_RESPONSE=$(curl -s -H "Host: localhost" -H "Authorization: Bearer $IDENTITY_TOKEN" http://localhost:8000/api/headers)
    echo "Backend received these headers:"
    echo "$HEADERS_RESPONSE" | jq '.headers' 2>/dev/null || echo "$HEADERS_RESPONSE"
fi

echo ""
echo ""

echo ""
echo -e "${BOLD}${ERROR_COLOR}🚫 Step 6: Testing Department-Based Access Control${COLOR_RESET}"
echo -e "${INFO_COLOR}Now let's test that our sales user gets blocked by Kong's department validation...${COLOR_RESET}"
echo ""

p "# Login as sales user"
p "# Username: demosales, Password: password123"
SALES_LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8200/v1/auth/userpass/login/demosales -d '{"password": "password123"}')

p "# Extract the sales user Vault token"
SALES_VAULT_TOKEN=$(echo "$SALES_LOGIN_RESPONSE" | jq -r '.auth.client_token')

if [ "$SALES_VAULT_TOKEN" = "null" ] || [ -z "$SALES_VAULT_TOKEN" ]; then 
    echo -e "${ERROR_COLOR}❌ Failed to login sales user to Vault${COLOR_RESET}"
    echo "Response: $SALES_LOGIN_RESPONSE"
    exit 1
fi

echo -e "${SUCCESS_COLOR}✅ Sales user logged into Vault${COLOR_RESET}"
echo "Sales token: ${SALES_VAULT_TOKEN:0:20}..."

p "# Request identity token for sales user"
pe "SALES_IDENTITY_RESPONSE=\$(curl -s -X GET http://localhost:8200/v1/identity/oidc/token/human-identity -H \"X-Vault-Token: \$SALES_VAULT_TOKEN\")"

pe "SALES_IDENTITY_TOKEN=\$(echo "\$SALES_IDENTITY_RESPONSE" | jq -r '.data.token')"

if [ "$SALES_IDENTITY_TOKEN" = "null" ] || [ -z "$SALES_IDENTITY_TOKEN" ]; then 
    echo -e "${ERROR_COLOR}❌ Failed to get sales identity token from Vault${COLOR_RESET}"
    echo "Response: $SALES_IDENTITY_RESPONSE"
    exit 1
fi

echo -e "${SUCCESS_COLOR}✅ Sales user obtained identity token${COLOR_RESET}"
echo "Sales identity token: ${SALES_IDENTITY_TOKEN:0:50}..."

echo ""
echo -e "${INFO_COLOR}🔍 Let's decode the sales user token to see the department claim:${COLOR_RESET}"
echo ""

p "# Decode sales user JWT payload to see department difference"
pe "echo \"\$SALES_IDENTITY_TOKEN\" | python3 decode-jwt.py 2>/dev/null || echo \"Could not decode sales token payload\""

echo ""

p "# Test API access with sales token - should be BLOCKED"
pe "SALES_RESPONSE=\$(curl -s -w \"\\nHTTP_STATUS:%{http_code}\" -H \"Host: localhost\" -H \"Authorization: Bearer \$SALES_IDENTITY_TOKEN\" http://localhost:8000/api/get)"

SALES_STATUS=$(echo "$SALES_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
SALES_BODY=$(echo "$SALES_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$SALES_STATUS" = "403" ]; then
    echo -e "${SUCCESS_COLOR}✅ CORRECT! Sales user blocked by Kong (403 Forbidden)${COLOR_RESET}"
    echo -e "${ERROR_COLOR}🚫 Kong's response:${COLOR_RESET}"
    echo "$SALES_BODY" | jq '.' 2>/dev/null || echo "$SALES_BODY"
else
    echo -e "${ERROR_COLOR}❌ Unexpected: Sales user was not blocked. Status: $SALES_STATUS${COLOR_RESET}"
fi

echo ""
echo -e "${BOLD}${BLUE}🎯 Demo Summary${COLOR_RESET}"
echo -e "${BOLD}${BLUE}===============${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 1. Logged into Vault with userpass authentication (engineering user)${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 2. Obtained Vault identity token (signed by Vault)${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 3. Used identity token with Kong API Gateway${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 4. Kong validated token using Vault's public key${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 5. Kong forwarded request to backend service${COLOR_RESET}"
echo -e "${SUCCESS_COLOR}✅ 6. Tested sales user - correctly blocked by department policy${COLOR_RESET}"
echo ""

echo -e "${BOLD}${INFO_COLOR}🔐 Security Flow Demonstrated:${COLOR_RESET}"
echo -e "1. ${VAULT_COLOR}User authenticates with Vault${COLOR_RESET}"
echo -e "2. ${VAULT_COLOR}Vault issues cryptographically signed identity token${COLOR_RESET}"
echo -e "3. ${KONG_COLOR}Kong validates token signature using Vault's public key${COLOR_RESET}"
echo -e "4. ${KONG_COLOR}Kong enforces department-based access control${COLOR_RESET}"
echo -e "5. ${KONG_COLOR}Kong forwards authenticated request to backend (if authorized)${COLOR_RESET}"
echo -e "6. ${SUCCESS_COLOR}Backend receives user context from Kong headers${COLOR_RESET}"
echo ""

echo -e "${BOLD}${YELLOW}💡 This demonstrates zero-trust authentication where:${COLOR_RESET}"
echo -e "   ${VAULT_COLOR}• Vault is the identity provider and token issuer${COLOR_RESET}"
echo -e "   ${KONG_COLOR}• Kong is the policy enforcement point with fine-grained access control${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}• Backend services receive verified user context${COLOR_RESET}"
echo -e "   ${INFO_COLOR}• No shared secrets between services${COLOR_RESET}"
echo -e "   ${ERROR_COLOR}• Department-based authorization enforced at gateway level${COLOR_RESET}"
echo ""

echo -e "${BOLD}${SUCCESS_COLOR}🏆 Production Benefits:${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}✅ Centralized identity management in Vault${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}✅ Cryptographic token verification in Kong${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}✅ Zero-trust security model${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}✅ Scalable microservices authentication${COLOR_RESET}"
echo -e "   ${SUCCESS_COLOR}✅ Complete audit trail${COLOR_RESET}"
echo ""
