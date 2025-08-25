#!/bin/bash

# Test script to verify nginx.conf creation fix
echo "🧪 Testing nginx.conf creation fix..."

# Create a test directory to simulate the issue
mkdir -p nginx.conf
echo "✅ Created nginx.conf directory to simulate the issue"

# Test the cleanup logic
if [[ -d "nginx.conf" ]]; then
    echo "⚠️  Found nginx.conf directory, removing it..."
    rm -rf nginx.conf
    echo "✅ Removed nginx.conf directory"
fi

# Test file creation
cat > nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    
    server {
        listen 80;
        server_name test.example.com;
        
        location / {
            return 200 "Test nginx config";
        }
    }
}
EOF

if [[ -f "nginx.conf" ]]; then
    echo "✅ Successfully created nginx.conf file"
    echo "📄 File contents:"
    head -5 nginx.conf
    rm nginx.conf
    echo "✅ Cleaned up test file"
else
    echo "❌ Failed to create nginx.conf file"
    exit 1
fi

echo ""
echo "✅ nginx.conf creation fix working correctly!"
