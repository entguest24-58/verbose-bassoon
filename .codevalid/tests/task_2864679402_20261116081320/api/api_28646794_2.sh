#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
MARK="NoEmail${SUFFIX}"
PASSWORD="Pw-${SUFFIX}-Secret!"
CREATED_ID=""

# Given
cv_step Given "No account exists with the unique marker name $MARK" $LINENO
cv_http GET "/api/customers?q=${MARK}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected no account named $MARK before the test, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Customer submits a registration with a password but no email" $LINENO
BODY=$(jq -nc --arg p "$PASSWORD" --arg m "$MARK" '{password:$p,firstName:$m,lastName:"Tester"}')
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
CREATED_ID=$(echo "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Registration is rejected and no account was created" $LINENO
[ "$REG_STATUS" = "400" ] || cv_fail "expected 400 for registration without email, got $REG_STATUS: $REG_BODY" $LINENO
echo "$REG_BODY" | jq -e '.error.details[]? | select(.path=="email")' >/dev/null || cv_fail "expected a validation error on email, got $REG_BODY" $LINENO
cv_http GET "/api/customers?q=${MARK}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected no account created without email, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Remove any account accidentally created" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/customers/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_2"
