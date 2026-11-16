#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="SKU9-${SUFFIX}"
PID=""

# Given
cv_step Given "A product exists in the catalog and the visitor holds no credentials" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"Guarded Chair",price:50.00,stock:3}')" 201
PID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$PID" ] && [ "$PID" != "null" ] || cv_fail "expected product id, got $CV_HTTP_BODY" $LINENO
cv_http GET "/api/products/${PID}" 200
BEFORE=$(echo "$CV_HTTP_BODY" | jq -cS '{sku,name,price,stock,active,currency}')

# When
cv_step When "Anonymous visitor tries PATCH /api/products/:id without signing in" $LINENO
cv_http PATCH "/api/products/${PID}" '{"name":"Hacked Chair","price":0}'
ATTEMPT_STATUS="$CV_HTTP_STATUS"; ATTEMPT_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "The attempt is refused and the product is unchanged" $LINENO
cv_http GET "/api/products/${PID}" 200
AFTER=$(echo "$CV_HTTP_BODY" | jq -cS '{sku,name,price,stock,active,currency}')
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected product unchanged after anonymous update, before=$BEFORE after=$AFTER" $LINENO
case "$ATTEMPT_STATUS" in 2??) cv_fail "expected anonymous catalog update to be refused, got $ATTEMPT_STATUS: $ATTEMPT_BODY" $LINENO ;; esac

# Cleanup
cv_step Cleanup "Delete the product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_9"
