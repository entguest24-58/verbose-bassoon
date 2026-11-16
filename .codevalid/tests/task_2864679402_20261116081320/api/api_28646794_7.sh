#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="SKU7-${SUFFIX}"
PID=""

# Given
cv_step Given "A product exists in the catalog" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"Browse Lamp",price:20.00}')" 201
PID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$PID" ] && [ "$PID" != "null" ] || cv_fail "expected product id, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "Anonymous visitor lists the catalog via GET /api/products" $LINENO
cv_http GET "/api/products?q=${SKU}"

# Then
cv_step Then "The catalog is returned and includes the product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for anonymous catalog browse, got $CV_HTTP_STATUS" $LINENO
echo "$CV_HTTP_BODY" | jq -e --arg id "$PID" '.data | map(.id) | index($id) != null' >/dev/null || cv_fail "expected product $PID in catalog, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_7"
