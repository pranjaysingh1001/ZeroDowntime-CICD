#!/bin/bash

set -e

REPORT_DIR="reports"
REPORT_FILE="$REPORT_DIR/compliance-report.txt"

mkdir -p "$REPORT_DIR"

echo "============================================" > "$REPORT_FILE"
echo " ZeroDowntime CI/CD Compliance Report" >> "$REPORT_FILE"
echo "============================================" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

echo "Generated At:" >> "$REPORT_FILE"
date -u >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

echo "Repository Commit:" >> "$REPORT_FILE"
git rev-parse HEAD >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

echo "--------------------------------------------" >> "$REPORT_FILE"
echo "COMPLIANCE POLICIES" >> "$REPORT_FILE"
echo "--------------------------------------------" >> "$REPORT_FILE"

for file in \
    compliance/pci-dss.yml \
    compliance/rbi.yml \
    compliance/sod.yml
do
    if [ -f "$file" ]; then
        echo "PASS - $file" >> "$REPORT_FILE"
    else
        echo "FAIL - $file" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"

echo "--------------------------------------------" >> "$REPORT_FILE"
echo "KUBERNETES SECURITY" >> "$REPORT_FILE"
echo "--------------------------------------------" >> "$REPORT_FILE"

if grep -R "image:.*:latest" kubernetes/ >/dev/null 2>&1; then
    echo "FAIL - Mutable image tag detected" >> "$REPORT_FILE"
else
    echo "PASS - No mutable image tags" >> "$REPORT_FILE"
fi

if grep -R "privileged:[[:space:]]*true" kubernetes/ >/dev/null 2>&1; then
    echo "FAIL - Privileged container detected" >> "$REPORT_FILE"
else
    echo "PASS - No privileged containers" >> "$REPORT_FILE"
fi

if grep -R "hostNetwork:[[:space:]]*true" kubernetes/ >/dev/null 2>&1; then
    echo "FAIL - hostNetwork enabled" >> "$REPORT_FILE"
else
    echo "PASS - hostNetwork disabled" >> "$REPORT_FILE"
fi

if grep -R "securityContext:" kubernetes/ >/dev/null 2>&1; then
    echo "PASS - securityContext configured" >> "$REPORT_FILE"
else
    echo "FAIL - securityContext missing" >> "$REPORT_FILE"
fi

if grep -R "livenessProbe:" kubernetes/ >/dev/null 2>&1; then
    echo "PASS - livenessProbe configured" >> "$REPORT_FILE"
else
    echo "FAIL - livenessProbe missing" >> "$REPORT_FILE"
fi

if grep -R "readinessProbe:" kubernetes/ >/dev/null 2>&1; then
    echo "PASS - readinessProbe configured" >> "$REPORT_FILE"
else
    echo "FAIL - readinessProbe missing" >> "$REPORT_FILE"
fi

if grep -R "limits:" kubernetes/ >/dev/null 2>&1; then
    echo "PASS - Resource limits configured" >> "$REPORT_FILE"
else
    echo "FAIL - Resource limits missing" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

echo "--------------------------------------------" >> "$REPORT_FILE"
echo "DATABASE MIGRATION CONTROLS" >> "$REPORT_FILE"
echo "--------------------------------------------" >> "$REPORT_FILE"

if [ -d "database/migrations" ]; then
    echo "PASS - Migration directory exists" >> "$REPORT_FILE"
else
    echo "FAIL - Migration directory missing" >> "$REPORT_FILE"
fi

if [ -f "scripts/run-migrations.sh" ]; then
    echo "PASS - Migration runner exists" >> "$REPORT_FILE"
else
    echo "FAIL - Migration runner missing" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

echo "--------------------------------------------" >> "$REPORT_FILE"
echo "SEGREGATION OF DUTIES" >> "$REPORT_FILE"
echo "--------------------------------------------" >> "$REPORT_FILE"

if [ -f "compliance/sod.yml" ]; then
    echo "PASS - SoD policy defined" >> "$REPORT_FILE"
else
    echo "FAIL - SoD policy missing" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

echo "--------------------------------------------" >> "$REPORT_FILE"
echo "FINAL RESULT" >> "$REPORT_FILE"
echo "--------------------------------------------" >> "$REPORT_FILE"

echo "Compliance gate execution completed." >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "============================================" >> "$REPORT_FILE"

echo "Report generated: $REPORT_FILE"

cat "$REPORT_FILE"