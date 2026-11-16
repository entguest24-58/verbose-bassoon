#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="DUP-${SUFFIX}"
EXISTING_ID=""
DUP_ID=""
# This code has no sign-in endpoint or auth middleware; requests are made as the only available caller.

# Given
cv_step Given "A product with product code $SKU already exists in the catalog" $LINENO
ORIG=$(jq -nc --arg s "$SKU" '{sku:$s,name:"Original",description:"Original desc",price:10.5}')
cv_http POST /api/products "$ORIG"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating existing product, got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
EXISTING_ID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
cv_http GET "/api/products/${EXISTING_ID}" 200
BEFORE=$(echo "$CV_HTTP_BODY" | jq -cS '.')

# When
cv_step When "User adds another product with the same product code via POST /api/products" $LINENO
DUP=$(jq -nc --arg s "$SKU" '{sku:$s,name:"Impostor",description:"Different desc",price:99.99}')
cv_http POST /api/products "$DUP"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"
DUP_ID=$(echo "$RB" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Request is rejected, only one product has the code, and the existing product is unchanged" $LINENO
case "$ST" in 4??) ;; *) cv_fail "expected 4xx rejection for duplicate sku, got $ST: $RB" $LINENO ;; esac
[ -z "$DUP_ID" ] || cv_fail "expected no product created for duplicate sku, got id $DUP_ID" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
N=$(echo "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
[ "$N" = "1" ] || cv_fail "expected exactly one product with sku $SKU, got $N: $CV_HTTP_BODY" $LINENO
cv_http GET "/api/products/${EXISTING_ID}" 200
AFTER=$(echo "$CV_HTTP_BODY" | jq -cS '.')
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected existing product unchanged $BEFORE got $AFTER" $LINENO

# Cleanup
cv_step Cleanup "Delete created products" $LINENO
if [ -n "$DUP_ID" ]; then cv_http DELETE "/api/products/${DUP_ID}"; fi
if [ -n "$EXISTING_ID" ]; then cv_http DELETE "/api/products/${EXISTING_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_45154186_2"
