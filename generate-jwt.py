# Kong JWT Token Generator
# This script generates JWT tokens for testing Kong API Gateway

import jwt
import json
from datetime import datetime, timedelta
import argparse

def generate_jwt_token(key, secret, user_id="testuser", role="user", hours=1):
    """Generate a JWT token for Kong authentication"""
    
    # JWT payload
    payload = {
        'iss': key,  # Issuer (Kong consumer key)
        'exp': int((datetime.utcnow() + timedelta(hours=hours)).timestamp()),
        'iat': int(datetime.utcnow().timestamp()),
        'sub': user_id,
        'name': f'User {user_id}',
        'role': role,
        'email': f'{user_id}@example.com'
    }
    
    # Generate token
    token = jwt.encode(payload, secret, algorithm='HS256')
    
    return token, payload

def main():
    parser = argparse.ArgumentParser(description='Generate JWT tokens for Kong')
    parser.add_argument('--key', required=True, help='Kong consumer key')
    parser.add_argument('--secret', required=True, help='Kong consumer secret')
    parser.add_argument('--user', default='testuser', help='User ID')
    parser.add_argument('--role', default='user', help='User role')
    parser.add_argument('--hours', type=int, default=1, help='Token validity in hours')
    
    args = parser.parse_args()
    
    token, payload = generate_jwt_token(
        args.key, 
        args.secret, 
        args.user, 
        args.role, 
        args.hours
    )
    
    print("=" * 60)
    print("JWT Token Generated Successfully!")
    print("=" * 60)
    print(f"Token: {token}")
    print("\nPayload:")
    print(json.dumps(payload, indent=2))
    print("\nTest Command:")
    print(f'curl -H "Host: api.local" -H "Authorization: Bearer {token}" http://localhost:8000/api/get')
    print("=" * 60)

if __name__ == "__main__":
    main()
