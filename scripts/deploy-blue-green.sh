#!/bin/bash

set -e

echo "=============================================="
echo "       BLUE-GREEN DEPLOYMENT"
echo "=============================================="

GREEN_DEPLOYMENT="zerodowntime-green"
BLUE_VERSION="blue"
GREEN_VERSION="green"
SERVICE="zerodowntime-service"
HEALTH_PATH="/health"

echo ""
echo "1. Checking Kubernetes cluster..."
echo "----------------------------------------------"

if ! kubectl get nodes; then
    echo "ERROR: Kubernetes cluster is not available."
    exit 1
fi

echo "Kubernetes cluster is available."

echo ""
echo "2. Checking current Blue deployment..."
echo "----------------------------------------------"

if kubectl get deployment zerodowntime-blue >/dev/null 2>&1; then
    echo "Blue deployment exists."

    kubectl get deployment zerodowntime-blue

    BLUE_READY=$(kubectl get deployment zerodowntime-blue \
        -o jsonpath='{.status.readyReplicas}')

    if [ "${BLUE_READY:-0}" -lt 1 ]; then
        echo "ERROR: Blue deployment is not Ready."
        echo "Blue deployment must be healthy before deploying Green."
        exit 1
    fi

    echo "Blue deployment is healthy."
else
    echo "WARNING: Blue deployment does not exist."
fi

echo ""
echo "3. Checking Service..."
echo "----------------------------------------------"

if ! kubectl get service "$SERVICE" >/dev/null 2>&1; then
    echo "ERROR: Service $SERVICE does not exist."
    exit 1
fi

kubectl get service "$SERVICE"

echo ""
echo "Current service selector:"
kubectl get service "$SERVICE" \
    -o jsonpath='{.spec.selector}'
echo ""

echo ""
echo "4. Deploying Green..."
echo "----------------------------------------------"

if ! kubectl apply -f kubernetes/deployment-green.yaml; then
    echo "ERROR: Failed to deploy Green."
    echo "Blue remains active."
    exit 1
fi

echo "Green deployment applied successfully."

echo ""
echo "5. Waiting for Green rollout..."
echo "----------------------------------------------"

if kubectl rollout status deployment/"$GREEN_DEPLOYMENT" --timeout=180s; then
    echo "Green rollout completed."
else
    echo "ERROR: Green rollout FAILED."
    echo ""
    echo "Green deployment status:"
    kubectl get deployment "$GREEN_DEPLOYMENT"

    echo ""
    echo "Green pods:"
    kubectl get pods -l app=zerodowntime,version="$GREEN_VERSION"

    echo ""
    echo "Green deployment description:"
    kubectl describe deployment "$GREEN_DEPLOYMENT"

    echo ""
    echo "Blue remains active."
    exit 1
fi

echo ""
echo "6. Checking Green pod readiness..."
echo "----------------------------------------------"

GREEN_READY=$(kubectl get deployment "$GREEN_DEPLOYMENT" \
    -o jsonpath='{.status.readyReplicas}')

GREEN_DESIRED=$(kubectl get deployment "$GREEN_DEPLOYMENT" \
    -o jsonpath='{.spec.replicas}')

echo "Green desired replicas : ${GREEN_DESIRED:-0}"
echo "Green ready replicas   : ${GREEN_READY:-0}"

if [ "${GREEN_READY:-0}" -lt "${GREEN_DESIRED:-1}" ]; then
    echo "ERROR: Green does not have all required replicas Ready."
    echo "Blue remains active."
    exit 1
fi

echo "All Green replicas are Ready."

echo ""
echo "7. Showing Green pods..."
echo "----------------------------------------------"

kubectl get pods \
    -l app=zerodowntime,version="$GREEN_VERSION" \
    -o wide

echo ""
echo "8. Checking Green health endpoint..."
echo "----------------------------------------------"

