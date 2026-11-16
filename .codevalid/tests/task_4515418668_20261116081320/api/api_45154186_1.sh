#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="ADD1-${SUFFIX}"
NAME="Widget ${SUFFIX}"
DESC="A sturdy widget ${SUFFIX}"
PRICE="19.99"
CREATED_ID=""
# This code has no sign-in endpoint or auth middleware; requests are made as the only available caller.
count_sku() { cv_http GET "/api/products?q=${1}&limit=100" 200; echo "$CV_HTTP_BODY" | jq --arg s "$1" '[.data[] | select(.sku == $s)] | length' > /tmp/cv_cnt.$$; }

# Given
cv_step Given "Product code $SKU is not yet in the catalog" $LINENO
count_sku "$SKU"
[ "$(cat /tmp/cv_cnt.$$)" = "0" ] || cv_fail "expected no product with sku $SKU before adding, got $CV_HTTP_BODY" $LINENO

# When
cv_step When "User adds a product with name, description, price and new product code via POST /api/products" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" '{sku:$s,name:$n,description:$d,price:$p}')
cv_http POST /api/products "$BODY"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"
CREATED_ID=$(echo "$RB" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Product is created and readable in the catalog with exactly the entered values" $LINENO
[ "$ST" = "201" ] || cv_fail "expected 201 adding product with new sku, got $ST: $RB" $LINENO
[ -n "$CREATED_ID" ] || cv_fail "expected created product id in response, got $RB" $LINENO
cv_http GET "/api/products/${CREATED_ID}" 200
P="$CV_HTTP_BODY"
[ "$(echo "$P" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME got $(echo "$P" | jq -r '.name')" $LINENO
[ "$(echo "$P" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description $DESC got $(echo "$P" | jq -r '.description')" $LINENO
[ "$(echo "$P" | jq -r '.price == 19.99')" = "true" ] || cv_fail "expected price 19.99 got $(echo "$P" | jq -r '.price')" $LINENO
[ "$(echo "$P" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU got $(echo "$P" | jq -r '.sku')" $LINENO
count_sku "$SKU"
[ "$(cat /tmp/cv_cnt.$$)" = "1" ] || cv_fail "expected exactly one catalog product with sku $SKU, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete the created product" $LINENO
if [ -n "$CREATED_ID" ]; then cv_http DELETE "/api/products/${CREATED_ID}"; fi
rm -f /tmp/cv_cnt.$$

echo "CODEVALID_TEST_ASSERTION_OK:api_45154186_1"
