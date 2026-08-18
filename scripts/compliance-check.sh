#!/bin/bash

set -e

echo "=========================================="
echo "       ZeroDowntime Compliance Gate"
echo "=========================================="

FAILED=0

# ==================================================
# Helper functions
# ==================================================

pass() {
    echo "PASS: $1"
}

fail() {
    echo "FAIL: $1"
    FAILED=1
}

# ==================================================
# 1. Required compliance files
# ==================================================

echo ""
echo "1. Checking required compliance files..."
echo "------------------------------------------"

REQUIRED_FILES=(
    "compliance/pci-dss.yml"
    "compliance/rbi.yml"
    "compliance/sod.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

# ==================================================
# 2. Kubernetes manifests
# ==================================================

echo ""
echo "2. Checking Kubernetes manifests..."
echo "------------------------------------------"

if [ -d "kubernetes" ]; then

    K8S_FILES=$(find kubernetes -type f \( \
        -name "*.yaml" -o \
        -name "*.yml" \
    \) 2>/dev/null || true)

    if [ -n "$K8S_FILES" ]; then
        pass "Kubernetes manifests found"
    else
        fail "No Kubernetes manifests found"
    fi

else
    fail "kubernetes directory is missing"
fi

# ==================================================
# 3. Mutable image tags
# ==================================================

echo ""
echo "3. Checking for mutable image tags..."
echo "------------------------------------------"

if [ -d "kubernetes" ]; then

    if grep -R -E "image:[[:space:]]*[^[:space:]]+:latest([[:space:]]|$)" \
        kubernetes/ >/dev/null 2>&1; then

        fail "'latest' image tag detected"

    else
        pass "No ':latest' image tags detected"
    fi

else
    fail "Cannot check image tags because kubernetes directory is missing"
fi

# ==================================================
# 4. Privileged containers
# ==================================================

echo ""
echo "4. Checking privileged containers..."
echo "------------------------------------------"

if [ -d "kubernetes" ]; then

    if grep -R -E "privileged:[[:space:]]*true" \
        kubernetes/ >/dev/null 2>&1; then

        fail "Privileged container detected"

    else
        pass "No privileged containers detected"
    fi

else
    fail "Cannot check privileged containers"
fi

# ==================================================
# 5. Host networking
# ==================================================

echo ""
echo "5. Checking host networking..."
echo "------------------------------------------"

if [ -d "kubernetes" ]; then

    if grep -R -E "hostNetwork:[[:space:]]*true" \
        kubernetes/ >/dev/null 2>&1; then

        fail "hostNetwork=true detected"

    else
        pass "hostNetwork is not enabled"
    fi

else
    fail "Cannot check host networking"
fi

# ==================================================
# 6. Liveness probe
# ==================================================

echo ""
echo "6. Checking liveness probes..."
echo "------------------------------------------"

if [ -d "kubernetes" ] && \
   grep -R "livenessProbe:" kubernetes/ >/dev/null 2>&1; then

    pass "livenessProbe found"

else
    fail "livenessProbe missing"
fi

# ==================================================
# 7. Readiness probe
# ==================================================

echo ""
echo "7. Checking readiness probes..."
echo "------------------------------------------"

if [ -d "kubernetes" ] && \
   grep -R "readinessProbe:" kubernetes/ >/dev/null 2>&1; then

    pass "readinessProbe found"

else
    fail "readinessProbe missing"
fi

# ==================================================
# 8. Resource limits
# ==================================================

echo ""
echo "8. Checking Kubernetes resource limits..."
echo "------------------------------------------"

if [ -d "kubernetes" ] && \
   grep -R "limits:" kubernetes/ >/dev/null 2>&1; then

    pass "Resource limits found"

else
    fail "Resource limits missing"
fi

# ==================================================
# 9. Security context
# ==================================================

echo ""
echo "9. Checking security context..."
echo "------------------------------------------"

if [ -d "kubernetes" ] && \
   grep -R "securityContext:" kubernetes/ >/dev/null 2>&1; then

    pass "securityContext found"

else
    fail "securityContext missing"
fi

# ==================================================
# 10. Database migrations
# ==================================================

echo ""
echo "10. Checking database migration controls..."
echo "------------------------------------------"

if [ -d "database/migrations" ]; then
    pass "Migration directory exists"
else
    fail "Migration directory missing"
fi

if [ -f "scripts/run-migrations.sh" ]; then
    pass "Migration runner exists"
else
    fail "Migration runner missing"
fi

# ==================================================
# 11. Test suite
# ==================================================

echo ""
echo "11. Checking test suite..."
echo "------------------------------------------"

if [ -d "tests" ]; then

    TEST_FILES=$(find tests -type f \( \
        -name "*.test.js" -o \
        -name "*.spec.js" \
    \) 2>/dev/null || true)

    if [ -n "$TEST_FILES" ]; then
        pass "Test files found"
    else
        fail "Tests directory exists but no test files were found"
    fi

elif [ -f "app.test.js" ]; then

    pass "app.test.js found"

else

    fail "Test structure missing"

fi

# ==================================================
# 12. Dockerfile
# ==================================================

echo ""
echo "12. Checking Dockerfile..."
echo "------------------------------------------"

if [ -f "Dockerfile" ]; then
    pass "Dockerfile exists"
else
    fail "Dockerfile missing"
fi

# ==================================================
# 13. Git secrets protection
# ==================================================

echo ""
echo "13. Checking .env protection..."
echo "------------------------------------------"

if [ -f ".gitignore" ]; then

    if grep -qxF ".env" .gitignore; then
        pass ".env is protected by .gitignore"
    else
        fail ".env is not listed in .gitignore"
    fi

else
    fail ".gitignore is missing"
fi

# ==================================================
# 14. Migration runner executable
# ==================================================

echo ""
echo "14. Checking migration runner..."
echo "------------------------------------------"

if [ -f "scripts/run-migrations.sh" ]; then

    if [ -x "scripts/run-migrations.sh" ]; then
        pass "Migration runner is executable"
    else
        echo "WARN: Migration runner is not executable"
        echo "      Run: chmod +x scripts/run-migrations.sh"
    fi

else
    fail "Migration runner does not exist"
fi

# ==================================================
# 15. Canary / Blue-Green deployment scripts
# ==================================================

echo ""
echo "15. Checking deployment automation..."
echo "------------------------------------------"

if [ -f "scripts/deploy-blue-green.sh" ]; then
    pass "Blue-Green deployment script exists"
else
    echo "WARN: Blue-Green deployment script not found"
fi

if [ -f "scripts/deploy-canary.sh" ]; then
    pass "Canary deployment script exists"
else
    echo "WARN: Canary deployment script not found"
fi

# ==================================================
# Final result
# ==================================================

echo ""
echo "=========================================="
echo "          COMPLIANCE SUMMARY"
echo "=========================================="

if [ "$FAILED" -eq 0 ]; then

    echo "COMPLIANCE GATE: PASSED"
    echo ""
    echo "All mandatory compliance checks passed."
    echo "Deployment may continue."
    echo "=========================================="

    exit 0

else

    echo "COMPLIANCE GATE: FAILED"
    echo ""
    echo "Mandatory compliance checks failed."
    echo "Deployment must be blocked."
    echo "=========================================="

    exit 1
fi