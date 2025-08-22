# Checkov Command Reference

## ✅ Correct Syntax (Used in Workflow)

### Basic Scan
```bash
checkov -d . --output cli --output json --output-file checkov_results.json
```

### With Configuration File
```bash
checkov --config-file .checkov.yml -d . --output cli --output json --output-file checkov_results.json
```

### Framework-Specific Scan
```bash
checkov -f . --framework terraform
```

## ❌ Invalid Arguments (Fixed)

### Old (Incorrect) Syntax
```bash
# These arguments don't exist in Checkov
--output-file-path .
--output-file-name checkov_results.json
--severity=CRITICAL --severity=HIGH --severity=MEDIUM
```

### New (Correct) Syntax
```bash
# Use these instead
--output-file checkov_results.json
# Severity filtering is done through configuration file or check selection
```

## 🔧 Common Checkov Options

### Output Formats
```bash
--output cli          # Console output
--output json         # JSON format
--output junit        # JUnit XML format
--output sarif        # SARIF format
```

### Scan Targets
```bash
-d DIRECTORY         # Scan directory
-f FILE              # Scan specific file
--framework terraform # Scan only Terraform files
```

### Configuration
```bash
--config-file FILE   # Use configuration file
--check CHECK_ID     # Run specific checks
--skip-check CHECK_ID # Skip specific checks
```

### Filtering
```bash
--compact            # Compact output
--quiet              # Minimal output
--soft-fail          # Don't exit with error code
```

## 📋 Example .checkov.yml Configuration

```yaml
# .checkov.yml
framework:
  - terraform

output:
  - cli
  - json

soft-fail: false

skip-check:
  - CKV_AWS_79  # Example: Skip specific check

check:
  - CKV_AWS_*   # Example: Run only AWS checks

# Note: Severity filtering is not supported in configuration
# Use check patterns or skip-check to control which checks run
```

## 🚀 Integration in CI/CD

### GitHub Actions (Current Implementation)
```yaml
- name: Security Scan with Checkov
  run: |
    pip install checkov
    
    if [ -f ".checkov.yml" ]; then
      checkov --config-file .checkov.yml -d . --output cli --output json --output-file checkov_results.json
    else
      checkov -d . --output cli --output json --output-file checkov_results.json
    fi
```

### Local Development
```bash
# Install Checkov
pip install checkov

# Run scan
cd terraform
checkov -d . --output cli

# Generate report
checkov -d . --output json --output-file security-report.json
```

## 🔍 Result Analysis

### JSON Output Structure
```json
{
  "results": {
    "passed_checks": [...],
    "failed_checks": [...],
    "skipped_checks": [...]
  },
  "summary": {
    "passed": 10,
    "failed": 2,
    "skipped": 1
  }
}
```

### Parsing Results
```bash
# Count failed checks
jq -r '.results.failed_checks | length' checkov_results.json

# Get specific failures
jq -r '.results.failed_checks[].check_id' checkov_results.json

# Summary
jq -r '.summary' checkov_results.json
```

---

*This reference covers the correct Checkov syntax used in the optimized CI/CD pipeline.*