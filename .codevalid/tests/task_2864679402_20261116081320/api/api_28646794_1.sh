#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="reg1-${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}-Secret!"
CREATED_ID=""

# Given
cv_step Given "Email $EMAIL is not yet used by any account" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected no account for $EMAIL before registering, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Customer registers with email and password via POST /api/customers" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,firstName:"Reg",lastName:"One"}')
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
CREATED_ID=$(echo "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Registration is accepted and exactly one account exists for the email" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected 201 registering with email and password, got $REG_STATUS: $REG_BODY" $LINENO
[ "$(echo "$REG_BODY" | jq -r '.email')" = "$EMAIL" ] || cv_fail "expected created account email $EMAIL, got $REG_BODY" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "1" ] || cv_fail "expected one account for $EMAIL after registration, got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.data[0].id')" = "$CREATED_ID" ] || cv_fail "expected listed account id $CREATED_ID, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the registered account" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/customers/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_1"
