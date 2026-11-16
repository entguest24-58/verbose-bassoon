#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
NAME="Single Item ${SUFFIX}"
DESC="Single description ${SUFFIX}"
PID=""

# Given
cv_step Given "The catalog contains a product with name, description and price" $LINENO
BODY=$(jq -nc --arg s "BRW2-${SUFFIX}" --arg nm "$NAME" --arg d "$DESC" '{sku:$s,name:$nm,description:$d,price:24.99}')
cv_http POST /api/products "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 seeding product, got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
PID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$PID" ] && [ "$PID" != "null" ] || cv_fail "expected an id for the seeded product, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Anonymous visitor opens the product via GET /api/products/{id} without credentials" $LINENO
cv_http GET "/api/products/${PID}"
GET_STATUS="$CV_HTTP_STATUS"; GET_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "The product's details are returned and no sign-in is asked for" $LINENO
[ "$GET_STATUS" = "200" ] || cv_fail "expected 200 for anonymous product view, got $GET_STATUS: $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.id')" = "$PID" ] || cv_fail "expected product id $PID, got $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name '$NAME', got $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description '$DESC', got $GET_BODY" $LINENO
[ "$(echo "$GET_BODY" | jq -r '.price')" = "24.99" ] || cv_fail "expected price 24.99, got $GET_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the seeded product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_35948808_2"
