#!/usr/bin/env python3

import json
import sys
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

def jwk_to_pem(jwk_data):
    """Convert JWK to PEM format"""
    
    # Decode the base64url encoded values
    def base64url_decode(data):
        # Add padding if needed
        missing_padding = len(data) % 4
        if missing_padding:
            data += '=' * (4 - missing_padding)
        return base64.urlsafe_b64decode(data)
    
    n = base64url_decode(jwk_data['n'])
    e = base64url_decode(jwk_data['e'])
    
    # Convert to integers
    n_int = int.from_bytes(n, byteorder='big')
    e_int = int.from_bytes(e, byteorder='big')
    
    # Create RSA public key
    public_key = rsa.RSAPublicNumbers(e_int, n_int).public_key()
    
    # Convert to PEM format
    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    
    return pem.decode('utf-8')

if __name__ == "__main__":
    jwk_str = sys.stdin.read()
    jwk_data = json.loads(jwk_str)
    pem = jwk_to_pem(jwk_data)
    print(pem, end='')
