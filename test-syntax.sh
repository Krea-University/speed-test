#!/bin/bash

# Test script to verify heredoc syntax is correct
echo "🧪 Testing heredoc syntax in deploy.sh..."

# Count heredoc starts and ends
heredoc_starts_unquoted=$(grep -c "<<EOF" /Users/senthilnasa/Development/speed-test/deploy.sh)
heredoc_starts_quoted=$(grep -c "<<'EOF'" /Users/senthilnasa/Development/speed-test/deploy.sh)
heredoc_total_starts=$((heredoc_starts_unquoted + heredoc_starts_quoted))
heredoc_ends=$(grep -c "^EOF" /Users/senthilnasa/Development/speed-test/deploy.sh)

echo "📊 Heredoc analysis:"
echo "  Starts unquoted (<<EOF): $heredoc_starts_unquoted"
echo "  Starts quoted (<<'EOF'): $heredoc_starts_quoted"
echo "  Total starts: $heredoc_total_starts"
echo "  Ends (^EOF): $heredoc_ends"

if [[ $heredoc_total_starts -eq $heredoc_ends ]]; then
    echo "✅ Heredoc structure is balanced"
else
    echo "❌ Heredoc structure is unbalanced"
fi

# Test syntax
echo ""
echo "🔍 Testing syntax..."
if bash -n /Users/senthilnasa/Development/speed-test/deploy.sh; then
    echo "✅ Syntax check passed"
else
    echo "❌ Syntax check failed"
fi

echo ""
echo "🎉 All syntax tests completed!"
