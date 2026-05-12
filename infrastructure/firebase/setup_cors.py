#!/usr/bin/env python3
"""Configure CORS on Firebase Storage bucket for local development."""

import json
import sys
from google.cloud import storage
from google.auth import default

# CORS configuration
cors_config = [
    {
        "origin": ["http://localhost:8081", "http://localhost:8082", "http://localhost:8083", "http://localhost:8084"],
        "method": ["GET", "HEAD", "DELETE"],
        "responseHeader": ["Content-Type", "Cache-Control"],
        "maxAgeSeconds": 3600
    },
    {
        "origin": ["https://*.web.app", "https://*.firebaseapp.com"],
        "method": ["GET", "HEAD", "DELETE"],
        "responseHeader": ["Content-Type", "Cache-Control"],
        "maxAgeSeconds": 3600
    }
]

def set_bucket_cors():
    """Set CORS configuration on the Firebase Storage bucket."""
    bucket_name = "suklu-prod.firebasestorage.app"
    
    try:
        # Use Application Default Credentials (ADC)
        credentials, project = default()
        print(f"✓ Using credentials for project: {project}")
        
        # Create storage client
        client = storage.Client(credentials=credentials, project=project)
        bucket = client.bucket(bucket_name)
        
        print(f"✓ Connected to bucket: {bucket_name}")
        
        # Set CORS
        bucket.cors = cors_config
        bucket.patch()
        
        print("✓ CORS configuration applied successfully!")
        print("\nCORS rules:")
        for rule in cors_config:
            print(f"  Origins: {rule['origin']}")
            print(f"  Methods: {rule['method']}")
            print()
        
        return True
        
    except Exception as e:
        print(f"✗ Error: {e}")
        print("\nMake sure you're authenticated with: gcloud auth application-default login")
        return False

if __name__ == "__main__":
    success = set_bucket_cors()
    sys.exit(0 if success else 1)
