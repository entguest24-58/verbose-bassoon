#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="nopw-${SUFFIX}@example.com"
CREATED_ID=""

# Given
cv_step Given "Email $EMAIL is not yet used by any account" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected no account for $EMAIL before the test, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Customer submits a registration with an email but no password" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" '{email:$e,firstName:"No",lastName:"Password"}')
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
CREATED_ID=$(echo "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Registration is rejected and no account exists for the email" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
LIST_TOTAL=$(echo "$CV_HTTP_BODY" | jq -r '.total')
case "$REG_STATUS" in 4??) ;; *) cv_fail "expected registration without password to be rejected (4xx), got $REG_STATUS: $REG_BODY" $LINENO ;; esac
[ "$LIST_TOTAL" = "0" ] || cv_fail "expected no account for $EMAIL after registration without password, got total=$LIST_TOTAL" $LINENO

# Cleanup
cv_step Cleanup "Delete any account created for the email" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/customers/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_3"