GREEN_POD=$(kubectl get pods \
    -l app=zerodowntime,version="$GREEN_VERSION" \
    -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GREEN_POD" ]; then
    echo "ERROR: Could not find a Green pod."
    echo "Blue remains active."
    exit 1
fi

echo "Testing Green pod:"
echo "$GREEN_POD"

if kubectl exec "$GREEN_POD" -- \
    wget -qO- "http://localhost:3000${HEALTH_PATH}" >/dev/null; then

    echo "Green health check PASSED."

else

    echo "ERROR: Green health check FAILED."

    echo ""
    echo "Green pod logs:"
    kubectl logs "$GREEN_POD" --tail=100 || true

    echo ""
    echo "Green pod description:"
    kubectl describe pod "$GREEN_POD" || true

    echo ""
    echo "Blue remains active."
    exit 1
fi

echo ""
echo "9. Confirming Green service endpoints..."
echo "----------------------------------------------"

GREEN_ENDPOINTS=$(kubectl get endpoints "$SERVICE" \
    -o jsonpath='{.subsets[*].addresses[*].ip}')

echo "Current endpoints:"
echo "${GREEN_ENDPOINTS:-NONE}"

echo ""
echo "10. Switching traffic from Blue to Green..."
echo "----------------------------------------------"

if kubectl patch service "$SERVICE" \
    -p '{"spec":{"selector":{"app":"zerodowntime","version":"green"}}}'; then

    echo "Traffic successfully switched to Green."

else

    echo "ERROR: Failed to switch traffic."
    echo "Blue remains active."
    exit 1
fi

echo ""
echo "11. Verifying Service selector..."
echo "----------------------------------------------"

CURRENT_VERSION=$(kubectl get service "$SERVICE" \
    -o jsonpath='{.spec.selector.version}')

echo "Service version selector: $CURRENT_VERSION"

if [ "$CURRENT_VERSION" != "$GREEN_VERSION" ]; then
    echo "ERROR: Service is not pointing to Green."
    echo "Rolling back to Blue..."

    kubectl patch service "$SERVICE" \
        -p '{"spec":{"selector":{"app":"zerodowntime","version":"blue"}}}'

    echo "Traffic rolled back to Blue."
    exit 1
fi

echo "Service is pointing to Green."

echo ""
echo "12. Waiting for Green endpoints..."
echo "----------------------------------------------"

for i in {1..30}; do

    GREEN_ENDPOINTS=$(kubectl get endpoints "$SERVICE" \
        -o jsonpath='{.subsets[*].addresses[*].ip}')

    if [ -n "$GREEN_ENDPOINTS" ]; then
        echo "Green endpoints available:"
        echo "$GREEN_ENDPOINTS"
        break
    fi

    echo "Waiting for Green endpoints... ($i/30)"
    sleep 2

done

if [ -z "$GREEN_ENDPOINTS" ]; then

    echo "ERROR: No Green endpoints available."
    echo "Rolling back to Blue..."

    kubectl patch service "$SERVICE" \
        -p '{"spec":{"selector":{"app":"zerodowntime","version":"blue"}}}'

    echo "Traffic rolled back to Blue."
    exit 1
fi

echo ""
echo "13. Post-switch verification..."
echo "----------------------------------------------"

LIVE_POD=$(kubectl get pods \
    -l app=zerodowntime,version="$GREEN_VERSION" \
    -o jsonpath='{.items[0].metadata.name}')

if [ -z "$LIVE_POD" ]; then

    echo "ERROR: Green pod disappeared after traffic switch."
    echo "Rolling back to Blue..."

    kubectl patch service "$SERVICE" \
        -p '{"spec":{"selector":{"app":"zerodowntime","version":"blue"}}}'

    echo "Traffic rolled back to Blue."
    exit 1
fi

echo "Testing live Green pod:"
echo "$LIVE_POD"

if kubectl exec "$LIVE_POD" -- \
    wget -qO- "http://localhost:3000${HEALTH_PATH}" >/dev/null; then

    echo "Live Green health check PASSED."

else

    echo "ERROR: Live Green health check FAILED."
    echo "Rolling back to Blue..."

    kubectl patch service "$SERVICE" \
        -p '{"spec":{"selector":{"app":"zerodowntime","version":"blue"}}}'

    echo "Traffic successfully rolled back to Blue."
    exit 1
fi

echo ""
echo "14. Final deployment status..."
echo "----------------------------------------------"

kubectl get deployments

echo ""
echo "Green pods:"
kubectl get pods \
    -l app=zerodowntime,version="$GREEN_VERSION"

echo ""
echo "Blue pods:"
kubectl get pods \
    -l app=zerodowntime,version="$BLUE_VERSION"

echo ""
echo "Service:"
kubectl get service "$SERVICE"

echo ""
echo "Service endpoints:"
kubectl get endpoints "$SERVICE"

echo ""
echo "=============================================="
echo "   BLUE-GREEN DEPLOYMENT SUCCESSFUL"
echo "=============================================="
echo ""
echo "Traffic is now serving GREEN."
echo "Blue remains available for rollback."
echo ""