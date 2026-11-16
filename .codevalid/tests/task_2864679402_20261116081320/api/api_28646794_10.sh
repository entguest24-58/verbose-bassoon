#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="priv-${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}-Secret!"
CREATED_ID=""

# Given
cv_step Given "Email $EMAIL is unused and a unique password is chosen" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected no account for $EMAIL before the test, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Customer registers with email and password" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,firstName:"Priv",lastName:"Acy"}')"
REG_BODY="$CV_HTTP_BODY"; REG_HEADERS=$(cat "$CV_HTTP_HEADERS_FILE")
CREATED_ID=$(echo "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "No response or returned account data contains the password" $LINENO
case "$REG_BODY$REG_HEADERS" in *"$PASSWORD"*) cv_fail "expected registration response to omit the password, got $REG_BODY" $LINENO ;; esac
echo "$REG_BODY" | jq -e 'has("password") | not' >/dev/null 2>&1 || cv_fail "expected no password field in registration response, got $REG_BODY" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
case "$CV_HTTP_BODY" in *"$PASSWORD"*) cv_fail "expected customer list to omit the password, got $CV_HTTP_BODY" $LINENO ;; esac
echo "$CV_HTTP_BODY" | jq -e '[.data[] | has("password")] | any | not' >/dev/null || cv_fail "expected no password field in listed accounts, got $CV_HTTP_BODY" $LINENO
cv_http GET "/api/customers?limit=100" 200
case "$CV_HTTP_BODY" in *"$PASSWORD"*) cv_fail "expected full customer list to omit the password" $LINENO ;; esac
if [ -n "$CREATED_ID" ]; then
  cv_http GET "/api/customers/${CREATED_ID}" 200
  case "$CV_HTTP_BODY" in *"$PASSWORD"*) cv_fail "expected account detail to omit the password, got $CV_HTTP_BODY" $LINENO ;; esac
fi

[ -n "$CREATED_ID" ] || cv_fail "expected registration with email and password to create an account (201), got no account id: $REG_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the registered account" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/customers/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_10"
