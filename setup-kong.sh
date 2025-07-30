#!/bin/bash

# Kong Gateway Setup Script
# This script demonstrates how to configure Kong with JWT authentication

echo "🚀 Starting Kong Gateway setup..."

# Wait for Kong to be ready
echo "⏳ Waiting for Kong to be ready..."
until curl -f http://localhost:8001/status > /dev/null 2>&1; do
    echo "Waiting for Kong Admin API..."
    sleep 5
done

echo "✅ Kong is ready!"

# 1. Create a service
echo "📝 Creating a service..."
curl -i -X POST http://localhost:8001/services/ \
  --data "name=httpbin-service" \
  --data "url=http://httpbin:80"

# 2. Create a route for the service
echo "🛣️ Creating a route..."
curl -i -X POST http://localhost:8001/services/httpbin-service/routes \
  --data "hosts[]=api.local" \
  --data "paths[]=/api"

# 3. Enable JWT plugin
echo "🔐 Enabling JWT plugin..."
curl -i -X POST http://localhost:8001/services/httpbin-service/plugins \
  --data "name=jwt"

# 4. Create a consumer
echo "👤 Creating a consumer..."
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=testuser"

# 5. Create JWT credentials for the consumer
echo "🔑 Creating JWT credentials..."
JWT_RESPONSE=$(curl -s -X POST http://localhost:8001/consumers/testuser/jwt \
  --data "algorithm=HS256")

# Extract key and secret from response
JWT_KEY=$(echo $JWT_RESPONSE | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
JWT_SECRET=$(echo $JWT_RESPONSE | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)

echo "📋 JWT Credentials created:"
echo "Key: $JWT_KEY"
echo "Secret: $JWT_SECRET"

# 6. Generate a sample JWT token using Python
echo "🎫 Generating sample JWT token..."
python3 -c "
import jwt
import json
from datetime import datetime, timedelta

# JWT payload
payload = {
    'iss': '$JWT_KEY',
    'exp': int((datetime.utcnow() + timedelta(hours=1)).timestamp()),
    'iat': int(datetime.utcnow().timestamp()),
    'sub': 'testuser',
    'name': 'Test User',
    'role': 'user'
}

# Generate token
token = jwt.encode(payload, '$JWT_SECRET', algorithm='HS256')
print('Generated JWT Token:')
print(token)
print()
print('Test the API with:')
print('curl -H \"Host: api.local\" -H \"Authorization: Bearer ' + token + '\" http://localhost:8000/api/get')
"

echo ""
echo "✅ Kong setup complete!"
echo ""
echo "📊 Access Kong Manager: http://localhost:8002"
echo "🔧 Admin API: http://localhost:8001"
echo "🌐 Gateway Proxy: http://localhost:8000"
echo "🧪 Test Backend: http://localhost:8080"
echo ""
echo "To test your setup:"
echo "1. Add 'api.local' to your /etc/hosts file pointing to 127.0.0.1"
echo "2. Use the generated JWT token to make authenticated requests"
