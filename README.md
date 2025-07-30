# Kong API Gateway Demo

This project demonstrates how to set up Kong API Gateway with JWT authentication using Docker.

## Quick Start

### 1. Start Kong Gateway

```bash
# Start all services
docker-compose up -d

# Check if services are running
docker-compose ps
```

### 2. Configure Kong

```bash
# Make the setup script executable
chmod +x setup-kong.sh

# Run the setup script
./setup-kong.sh
```

### 3. Add Host Entry

Add this line to your `/etc/hosts` file:

```text
127.0.0.1 api.local
```

### 4. Test the API

The setup script will generate a JWT token. Use it to test:

```bash
# Test without token (should fail with 401)
curl -H "Host: api.local" http://localhost:8000/api/get

# Test with JWT token (should succeed)
curl -H "Host: api.local" -H "Authorization: Bearer YOUR_JWT_TOKEN" http://localhost:8000/api/get
```

## Kong Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Kong Proxy | 8000 | Main gateway endpoint |
| Kong Admin API | 8001 | Admin API for configuration |
| Kong Manager | 8002 | Web UI for Kong management |
| PostgreSQL | 5432 | Kong's database |
| HTTPBin | 8080 | Sample backend service |

## JWT Configuration

The setup includes:

- **Algorithm**: HS256
- **Issuer**: Kong consumer key
- **Claims**: Standard JWT claims (iss, exp, iat, sub)
- **Custom Claims**: name, role (for additional authorization)

## Manual Configuration Examples

### Create a Service

```bash
curl -i -X POST http://localhost:8001/services/ \
  --data "name=my-service" \
  --data "url=http://backend:80"
```

### Create a Route

```bash
curl -i -X POST http://localhost:8001/services/my-service/routes \
  --data "hosts[]=api.example.com" \
  --data "paths[]=/v1"
```

### Enable JWT Plugin

```bash
curl -i -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp,iss" \
  --data "config.key_claim_name=iss"
```

### Create Consumer and JWT Credentials

```bash
# Create consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=api-user"

# Create JWT credentials
curl -i -X POST http://localhost:8001/consumers/api-user/jwt \
  --data "algorithm=HS256" \
  --data "key=my-app-key"
```

## Generating JWT Tokens

### Using Python

```python
import jwt
from datetime import datetime, timedelta

payload = {
    'iss': 'your-kong-key',
    'exp': int((datetime.utcnow() + timedelta(hours=1)).timestamp()),
    'iat': int(datetime.utcnow().timestamp()),
    'sub': 'user123',
    'role': 'admin'
}

token = jwt.encode(payload, 'your-kong-secret', algorithm='HS256')
```

### Using Node.js

```javascript
const jwt = require('jsonwebtoken');

const payload = {
    iss: 'your-kong-key',
    exp: Math.floor(Date.now() / 1000) + (60 * 60), // 1 hour
    iat: Math.floor(Date.now() / 1000),
    sub: 'user123',
    role: 'admin'
};

const token = jwt.sign(payload, 'your-kong-secret', { algorithm: 'HS256' });
```

## Common Kong Plugins for API Security

### Rate Limiting

```bash
curl -i -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=100" \
  --data "config.hour=1000"
```

### CORS

```bash
curl -i -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=cors" \
  --data "config.origins=*" \
  --data "config.methods=GET,POST,PUT,DELETE" \
  --data "config.headers=Accept,Authorization,Content-Type"
```

### Request Size Limiting

```bash
curl -i -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=request-size-limiting" \
  --data "config.allowed_payload_size=1"
```

## Cleanup

```bash
# Stop and remove all containers
docker-compose down

# Remove volumes (this will delete the database)
docker-compose down -v
```

## Troubleshooting

### Check Kong Status

```bash
curl http://localhost:8001/status
```

### View Kong Logs

```bash
docker-compose logs kong
```

### List All Services

```bash
curl http://localhost:8001/services
```

### List All Routes

```bash
curl http://localhost:8001/routes
```

### List All Consumers

```bash
curl http://localhost:8001/consumers
```

## Next Steps

1. **Production Setup**: Use environment variables for secrets
2. **SSL/TLS**: Configure HTTPS certificates
3. **Custom Plugins**: Develop custom Kong plugins
4. **Monitoring**: Set up logging and monitoring
5. **Load Balancing**: Configure upstream services
6. **Advanced Auth**: Integrate with OAuth2, OIDC, or LDAP
