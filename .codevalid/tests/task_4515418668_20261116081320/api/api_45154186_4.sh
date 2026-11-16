#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="ANON-${SUFFIX}"
CREATED_ID=""

# Given
cv_step Given "Anonymous requester (no credentials) and product code $SKU not in the catalog" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
[ "$(echo "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')" = "0" ] || cv_fail "expected no product with sku $SKU before, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Anonymous requester adds a valid product via POST /api/products without signing in" $LINENO
BODY=$(jq -nc --arg s "$SKU" '{sku:$s,name:"Anon product",description:"Should be refused",price:5.00}')
cv_http POST /api/products "$BODY"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"
CREATED_ID=$(echo "$RB" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "No product with that code appears in the catalog" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
N=$(echo "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
[ "$N" = "0" ] || cv_fail "expected anonymous add to be refused with no product $SKU in catalog, but it was created (HTTP $ST, id $CREATED_ID)" $LINENO
case "$ST" in 2??) cv_fail "expected anonymous add to be rejected, got HTTP $ST: $RB" $LINENO ;; esac

# Cleanup
cv_step Cleanup "Delete the product if the anonymous add got through" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/products/${CREATED_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_45154186_4"
