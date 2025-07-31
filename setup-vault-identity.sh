#!/bin/bash

# Setup Kong to validate Vault identity tokens
# This configures Kong to accept JWT tokens signed by Vault

echo "🚀 Setting up Kong + Vault Identity Token Demo"
echo "=============================================="

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
until curl -f http://localhost:8001/status > /dev/null 2>&1; do
    echo "Waiting for Kong Admin API..."
    sleep 5
done

until curl -f http://localhost:8200/v1/sys/health > /dev/null 2>&1; do
    echo "Waiting for Vault..."
    sleep 5
done

echo "✅ Kong and Vault are ready!"

# Configure Vault
echo ""
echo "🔐 Configuring Vault Identity Tokens..."

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='myroot'

# Enable identity secrets engine (usually enabled by default)
vault secrets list | grep identity/ > /dev/null || vault secrets enable identity

# Create an entity for our demo user
ENTITY_ID=$(vault write -field=id identity/entity name="demo-user" \
    policies="default" \
    metadata=department="engineering" \
    metadata=role="developer")

echo "Created Vault entity: $ENTITY_ID"

# Create an entity alias (for userpass auth)
vault auth list | grep userpass/ > /dev/null || vault auth enable userpass

# Create a user in userpass auth
vault write auth/userpass/users/demouser \
    password=password123 \
    policies=default

# Get the userpass auth accessor
USERPASS_ACCESSOR=$(vault auth list -format=json | jq -r '."userpass/".accessor')

# Create entity alias linking the user to the entity
vault write identity/entity-alias \
    name="demouser" \
    canonical_id="$ENTITY_ID" \
    mount_accessor="$USERPASS_ACCESSOR"

# Create a named key for signing identity tokens
vault write identity/oidc/key/demo-key \
    algorithm="RS256" \
    verification_ttl="24h" \
    rotation_period="24h"

# Create a role for issuing identity tokens
vault write identity/oidc/role/demo-role \
    key="demo-key" \
    ttl="1h" \
    template='{"aud": "kong-api", "sub": "{{identity.entity.id}}", "user": "{{identity.entity.name}}", "department": "{{identity.entity.metadata.department}}", "role": "{{identity.entity.metadata.role}}"}'

echo "✅ Vault identity tokens configured!"

# Get Vault's public key for Kong
echo ""
echo "🔑 Getting Vault's public key..."
VAULT_PUBLIC_KEY=$(curl -s http://localhost:8200/v1/identity/oidc/key/demo-key | jq -r '.data.keys | to_entries[0].value')

echo "Vault public key obtained"

# Configure Kong
echo ""
echo "📝 Configuring Kong for Vault identity tokens..."

# Create Kong service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=vault-demo-service" \
  --data "url=http://httpbin:80" > /dev/null

echo "Created Kong service"

# Create route
curl -i -X POST http://localhost:8001/services/vault-demo-service/routes \
  --data "hosts[]=vault-demo.local" \
  --data "paths[]=/api" > /dev/null

echo "Created Kong route"

# Create consumer for Vault tokens
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=vault-identity" > /dev/null

echo "Created Kong consumer"

# Add JWT credential with Vault's public key
curl -i -X POST http://localhost:8001/consumers/vault-identity/jwt \
  --data "algorithm=RS256" \
  --data "key=vault-identity-issuer" \
  --data "rsa_public_key=$VAULT_PUBLIC_KEY" > /dev/null

echo "Added Vault public key to Kong consumer"

# Enable JWT plugin
curl -i -X POST http://localhost:8001/services/vault-demo-service/plugins \
  --data "name=jwt" \
  --data "config.key_claim_name=iss" \
  --data "config.claims_to_verify=exp,iss" > /dev/null

echo "Enabled JWT plugin on Kong service"

echo ""
echo "✅ Setup complete!"
echo ""
echo "🧪 Demo URLs:"
echo "- Vault UI: http://localhost:8200 (token: myroot)"
echo "- Kong Manager: http://localhost:8002"
echo "- Kong Admin: http://localhost:8001"
echo "- API Gateway: http://localhost:8000"
echo ""
echo "📋 Next steps:"
echo "1. Add 'vault-demo.local' to your /etc/hosts: 127.0.0.1 vault-demo.local"
echo "2. Run: ./vault-identity-demo.sh"
