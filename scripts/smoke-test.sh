#!/usr/bin/env bash
# Smoke test script for microservice-cicd-kubernetes
# Tests all three microservices: health checks, authentication, verification, data retrieval, and job dispatch.

set -euo pipefail

BASE_URL="${1:-}"
AUTH_URL="${BASE_URL:-http://localhost:5001}"
API_URL="${BASE_URL:-http://localhost:5002}"
WORKER_URL="${BASE_URL:-http://localhost:5003}"

# If an ingress or unified base URL is passed (e.g. http://localhost or http://minikube-ip), adjust paths
if [ -n "$BASE_URL" ]; then
    AUTH_URL="$BASE_URL/auth"
    API_URL="$BASE_URL/api"
    WORKER_URL="$BASE_URL/worker"
fi

echo "=================================================="
echo " Starting Microservices Smoke Test"
echo " Auth Endpoint:   $AUTH_URL"
echo " API Endpoint:    $API_URL"
echo " Worker Endpoint: $WORKER_URL"
echo "=================================================="

# 1. Health Checks
echo -n "[1/5] Checking Auth Service Health... "
curl -sf "$AUTH_URL/health" > /dev/null && echo "PASSED" || { echo "FAILED"; exit 1; }

echo -n "[2/5] Checking API Service Health... "
curl -sf "$API_URL/health" > /dev/null && echo "PASSED" || { echo "FAILED"; exit 1; }

echo -n "[3/5] Checking Worker Service Health... "
curl -sf "$WORKER_URL/health" > /dev/null && echo "PASSED" || { echo "FAILED"; exit 1; }

# 2. Authentication & JWT Verification
echo -n "[4/5] Testing User Authentication & Token Issuance... "
LOGIN_RESPONSE=$(curl -sf -X POST "$AUTH_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || true)

if [ -z "$TOKEN" ]; then
    echo "FAILED (No access token returned)"
    exit 1
fi
echo "PASSED (Token generated)"

echo -n "      Verifying JWT Token... "
VERIFY_RESPONSE=$(curl -sf -X POST "$AUTH_URL/verify" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}")

if echo "$VERIFY_RESPONSE" | grep -q '"valid":true'; then
    echo "PASSED"
else
    echo "FAILED (Token validation failed)"
    exit 1
fi

# 3. Data Service Retrieval & Creation
echo -n "[5/5] Testing API Data & Worker Queue... "
# If route rewrite or direct route
curl -sf "$API_URL/data" > /dev/null || curl -sf "$API_URL/api/data" > /dev/null
echo -n "API Data PASSED, "

WORKER_JOB_RESPONSE=$(curl -sf -X POST "$WORKER_URL/jobs" \
  -H "Content-Type: application/json" \
  -d '{"task_type": "smoke_test_verification", "payload": {"source": "e2e-smoke-test"}}')

if echo "$WORKER_JOB_RESPONSE" | grep -q "Job accepted"; then
    echo "Worker Job Dispatch PASSED"
else
    echo "Worker Job Dispatch FAILED"
    exit 1
fi

echo "=================================================="
echo " ALL SMOKE TESTS PASSED SUCCESSFULLY! "
echo "=================================================="
