# Vault Identity Token + Kong Gateway Demo

This project demonstrates a **zero-trust authentication architecture** using:

- **HashiCorp Vault** as the identity provider issuing cryptographically signed JWT tokens
- **Kong Gateway** as the API gateway with JWT validation and policy enforcement
- **SPIFFE-compliant** workload identity with audience claims

## Architecture Overview

```text
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│    Vault     │───▶│    Kong     │───▶│   Backend   │
│             │    │  (Identity)  │    │ (Gateway)   │    │  (HTTPBin)  │
│             │    │              │    │             │    │             │
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘
      │                     │                   │                 │
      │                     │                   │                 │
   1. Auth                2. JWT            3. Validate        4. Request
   Request             Token + Claims       + Forward         + User Context
```

## Quick Start

### 1. Start All Services

```bash
# Start Vault, Kong, and HTTPBin
docker compose -f docker-compose-with-vault.yml up -d

# Check if services are healthy
docker compose -f docker-compose-with-vault.yml ps
```

### 2. Add Host Entry

Add this line to your `/etc/hosts` file:

```text
127.0.0.1 vault.local
```

### 3. Configure the Complete System

```bash
# Make the setup script executable
chmod +x setup-vault-identity-interactive.sh

# Run the complete setup (interactive mode)
./setup-vault-identity-interactive.sh

# Or run in auto-play mode
AUTO_PLAY_MODE=1 ./setup-vault-identity-interactive.sh
```

### 4. Run the Interactive Demo

```bash
# Interactive demonstration of the complete flow
./vault-identity-demo-interactive.sh

# Or in auto-play mode
AUTO_PLAY_MODE=1 ./vault-identity-demo-interactive.sh
```

## Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Kong Proxy | 8000 | Main API gateway endpoint |
| Kong Admin API | 8001 | Admin API for configuration |
| Kong Manager | 8002 | Web UI for Kong management |
| Vault Server | 8200 | Identity provider and token issuer |
| HTTPBin | 8080 | Sample backend service |
| PostgreSQL | 5432 | Kong's database |

## Security Features

### ✅ **Cryptographic Token Validation**

- JWT tokens signed by Vault using RS256 algorithm
- Public key validation in Kong using Vault's OIDC keys
- Automatic key rotation support (24-hour rotation period)

### ✅ **SPIFFE-Compliant Identity**

- Audience claim validation (`spiff://kong-api-gateway`)
- Workload identity with department and role metadata
- Zero shared secrets between services

### ✅ **Department-Based Access Control**

- JWT claims include department and role information
- Kong adds user context headers to backend requests
- Backend services receive authenticated user metadata

**Available Demo Users:**

| Department | Username | Password | Role |
|------------|----------|----------|------|
| Engineering | demodeveloper | password123 | developer |
| Sales | demosales | password123 | manager |

## Authentication Flow

### 1. **User Authentication with Vault**

```bash
# Authenticate with Vault
export VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=$(vault write -field=token auth/userpass/login/demodeveloper password=password123)
export VAULT_TOKEN
```

### 2. **Obtain Signed Identity Token**

```bash
# Get SPIFFE-compliant identity token
JWT_TOKEN=$(vault read -field=token identity/oidc/token/human-identity)
```

### 3. **Call API with Token**

```bash
# Make authenticated request
curl -H "Host: vault.local" \
     -H "Authorization: Bearer $JWT_TOKEN" \
     http://localhost:8000/api/get
```

## Token Structure

The JWT tokens issued by Vault contain:

```json
{
  "aud": "spiff://kong-api-gateway",
  "azp": "spiffe://vault/engineering/developer/demo-developer",
  "exp": 1754228088,
  "iat": 1754224488,
  "iss": "http://vault.local:8200/v1/identity/oidc",
  "namespace": "root",
  "sub": "f388b783-8dec-031e-c344-6aaa18012c77",
  "userinfo": {
    "department": "engineering",
    "entity_id": "f388b783-8dec-031e-c344-6aaa18012c77",
    "entity_name": "demo-developer",
    "role": "developer"
  }
}
```

## Manual Configuration Examples

### Create Vault Entity with Metadata

```bash
vault write identity/entity \
  name="demo-user" \
  policies="default" \
  metadata=department="engineering" \
  metadata=role="developer" \
  metadata=entity_name="demo-user" \
  metadata=spiffe_id="spiffe://vault/engineering/developer/demo-user"
```

### Configure OIDC Role for JWT Signing

```bash
vault write identity/oidc/role/human-identity \
  key="human-signer-key" \
  ttl="1h" \
  client_id="spiff://kong-api-gateway" \
  template=@identity.tmpl
```

### Kong Service and Route Setup

```bash
# Create service
curl -X POST http://localhost:8001/services/ \
  --data "name=demo-service" \
  --data "url=http://httpbin:80"

# Create route
curl -X POST http://localhost:8001/services/demo-service/routes \
  --data "hosts[]=vault.local" \
  --data "paths[]=/api"
```

### Add Kong JWT Consumer

```bash
# Create consumer
curl -X POST http://localhost:8001/consumers/ \
  --data "username=vault-signed-identity"

# Add JWT credential with Vault's public key
curl -X POST http://localhost:8001/consumers/vault-signed-identity/jwt \
  --data "algorithm=RS256" \
  --data "key=http://vault.local:8200/v1/identity/oidc" \
  --data-urlencode "rsa_public_key@vault-public.pem"
```

## Demo Users

| Username | Password | Department | Role |
|----------|----------|------------|------|
| demodeveloper | password123 | engineering | developer |
| demosales | password123 | sales | manager |

## File Structure

```text
├── docker-compose-with-vault.yml   # Complete stack with Vault
├── setup-vault-identity-interactive.sh  # System setup script
├── vault-identity-demo-interactive.sh   # Demo script
├── identity.tmpl                   # Vault JWT template
├── convert-jwk-to-pem.py          # JWK to PEM converter
├── decode-jwt.py                  # JWT token decoder
└── demo-magic.sh                  # Interactive demo effects
```

## Troubleshooting

### Check Service Health

```bash
# Kong status
curl http://localhost:8001/status

# Vault status
curl http://localhost:8200/v1/sys/health
```

### View Logs

```bash
# Kong logs
docker compose -f docker-compose-with-vault.yml logs kong-gateway

# Vault logs
docker compose -f docker-compose-with-vault.yml logs vault-server
```

### Test JWT Token Decoding

```bash
echo "$JWT_TOKEN" | python3 decode-jwt.py
```

## Cleanup

```bash
# Stop all services
docker compose -f docker-compose-with-vault.yml down

# Remove volumes (deletes databases)
docker compose -f docker-compose-with-vault.yml down -v
```

## Production Considerations

1. **Vault High Availability**: Configure Vault clustering for production
2. **Kong Enterprise**: Consider Kong Enterprise for additional features
3. **TLS/SSL**: Enable HTTPS for all service communications
4. **Secret Management**: Use proper secret rotation and management
5. **Monitoring**: Implement comprehensive logging and monitoring
6. **Performance**: Tune JWT validation performance

## Benefits of This Architecture

- **Zero Trust**: No shared secrets between services
- **Centralized Identity**: Single source of truth for user identity
- **Scalable**: Microservices-ready authentication
- **Auditable**: Complete audit trail of all authentication decisions
- **Standards Compliant**: Uses SPIFFE, JWT, and OIDC standards
- **Flexible**: Easy to extend with additional authorization layers
