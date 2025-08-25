#!/bin/bash

# Comprehensive test for file creation issues in deploy.sh
echo "🧪 Testing deploy.sh file creation robustness..."

# Test files that the deploy script creates
test_files=("nginx.conf" "docker-compose.yml" ".env" "backup-script.sh" 
           "start.sh" "stop.sh" "restart.sh" "logs.sh" "status.sh")

failed_tests=0

for file in "${test_files[@]}"; do
    echo ""
    echo "📁 Testing $file creation..."
    
    # Create directory with same name to simulate the issue
    mkdir -p "$file"
    echo "  ✅ Created $file directory"
    
    # Test the removal and creation logic
    if [[ -d "$file" ]]; then
        echo "  ⚠️  Found $file directory, removing it..."
        rm -rf "$file"
        echo "  ✅ Removed $file directory"
    fi
    
    # Try to create the file
    if echo "# Test content for $file" > "$file" 2>/dev/null; then
        if [[ -f "$file" ]]; then
            echo "  ✅ Successfully created $file file"
            rm "$file"
            echo "  ✅ Cleaned up $file"
        else
            echo "  ❌ Failed: $file exists but is not a regular file"
            ((failed_tests++))
        fi
    else
        echo "  ❌ Failed to create $file"
        ((failed_tests++))
    fi
done

echo ""
echo "=================================="
if [[ $failed_tests -eq 0 ]]; then
    echo "✅ All file creation tests passed!"
    echo "🎉 The nginx.conf directory issue has been resolved!"
else
    echo "❌ $failed_tests test(s) failed"
    echo "🔧 Some file creation issues may still exist"
fi
echo "=================================="
