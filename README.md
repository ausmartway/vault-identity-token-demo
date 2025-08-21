# Vault Identity Token + Kong Gateway Demo

This project demonstrates a **zero-trust authentication architecture** using:

- **HashiCorp Vault** as the identity provider issuing cryptographically signed JWT tokens
- **Kong Gateway** as the API gateway with JWT validation and policy enforcement
- **SPIFFE-compliant** workload identity with audience claims

## Problem Statement

Traditional microservices authentication faces several fundamental challenges that impact both scalability and operational efficiency:

### 🚫 **API Gateway Architectural Mismatch**

Traditional authentication/authorization handled at backend services is not API gateway friendly. API gateways operate primarily with HTTP headers for routing, rate limiting, and policy decisions. When authentication logic is embedded within individual services, it creates incompatibility with Layer 7 routing patterns. Header-based routing capabilities (for versioning, A/B testing, environment separation) become impossible when authentication decisions are buried in service logic rather than available at the gateway layer.

### 📈 **Management Scalability Crisis** 

Traditional authentication/authorization implemented at individual backend services doesn't scale in terms of management. Each service requires its own authentication implementation, updates, and maintenance. Policy changes require coordinated updates across multiple services and development teams, creating operational overhead that grows exponentially with service count. There's no centralized control or visibility over authentication policies, making security governance increasingly difficult.

### ⚡ **Performance & Latency Overhead**

Backend service authentication introduces additional network hops for every request (service → auth service → service). These authentication calls compound across service chains, with each service in a request path requiring its own authentication validation. This creates cumulative latency compared to a single authentication validation at the API gateway layer.

### 🔧 **Operational Complexity**

Distributed authentication creates significant operational challenges. Secret rotation requires coordinated updates across all services simultaneously. Each service needs network access to authentication services, complicating network policies and service discovery. Integration testing becomes complex as it requires spinning up multiple auth-enabled service dependencies rather than a single authentication point.

### 📋 **Compliance & Audit Challenges**

Distributed authentication makes centralized audit logging and compliance monitoring difficult. Many regulatory requirements (SOX, PCI DSS) mandate centralized access control and audit trails. Forensic analysis becomes complex when authentication decisions are scattered across multiple services, making it hard to reconstruct user access patterns and security events.

## Architecture Overview

This architecture directly addresses the problems outlined above by centralizing authentication at the API gateway layer:

```text
┌─────────────┐                   ┌──────────────┐
│   Client    │◀─── 2. JWT Token ─│    Vault     │
│             │                   │  (Identity)  │
│             │─── 1. Auth Req ──▶│              │
└─────┬───────┘                   └──────▲───────┘
      │                                  │
      │ 3. API Request                   │ 4. Token
      │    + JWT Token                   │    Validation
      ▼                                  │
┌─────────────┐                          │
│    Kong     │──────────────────────────┘
│ (Gateway)   │ ← Single auth point enables
│             │   header-based routing
└─────┬───────┘
      │
      │ 5. Forwarded Request
      │    + User Context Headers
      ▼
┌─────────────┐
│   Backend   │ ← No auth logic needed
│  (HTTPBin)  │   in backend services
│             │
└─────────────┘
```

**Key Architectural Benefits:**

- **🎯 API Gateway Compatibility**: Kong performs authentication and makes user claims available as HTTP headers for routing decisions, A/B testing, and policy enforcement
- **📊 Centralized Management**: Single point of authentication policy control rather than distributed across dozens of services  
- **⚡ Reduced Latency**: One authentication validation per request vs. multiple validations across service chains
- **🔧 Simplified Operations**: Backend services require no authentication logic, secrets, or auth service connectivity
- **📋 Centralized Auditing**: All authentication decisions flow through Kong, enabling comprehensive audit logging

## Quick Start

### 1. Start All Services

```bash
# Start Vault, Kong, and HTTPBin
docker compose up -d

# Check if services are healthy
docker compose ps
```

### 2. Configure the Complete System

```bash
# Make the setup script executable
chmod +x setup-vault-identity-interactive.sh

# Run the complete setup (interactive mode)
./setup-vault-identity-interactive.sh

# Or run in auto-play mode
AUTO_PLAY_MODE=1 ./setup-vault-identity-interactive.sh
```

### 3. Run the Interactive Demo

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

*Solves: Eliminates shared secrets and enables centralized secret management*

### ✅ **SPIFFE-Compliant Identity**

- Audience claim validation (`spiffe://kong-api-gateway`)
- Workload identity with department and role metadata
- Zero shared secrets between services

*Solves: Provides standards-based identity that works across cloud-native environments*

### ✅ **Department-Based Access Control**

- JWT claims include department and role information
- Kong adds user context headers to backend requests
- Backend services receive authenticated user metadata

*Solves: Enables fine-grained authorization without backend service auth logic*

### ✅ **API Gateway Integration**

- Authentication happens at Kong, making user claims available as HTTP headers
- Enables header-based routing for versioning, A/B testing, and environment separation
- Single authentication decision point rather than distributed validation

