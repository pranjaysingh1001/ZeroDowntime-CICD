#!/bin/bash

set -e

echo "=============================================="
echo "        CANARY DEPLOYMENT"
echo "=============================================="

# ------------------------------------------------
# Configuration
# ------------------------------------------------

GREEN_DEPLOYMENT="zerodowntime-green"
GREEN_SERVICE="zerodowntime-green-service"

BLUE_SERVICE="zerodowntime-blue-service"

CANARY_INGRESS="kubernetes/canary-blue-ingress.yaml"

NAMESPACE="default"

echo ""
echo "Configuration:"
echo "Green Deployment : $GREEN_DEPLOYMENT"
echo "Green Service     : $GREEN_SERVICE"
echo "Blue Service      : $BLUE_SERVICE"
echo "Canary Ingress    : $CANARY_INGRESS"

# ------------------------------------------------
# Stage 0 - Check Kubernetes
# ------------------------------------------------

echo ""
echo "=============================================="
echo "1. Checking Kubernetes cluster..."
echo "=============================================="

if ! kubectl get nodes; then
    echo "ERROR: Kubernetes cluster is not available."
    exit 1
fi

echo "Kubernetes cluster is available."

# ------------------------------------------------
# Stage 1 - Check Green Deployment
# ------------------------------------------------

echo ""
echo "=============================================="
echo "2. Deploying Green environment..."
echo "=============================================="

if ! kubectl apply -f kubernetes/deployment-green.yaml; then
    echo "ERROR: Failed to deploy Green."
    exit 1
fi

echo "Green deployment applied successfully."

# ------------------------------------------------
# Stage 2 - Wait for Green rollout
# ------------------------------------------------

echo ""
echo "=============================================="
echo "3. Waiting for Green rollout..."
echo "=============================================="

if kubectl rollout status deployment/$GREEN_DEPLOYMENT --timeout=180s; then
    echo "Green rollout completed successfully."
else
    echo "ERROR: Green rollout failed."
    echo "Blue remains active."
    exit 1
fi

# ------------------------------------------------
# Stage 3 - Check Green replicas
# ------------------------------------------------

echo ""
echo "=============================================="
echo "4. Checking Green pod readiness..."
echo "=============================================="

DESIRED=$(kubectl get deployment "$GREEN_DEPLOYMENT" \
    -o jsonpath='{.spec.replicas}')

READY=$(kubectl get deployment "$GREEN_DEPLOYMENT" \
    -o jsonpath='{.status.readyReplicas}')

DESIRED=${DESIRED:-0}
READY=${READY:-0}

echo "Green desired replicas : $DESIRED"
echo "Green ready replicas   : $READY"

if [ "$READY" -ne "$DESIRED" ]; then
    echo "ERROR: Green pods are not fully ready."
    echo "Blue remains active."
    exit 1
fi

echo "All Green replicas are Ready."

# ------------------------------------------------
# Stage 4 - Show Green pods
# ------------------------------------------------

echo ""
echo "=============================================="
echo "5. Green pods..."
echo "=============================================="

kubectl get pods \
    -l app=zerodowntime,version=green \
    -o wide

# ------------------------------------------------
# Stage 5 - Apply Services
# ------------------------------------------------

echo ""
echo "=============================================="
echo "6. Applying Blue and Green services..."
echo "=============================================="

if ! kubectl apply \
    -f kubernetes/service-blue.yaml \
    -f kubernetes/service-green.yaml; then

    echo "ERROR: Failed to apply services."
    echo "Blue remains active."
    exit 1
fi

echo "Blue and Green services applied successfully."

# ------------------------------------------------
# Stage 6 - Apply Canary Ingress
# ------------------------------------------------

echo ""
echo "=============================================="
echo "7. Applying Canary Ingress..."
echo "=============================================="

if [ ! -f "$CANARY_INGRESS" ]; then
    echo "ERROR: Canary ingress file not found:"
    echo "$CANARY_INGRESS"
    exit 1
fi

if ! kubectl apply -f "$CANARY_INGRESS"; then
    echo "ERROR: Failed to apply Canary Ingress."
    echo "Blue remains active."
    exit 1
fi

echo "Canary Ingress applied successfully."

# ------------------------------------------------
# Function: Green Health Check
# ------------------------------------------------

