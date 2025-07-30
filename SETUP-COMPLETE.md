# Kong API Gateway Setup - Quick Reference

## 🎉 Success! Your Kong API Gateway is now running with JWT authentication

### What we've set up

1. **Kong Gateway** - Running on ports 8000-8002
2. **PostgreSQL Database** - Kong's data store
3. **HTTPBin Service** - Test backend service
4. **JWT Authentication** - Secure token-based API access

### Key URLs

- **API Gateway**: <http://localhost:8000> (with Host: api.local)
- **Kong Manager UI**: <http://localhost:8002>
- **Kong Admin API**: <http://localhost:8001>
- **Test Backend**: <http://localhost:8080>

### Your JWT Credentials

- **Consumer**: testuser
- **JWT Key**: `ewR0kknJAseqv2I7fJkSj8IRCHqXMOAM`
- **JWT Secret**: `ZITJz5KgsfB4WezPEkudGcC45i0uvKCZ`

### Sample JWT Token (1 hour validity)

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJld1Iwa2tuSkFzZXF2Mkk3ZkprU2o4SVJDSHFYTU9BTSIsImV4cCI6MTc1MzgyNDc5NywiaWF0IjoxNzUzODIxMTk3LCJzdWIiOiJ0ZXN0dXNlciIsIm5hbWUiOiJVc2VyIHRlc3R1c2VyIiwicm9sZSI6ImFkbWluIiwiZW1haWwiOiJ0ZXN0dXNlckBleGFtcGxlLmNvbSJ9.qF2uB-sHTTblbB8YjJ47T4M1qk36AS8LRzBHXSwz0Dg
```

## 🧪 Test Commands

### 1. Unauthenticated Request (should fail)

```bash
curl -H "Host: api.local" http://localhost:8000/api/get
# Expected: {"message":"Unauthorized"}
```

### 2. Authenticated GET Request

```bash
curl -H "Host: api.local" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:8000/api/get
```

### 3. Authenticated POST Request

```bash
curl -X POST \
     -H "Host: api.local" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello from Kong!"}' \
     http://localhost:8000/api/post
```

### 4. Generate New JWT Token

```bash
/Users/yuleiliu/unfinished-projects/vault-identity-token-demo/.venv/bin/python generate-jwt.py \
  --key "ewR0kknJAseqv2I7fJkSj8IRCHqXMOAM" \
  --secret "ZITJz5KgsfB4WezPEkudGcC45i0uvKCZ" \
  --user "testuser" \
  --role "admin"
```

## 🔍 What Kong Added to Your Requests

When you make authenticated requests, Kong automatically adds these headers to your backend:

- `X-Consumer-Id`: Kong consumer ID
- `X-Consumer-Username`: testuser
- `X-Credential-Identifier`: JWT key identifier
- `X-Forwarded-*`: Request routing information

This allows your backend services to:

1. Know who is making the request
2. Access user information from JWT claims
3. Implement additional authorization logic

## 🛠️ Next Steps

1. **Explore Kong Manager**: Visit <http://localhost:8002> to see the web interface
2. **Add More Plugins**: Rate limiting, CORS, request transformation
3. **Create More Services**: Add your own backend services
4. **Production Setup**: Use environment variables for secrets
5. **Monitoring**: Set up logging and analytics

## 🧹 Cleanup

When you're done testing:

```bash
# Stop all services
docker compose down

# Remove volumes (this deletes the database)
docker compose down -v
```

## 📚 Learn More

- Kong Documentation: <https://docs.konghq.com/>
- JWT Plugin: <https://docs.konghq.com/hub/kong-inc/jwt/>
- Kong Manager: <https://docs.konghq.com/gateway/latest/kong-manager/>

Congratulations! You now have a fully functional API Gateway with JWT authentication! 🎉
