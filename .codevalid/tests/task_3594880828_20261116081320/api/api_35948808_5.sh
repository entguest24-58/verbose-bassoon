#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="ANON5-${SUFFIX}"
CREATED_ID=""

# Given
cv_step Given "Anonymous visitor (no credentials) sees the current product list; SKU $SKU is absent" $LINENO
cv_http GET "/api/products?limit=100" 200
TOTAL_BEFORE=$(echo "$CV_HTTP_BODY" | jq -r '.total')
[ "$(echo "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku==$s)] | length')" = "0" ] || cv_fail "expected SKU $SKU absent before the attempt, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Anonymous visitor tries to add a product via POST /api/products without signing in" $LINENO
BODY=$(jq -nc --arg s "$SKU" '{sku:$s,name:"Anonymous Product",description:"added without sign-in",price:9.99}')
cv_http POST /api/products "$BODY"
POST_STATUS="$CV_HTTP_STATUS"; POST_BODY="$CV_HTTP_BODY"
CREATED_ID=$(echo "$POST_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "The attempt is refused and the product list is unchanged" $LINENO
cv_http GET "/api/products?limit=100" 200
TOTAL_AFTER=$(echo "$CV_HTTP_BODY" | jq -r '.total')
FOUND=$(echo "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku==$s)] | length')
case "$POST_STATUS" in 2*) cv_fail "expected anonymous product creation to be refused, got $POST_STATUS and product created: $POST_BODY" $LINENO ;; esac
[ "$FOUND" = "0" ] || cv_fail "expected SKU $SKU not in the catalog after anonymous attempt, found it: $CV_HTTP_BODY" $LINENO
[ "$TOTAL_AFTER" = "$TOTAL_BEFORE" ] || cv_fail "expected product total $TOTAL_BEFORE unchanged, got $TOTAL_AFTER" $LINENO

# Cleanup
cv_step Cleanup "Remove the product if the app created it" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/products/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_35948808_5"
