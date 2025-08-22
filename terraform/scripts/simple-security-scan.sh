#!/bin/bash

# Simple Security Scan for CI/CD
set -e

echo "🔒 Running Checkov security scan..."

# Run Checkov and capture exit code
if checkov --config-file .checkov.yml -d . --compact --quiet; then
    echo "✅ Checkov security scan passed"
    echo "security_passed=true" >> $GITHUB_OUTPUT 2>/dev/null || true
    echo "compliance_passed=true" >> $GITHUB_OUTPUT 2>/dev/null || true
    exit 0
else
    echo "❌ Checkov security scan failed"
    echo "security_passed=false" >> $GITHUB_OUTPUT 2>/dev/null || true
    echo "compliance_passed=false" >> $GITHUB_OUTPUT 2>/dev/null || true
    exit 1
fi