#!/bin/bash

# Interactive Setup Kong to validate Vault identity tokens
# This configures Kong to accept JWT tokens signed by Vault

# Source demo-magic.sh for interactive effects
source ./demo-magic.sh

# Set typing speed for demo effect
TYPE_SPEED=150

# Custom colors for our demo
VAULT_COLOR="\033[0;35m"  # Purple for Vault
KONG_COLOR="\033[0;36m"   # Cyan for Kong
SUCCESS_COLOR="\033[0;32m" # Green for success
INFO_COLOR="\033[0;34m"    # Blue for info

clear

echo -e "${BOLD}${BLUE}🚀 Interactive Kong + Vault Identity Token Demo Setup${COLOR_RESET}"
echo -e "${BOLD}${BLUE}====================================================${COLOR_RESET}"
echo ""
echo -e "${INFO_COLOR}This interactive demo will set up:${COLOR_RESET}"
echo -e "  ${VAULT_COLOR}• HashiCorp Vault${COLOR_RESET} as the identity provider"
echo -e "  ${KONG_COLOR}• Kong Gateway${COLOR_RESET} as the API gateway with JWT validation"
echo -e "  ${SUCCESS_COLOR}• Zero-trust authentication${COLOR_RESET} with SPIFFE-compliant tokens"
echo ""

p "# First, let's wait for our services to be ready..."
echo ""

p "# Checking Kong Admin API..."
until curl -f http://localhost:8001/status > /dev/null 2>&1; do echo 'Waiting for Kong...'; sleep 2; done

p "# Checking Vault API..."
until curl -f http://localhost:8200/v1/sys/health > /dev/null 2>&1; do echo 'Waiting for Vault...'; sleep 2; done

echo ""
echo -e "${SUCCESS_COLOR}✅ Kong and Vault are ready!${COLOR_RESET}"
echo ""

p "# Now let's configure Vault for identity token generation"
echo ""

p "# Become root user ,set Vault environment variables"
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='myroot'

p "# Configure OIDC issuer - this is crucial for JWT validation"
pe "vault write identity/oidc/config issuer=\"http://vault.local:8200\""

echo ""
echo -e "${INFO_COLOR}🔐 Creating Vault entities and authentication...${COLOR_RESET}"
echo ""

p "# Create an entity for our demo developer user"
pe "ENTITY_ID=\$(vault write -field=id identity/entity name=\"demo-developer\" policies=\"default\" metadata=department=\"engineering\" metadata=role=\"developer\" metadata=entity_name=\"demo-developer\" metadata=spiffe_id=\"spiffe://vault/engineering/developer/demo-developer\")"

# Silent error checking - not part of the demo
if [ -z "$ENTITY_ID" ]; then 
    echo "Error: Failed to create entity or get entity ID"
    exit 1
fi

pe "echo \"Created Vault entity: \$ENTITY_ID\""

p "# Enable userpass authentication method"
pe "vault auth list | grep userpass/ > /dev/null || vault auth enable userpass"

p "# Create a demo developer user alias"
pe "vault write auth/userpass/users/demodeveloper password=password123 policies=default"

p "# Link the demo developer user to the entity via entity alias"
pe "USERPASS_ACCESSOR=\$(vault auth list -format=json | jq -r '.\"userpass/\".accessor')"
pe "vault write identity/entity-alias name=\"demodeveloper\" canonical_id=\"\$ENTITY_ID\" mount_accessor=\"\$USERPASS_ACCESSOR\""

p "# Read the entity to verify"
pe "vault read -format=json identity/entity/id/\$ENTITY_ID | jq -r ."

echo ""

p "# Create an entity for our demo sales user"
pe "SALES_ENTITY_ID=\$(vault write -field=id identity/entity name=\"demo-sales\" policies=\"default\" metadata=department=\"sales\" metadata=role=\"manager\" metadata=entity_name=\"demo-sales\" metadata=spiffe_id=\"spiffe://vault/sales/manager/demo-sales\")"

# Silent error checking - not part of the demo
if [ -z "$SALES_ENTITY_ID" ]; then 
    echo "Error: Failed to create sales entity or get entity ID"
    exit 1
fi

pe "echo \"Created sales Vault entity: \$SALES_ENTITY_ID\""

p "# Create a demo sales user alias"
pe "vault write auth/userpass/users/demosales password=password123 policies=default"

p "# Link the sales user to the entity via entity alias"
pe "vault write identity/entity-alias name=\"demosales\" canonical_id=\"\$SALES_ENTITY_ID\" mount_accessor=\"\$USERPASS_ACCESSOR\""

p "# Read the sales entity to verify"
pe "vault read -format=json identity/entity/id/\$SALES_ENTITY_ID | jq -r ."

echo ""
echo -e "${INFO_COLOR}�🔑 Setting up OIDC keys and roles for JWT signing...${COLOR_RESET}"
echo ""

p "# Create a named key for signing identity tokens, the key auto auto-rotates every 24h hours"
pe "vault write identity/oidc/key/human-signer-key algorithm=\"RS256\" verification_ttl=\"24h\" rotation_period=\"24h\""

p "# Create a role with custom SPIFFE-compliant audience, signed jwt token is valid for 1 hour"
vault write identity/oidc/role/human-identity key="human-signer-key" ttl="1h" client_id="spiff://kong-api-gateway" template=@identity.tmpl

