#!/bin/bash
# Test script to verify standalone execution of smoke test and validation scripts

set -e

echo "========================================="
echo "Testing Standalone Script Execution"
echo "========================================="
echo ""

# Store the current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
REDMINE_ROOT="$(dirname "$(dirname "$PLUGIN_ROOT")")"

echo "Plugin root: $PLUGIN_ROOT"
echo "Redmine root: $REDMINE_ROOT"
echo ""

# Test 1: Run smoke test from plugin directory
echo "Test 1: Running smoke_test.rb from plugin directory..."
echo "========================================="
cd "$PLUGIN_ROOT"
if ruby bin/smoke_test.rb; then
    echo ""
    echo "✓ Test 1 PASSED: smoke_test.rb works from plugin directory"
else
    echo ""
    echo "✗ Test 1 FAILED: smoke_test.rb failed from plugin directory"
    exit 1
fi
echo ""
echo ""

# Test 2: Run smoke test from Redmine root
echo "Test 2: Running smoke_test.rb from Redmine root..."
echo "========================================="
cd "$REDMINE_ROOT"
if ruby plugins/redmine_mcp/bin/smoke_test.rb; then
    echo ""
    echo "✓ Test 2 PASSED: smoke_test.rb works from Redmine root"
else
    echo ""
    echo "✗ Test 2 FAILED: smoke_test.rb failed from Redmine root"
    exit 1
fi
echo ""
echo ""

# Test 3: Run validation script from plugin directory
echo "Test 3: Running validate_installation.rb from plugin directory..."
echo "========================================="
cd "$PLUGIN_ROOT"
if ruby bin/validate_installation.rb; then
    echo ""
    echo "✓ Test 3 PASSED: validate_installation.rb works from plugin directory"
else
    echo ""
    echo "✗ Test 3 FAILED: validate_installation.rb failed from plugin directory"
    exit 1
fi
echo ""
echo ""

# Test 4: Run validation script from Redmine root
echo "Test 4: Running validate_installation.rb from Redmine root..."
echo "========================================="
cd "$REDMINE_ROOT"
if ruby plugins/redmine_mcp/bin/validate_installation.rb; then
    echo ""
    echo "✓ Test 4 PASSED: validate_installation.rb works from Redmine root"
else
    echo ""
    echo "✗ Test 4 FAILED: validate_installation.rb failed from Redmine root"
    exit 1
fi
echo ""
echo ""

echo "========================================="
echo "ALL TESTS PASSED!"
echo "========================================="
echo ""
echo "Both scripts work correctly in standalone mode:"
echo "  ✓ smoke_test.rb"
echo "  ✓ validate_installation.rb"
echo ""
echo "They can be run from:"
echo "  ✓ Plugin directory"
echo "  ✓ Redmine root directory"
echo ""
