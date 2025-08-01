#!/usr/bin/env python3
"""
JWT Token Decoder
Decodes and displays JWT token payload with proper base64 padding handling
"""

import base64
import json
import sys

def decode_jwt_payload(token):
    """
    Decode JWT payload with proper base64 padding handling
    
    Args:
        token (str): JWT token string
        
    Returns:
        dict: Decoded payload as dictionary
    """
    try:
        # Split token into header, payload, signature
        parts = token.split('.')
        if len(parts) != 3:
            raise ValueError("Invalid JWT format - should have 3 parts separated by dots")
        
        # Get payload (second part)
        payload = parts[1]
        
        # Add padding if needed for proper base64 decoding
        missing_padding = len(payload) % 4
        if missing_padding:
            payload += '=' * (4 - missing_padding)
        
        # Decode base64
        decoded_bytes = base64.urlsafe_b64decode(payload.encode())
        decoded_str = decoded_bytes.decode('utf-8')
        
        # Parse JSON
        parsed = json.loads(decoded_str)
        
        return parsed
        
    except Exception as e:
        raise Exception(f"Failed to decode JWT payload: {str(e)}")

def main():
    """Main function to read token from stdin and decode it"""
    try:
        # Read token from stdin
        token = sys.stdin.read().strip()
        
        if not token:
            print("Error: No token provided via stdin", file=sys.stderr)
            sys.exit(1)
        
        # Decode the payload
        payload = decode_jwt_payload(token)
        
        # Pretty print the payload
        print("🔍 Token payload (decoded):")
        print(json.dumps(payload, indent=2))
        
    except Exception as e:
        print(f"Could not decode token payload: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
