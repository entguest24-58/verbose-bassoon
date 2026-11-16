#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="SKU6-${SUFFIX}"
PID=""

# Given
cv_step Given "A product exists in the catalog" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"Original Mug",price:10.00,stock:5}')" 201
PID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$PID" ] && [ "$PID" != "null" ] || cv_fail "expected product id, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "User updates the product via PATCH /api/products/:id" $LINENO
cv_http PATCH "/api/products/${PID}" '{"name":"Updated Mug","price":12.5}'
PATCH_STATUS="$CV_HTTP_STATUS"; PATCH_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "Update is accepted and the catalog reflects it" $LINENO
[ "$PATCH_STATUS" = "200" ] || cv_fail "expected 200 for catalog update, got $PATCH_STATUS: $PATCH_BODY" $LINENO
cv_http GET "/api/products/${PID}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.name')" = "Updated Mug" ] || cv_fail "expected name 'Updated Mug', got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.price')" = "12.5" ] || cv_fail "expected price 12.5, got $CV_HTTP_BODY" $LINENO
cv_http GET "/api/products?q=${SKU}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.data[0].name')" = "Updated Mug" ] || cv_fail "expected catalog listing to show updated name, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_6"