*Solves: API gateway architectural mismatch and enables Layer 7 routing capabilities*

### ✅ **Centralized Policy Management**

- All authentication policies configured in Vault and Kong
- Policy changes require updates to only two central services
- Unified audit trail and monitoring through Kong access logs

*Solves: Management scalability crisis and compliance audit challenges*

**Available Demo Users:**

| Department | Username | Password | Role |
|------------|----------|----------|------|
| Engineering | demodeveloper | password123 | developer |
| Sales | demosales | password123 | manager |

## Authentication Flow

*This flow demonstrates single authentication validation vs. traditional multi-service auth chains*

### 1. **User Authentication with Vault**

```bash
# Authenticate with Vault
export VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=$(vault write -field=token auth/userpass/login/demodeveloper password=password123)
export VAULT_TOKEN
```

### 2. **Obtain Signed Identity Token**

```bash
# Get SPIFFE-compliant identity token with user claims
JWT_TOKEN=$(vault read -field=token identity/oidc/token/human-identity)
```

### 3. **Call API with Token**

```bash
# Single authentication call to Kong - no backend service auth needed
curl -H "Host: localhost" \
     -H "Authorization: Bearer $JWT_TOKEN" \
     http://localhost:8000/api/get
```

**Key Advantage**: Instead of each backend service validating authentication individually, Kong validates once and forwards the request with user context headers. This eliminates the service → auth → service → auth chain common in distributed authentication.

## Token Structure

The JWT tokens issued by Vault contain structured claims that enable Kong's routing and authorization decisions:

```json
{
  "aud": "spiffe://kong-api-gateway",        ← Validates token is for this gateway
  "azp": "spiffe://vault/engineering/developer/demo-developer",
  "exp": 1754228088,
  "iat": 1754224488,
  "iss": "http://localhost:8200/v1/identity/oidc",
  "namespace": "root",
  "sub": "f388b783-8dec-031e-c344-6aaa18012c77",
  "userinfo": {                              ← Available to Kong for header-based routing
    "department": "engineering",             ← Enables department-based access control
    "entity_id": "f388b783-8dec-031e-c344-6aaa18012c77",
    "entity_name": "demo-developer",
    "role": "developer"                      ← Can be used for role-based routing
  }
}
```

**Gateway Integration**: Kong extracts these claims and can use them for routing decisions (e.g., route engineering users to v2 APIs), rate limiting per department, or A/B testing based on roles. The claims are also forwarded as HTTP headers to backend services, eliminating the need for services to decode tokens themselves.

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
  client_id="spiffe://kong-api-gateway" \
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
  --data "hosts[]=localhost" \
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
  --data "key=http://localhost:8200/v1/identity/oidc" \
  --data-urlencode "rsa_public_key@vault-public.pem"
```

## Demo Users

| Username | Password | Department | Role |
|----------|----------|------------|------|
| demodeveloper | password123 | engineering | developer |
| demosales | password123 | sales | manager |

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
docker compose logs kong-gateway

# Vault logs
docker compose logs vault-server
```

### Test JWT Token Decoding

```bash
echo "$JWT_TOKEN" | python3 decode-jwt.py
```

## Cleanup

```bash
# Stop all services
docker compose down

# Remove volumes (deletes databases)
docker compose down -v
```

## Production Considerations

1. **Vault High Availability**: Configure Vault clustering for production
2. **Kong Enterprise**: Consider Kong Enterprise for additional features
3. **TLS/SSL**: Enable HTTPS for all service communications
4. **Secret Management**: Use proper secret rotation and management
5. **Monitoring**: Implement comprehensive logging and monitoring
6. **Performance**: Tune JWT validation performance

## How This Architecture Solves Key Problems

### 🚫 **API Gateway Architectural Mismatch → SOLVED**
- **Before**: Backend services handle auth, blocking header-based routing
- **After**: Kong authenticates and exposes user claims as HTTP headers for intelligent routing, A/B testing, and policy decisions

### 📈 **Management Scalability Crisis → SOLVED** 
- **Before**: N services × M auth implementations = exponential complexity
- **After**: 2 centralized services (Vault + Kong) manage authentication for unlimited backend services

### ⚡ **Performance & Latency Overhead → SOLVED**
- **Before**: Multiple auth calls per request (service → auth → service → auth...)
- **After**: Single authentication validation at gateway, then direct service-to-service calls

### 🔧 **Operational Complexity → SOLVED**
- **Before**: Secret rotation across all services, complex network policies, auth service dependencies
- **After**: Backend services are stateless with no secrets, simplified deployment and testing

### 📋 **Compliance & Audit Challenges → SOLVED**
- **Before**: Scattered auth decisions across dozens of service logs
- **After**: Centralized audit trail through Kong access logs with complete user context

### **Additional Production Benefits**
- **Zero Trust**: Cryptographically signed tokens eliminate shared secrets
- **Standards Compliant**: Uses SPIFFE, JWT, and OIDC industry standards  
- **Cloud Native**: Works across Kubernetes, containers, and traditional infrastructure
- **Scalable**: Horizontal scaling of authentication without backend service changes
