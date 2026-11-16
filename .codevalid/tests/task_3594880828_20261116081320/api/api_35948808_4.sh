#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
UNKNOWN_ID="00000000-0000-4000-8000-$(printf '%012d' "$((SUFFIX % 1000000000000))")"

# Given
cv_step Given "Identifier $UNKNOWN_ID matches no product in the catalog" $LINENO
cv_http GET "/api/products?limit=100" 200
[ "$(echo "$CV_HTTP_BODY" | jq --arg id "$UNKNOWN_ID" '[.data[] | select(.id==$id)] | length')" = "0" ] || cv_fail "expected no product with id $UNKNOWN_ID, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Visitor opens GET /api/products/{unknown id}" $LINENO
cv_http GET "/api/products/${UNKNOWN_ID}"
GET_STATUS="$CV_HTTP_STATUS"; GET_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "No product details are returned and the visitor is told the product was not found" $LINENO
[ "$GET_STATUS" = "404" ] || cv_fail "expected 404 for unknown product id, got $GET_STATUS: $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.id // empty')" = "" ] || cv_fail "expected no product details, got $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.name // empty')" = "" ] || cv_fail "expected no product name, got $GET_BODY" $LINENO
echo "$GET_BODY" | jq -r '.error.message // empty' | grep -qi 'not found' || cv_fail "expected a 'not found' message, got $GET_BODY" $LINENO

# Cleanup
cv_step Cleanup "Nothing was created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_35948808_4"