p "# Configure the key to allow our custom audience"
pe "vault write identity/oidc/key/human-signer-key allowed_client_ids=\"spiff://kong-api-gateway\""

p "# Create policy for token generation"
pe 'echo "path \"identity/oidc/token/human-identity\" {
  capabilities = [\"read\", \"create\", \"update\"]
}" | vault policy write demo-token-policy -'

p "# Attach the policy to our entity using the correct API"
pe "vault write identity/entity/id/\$ENTITY_ID policies=\"default,demo-token-policy\""

p "# Attach the policy to our sales entity as well"
pe "vault write identity/entity/id/\$SALES_ENTITY_ID policies=\"default,demo-token-policy\""

echo ""
echo -e "${SUCCESS_COLOR}✅ Vault identity tokens configured!${COLOR_RESET}"
echo ""

echo -e "${INFO_COLOR}🔑 Extracting Vault's public key for Kong...${COLOR_RESET}"
echo ""

p "# Get the JWK and convert to PEM format"
pe "curl -s http://localhost:8200/v1/identity/oidc/.well-known/keys | jq -r '.keys[0]' | python3 convert-jwk-to-pem.py > vault-public.pem"

p "# Vault public key extracted to PEM format"

echo ""
echo -e "${KONG_COLOR}📝 Configuring Kong API Gateway...${COLOR_RESET}"
echo ""

p "# Create Kong service pointing to our backend"
pe "curl -i -X POST http://localhost:8001/services/ --data \"name=vault-demo-service\" --data \"url=http://httpbin:80\" > /dev/null"
p "Created Kong service"

p "# Create route for our API"
pe "curl -i -X POST http://localhost:8001/services/vault-demo-service/routes --data \"hosts[]=vault.local\" --data \"paths[]=/api\" > /dev/null"
p "Created Kong route"

p "# Create consumer for Vault tokens"
pe "curl -i -X POST http://localhost:8001/consumers/ --data \"username=vault-identity\" > /dev/null"
p "Created Kong consumer"

echo ""
echo -e "${INFO_COLOR}🔐 Adding Vault's public key to Kong for JWT validation...${COLOR_RESET}"
echo ""

p "# Add JWT credential with Vault's public key"
pe "curl -i -X POST http://localhost:8001/consumers/vault-identity/jwt --data \"algorithm=RS256\" --data \"key=http://vault.local:8200/v1/identity/oidc\" --data-urlencode \"rsa_public_key@vault-public.pem\" > /dev/null"

p "# Ensure the public key is synchronized (handles key rotation)"
pe "KONG_JWT_ID=\$(curl -s http://localhost:8001/consumers/vault-identity/jwt | jq -r '.data[0].id')"
pe "curl -X PATCH http://localhost:8001/consumers/vault-identity/jwt/\$KONG_JWT_ID --data-urlencode \"rsa_public_key@vault-public.pem\" > /dev/null"

pe "echo \"Added Vault public key to Kong consumer\""

echo ""
echo -e "${INFO_COLOR}🛡️ Adding Enhanced JWT Validation...${COLOR_RESET}"
echo ""

p "# Add custom JWT validator with department-based access control"
p "# This validates audience claims and enforces department authorization"
pe "curl -i -X POST http://localhost:8001/services/vault-demo-service/plugins --data \"name=pre-function\" --data-urlencode \"config.access@simple-jwt-validator.lua\" > /dev/null"

pe "echo \"Added enhanced JWT validation with department controls\""
p "# Features: audience validation, department authorization (engineering/security/devops)"

echo ""
echo -e "${SUCCESS_COLOR}🎉 Setup Complete!${COLOR_RESET}"
echo ""
echo -e "${BOLD}${SUCCESS_COLOR}🧪 Demo Environment Ready:${COLOR_RESET}"
echo -e "  ${VAULT_COLOR}• Vault UI: http://localhost:8200 (token: myroot)${COLOR_RESET}"
echo -e "  ${KONG_COLOR}• Kong Manager: http://localhost:8002${COLOR_RESET}"
echo -e "  ${KONG_COLOR}• Kong Admin: http://localhost:8001${COLOR_RESET}"
echo -e "  ${INFO_COLOR}• API Gateway: http://localhost:8000${COLOR_RESET}"
echo ""
echo -e "${BOLD}${SUCCESS_COLOR}🛡️ Security Features Configured:${COLOR_RESET}"
echo -e "  ${SUCCESS_COLOR}✅ JWT signature validation with Vault's public key${COLOR_RESET}"
echo -e "  ${SUCCESS_COLOR}✅ Audience claim validation (spiff://kong-api-gateway)${COLOR_RESET}"
echo -e "  ${SUCCESS_COLOR}✅ Department-based access control (engineering/security/devops)${COLOR_RESET}"
echo -e "  ${SUCCESS_COLOR}✅ User context headers (X-User-Department, X-User-Role, etc.)${COLOR_RESET}"
echo ""
echo -e "${BOLD}${BLUE}📋 Next Steps:${COLOR_RESET}"
echo -e "  1. Add 'vault.local' to your /etc/hosts: ${INFO_COLOR}127.0.0.1 vault.local${COLOR_RESET}"
echo -e "  2. Run the interactive demo: ${INFO_COLOR}./vault-identity-demo-interactive.sh${COLOR_RESET}"
echo ""