green_health_check() {

    CHECK_NAME="green-health-check-$(date +%s)"

    echo ""
    echo "Running Green health check..."

    if kubectl run "$CHECK_NAME" \
        --restart=Never \
        --image=curlimages/curl:8.10.1 \
        --command \
        --attach \
        --rm \
        -- \
        curl --fail --silent --show-error \
        "http://$GREEN_SERVICE/health"; then

        echo ""
        echo "Green health check PASSED."
        return 0

    else

        echo ""
        echo "Green health check FAILED."
        return 1
    fi
}

# ------------------------------------------------
# Function: Set Canary Weight
# ------------------------------------------------

set_canary_weight() {

    WEIGHT=$1

    echo ""
    echo "Setting Green traffic to ${WEIGHT}%..."

    kubectl annotate ingress \
        zerodowntime-green-canary \
        nginx.ingress.kubernetes.io/canary-weight="$WEIGHT" \
        --overwrite

    echo "Green traffic is now configured for ${WEIGHT}%."
}

# ------------------------------------------------
# Function: Rollback Canary
# ------------------------------------------------

rollback_canary() {

    echo ""
    echo "=============================================="
    echo "ROLLING BACK CANARY"
    echo "=============================================="

    echo "Setting Green traffic to 0%..."

    kubectl annotate ingress \
        zerodowntime-green-canary \
        nginx.ingress.kubernetes.io/canary-weight="0" \
        --overwrite

    echo "Green traffic set to 0%."

    echo "Blue remains active."

    echo ""
    echo "Current ingress configuration:"
    kubectl get ingress

    exit 1
}

# ------------------------------------------------
# Stage 8 - 10% Canary
# ------------------------------------------------

echo ""
echo "=============================================="
echo "8. CANARY STAGE - 10% GREEN"
echo "=============================================="

set_canary_weight 10

if ! green_health_check; then

    echo "ERROR: 10% Canary health check failed."

    rollback_canary
fi

echo "10% Canary PASSED."

# ------------------------------------------------
# Stage 9 - 25% Canary
# ------------------------------------------------

echo ""
echo "=============================================="
echo "9. CANARY STAGE - 25% GREEN"
echo "=============================================="

set_canary_weight 25

if ! green_health_check; then

    echo "ERROR: 25% Canary health check failed."

    rollback_canary
fi

echo "25% Canary PASSED."

# ------------------------------------------------
# Stage 10 - 50% Canary
# ------------------------------------------------

echo ""
echo "=============================================="
echo "10. CANARY STAGE - 50% GREEN"
echo "=============================================="

set_canary_weight 50

if ! green_health_check; then

    echo "ERROR: 50% Canary health check failed."

    rollback_canary
fi

echo "50% Canary PASSED."

# ------------------------------------------------
# Stage 11 - 100% Green
# ------------------------------------------------

echo ""
echo "=============================================="
echo "11. CANARY STAGE - 100% GREEN"
echo "=============================================="

set_canary_weight 100

if ! green_health_check; then

    echo "ERROR: 100% Green health check failed."

    rollback_canary
fi

echo "100% Green health check PASSED."

# ------------------------------------------------
# Stage 12 - Verify Ingress
# ------------------------------------------------

echo ""
echo "=============================================="
echo "12. Verifying Ingress..."
echo "=============================================="

kubectl get ingress

echo ""
echo "Canary Ingress annotations:"

kubectl get ingress zerodowntime-green-canary \
    -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'

echo "%"

# ------------------------------------------------
# Stage 13 - Verify Green Service
# ------------------------------------------------

echo ""
echo "=============================================="
echo "13. Verifying Green service..."
echo "=============================================="

kubectl get service "$GREEN_SERVICE"

echo ""
echo "Green service endpoints:"

kubectl get endpoints "$GREEN_SERVICE" 2>/dev/null || true

# ------------------------------------------------
# Stage 14 - Final Status
# ------------------------------------------------

echo ""
echo "=============================================="
echo "14. Final Deployment Status"
echo "=============================================="

kubectl get deployments

echo ""
echo "Green pods:"

kubectl get pods \
    -l app=zerodowntime,version=green \
    -o wide

echo ""
echo "Blue pods:"

kubectl get pods \
    -l app=zerodowntime,version=blue \
    -o wide

echo ""
echo "Ingress:"

kubectl get ingress

# ------------------------------------------------
# Success
# ------------------------------------------------

echo ""
echo "=============================================="
echo "       CANARY DEPLOYMENT SUCCESSFUL"
echo "=============================================="

echo ""
echo "Traffic distribution:"
echo "100% GREEN"
echo ""
echo "Blue environment remains available for rollback."
echo ""
echo "=============================================="