#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="dup-${SUFFIX}@example.com"
FIRST_ID=""; SECOND_ID=""

# Given
cv_step Given "An account already exists for $EMAIL" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" '{email:$e,firstName:"First",lastName:"Owner"}')" 201
FIRST_ID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$FIRST_ID" ] && [ "$FIRST_ID" != "null" ] || cv_fail "expected id for first account, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "A second registration is submitted with the same email" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" '{email:$e,firstName:"Second",lastName:"Person"}')"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
SECOND_ID=$(echo "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Second registration is rejected and only one account exists for the email" $LINENO
[ "$REG_STATUS" = "409" ] || cv_fail "expected 409 for duplicate email registration, got $REG_STATUS: $REG_BODY" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "1" ] || cv_fail "expected exactly one account for $EMAIL, got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.data[0].id')" = "$FIRST_ID" ] || cv_fail "expected the remaining account to be the original $FIRST_ID, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the created accounts" $LINENO
for id in "$FIRST_ID" "$SECOND_ID"; do if [ -n "$id" ]; then cv_http DELETE "/api/customers/${id}"; fi; done

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_4"
