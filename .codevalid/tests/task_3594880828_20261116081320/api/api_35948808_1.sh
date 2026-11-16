#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
IDS=()

# Given
cv_step Given "The catalog contains two products with name, description and price" $LINENO
for n in 1 2; do
  BODY=$(jq -nc --arg s "BRW1-${n}-${SUFFIX}" --arg nm "Browse Item ${n} ${SUFFIX}" --arg d "Description ${n} ${SUFFIX}" --argjson p "1${n}.50" \
    '{sku:$s,name:$nm,description:$d,price:$p}')
  cv_http POST /api/products "$BODY"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 seeding product $n, got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
  IDS+=("$(echo "$CV_HTTP_BODY" | jq -r '.id')")
done

# When
cv_step When "Anonymous visitor requests the product list via GET /api/products without credentials" $LINENO
cv_http GET "/api/products?limit=100"
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "The full list is returned with each product's name, description and price and no sign-in is asked for" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 for anonymous product list, got $LIST_STATUS: $LIST_BODY" $LINENO
TOTAL=$(echo "$LIST_BODY" | jq -r '.total')
COUNT=$(echo "$LIST_BODY" | jq -r '.data | length')
[ "$TOTAL" = "$COUNT" ] || cv_fail "expected every product in the list (total $TOTAL), got $COUNT items" $LINENO
for n in 1 2; do
  ID="${IDS[$((n-1))]}"
  ITEM=$(echo "$LIST_BODY" | jq -c --arg id "$ID" '.data[] | select(.id==$id)')
  [ -n "$ITEM" ] || cv_fail "expected product $ID in the anonymous list, got $LIST_BODY" $LINENO
  [ "$(echo "$ITEM" | jq -r '.name')" = "Browse Item ${n} ${SUFFIX}" ] || cv_fail "expected name 'Browse Item ${n} ${SUFFIX}', got $ITEM" $LINENO
  [ "$(echo "$ITEM" | jq -r '.description')" = "Description ${n} ${SUFFIX}" ] || cv_fail "expected description 'Description ${n} ${SUFFIX}', got $ITEM" $LINENO
  [ "$(echo "$ITEM" | jq -r '.price')" = "1${n}.5" ] || cv_fail "expected price 1${n}.5, got $ITEM" $LINENO
done

# Cleanup
cv_step Cleanup "Delete the seeded products" $LINENO
for ID in "${IDS[@]}"; do cv_http DELETE "/api/products/${ID}"; done

echo "CODEVALID_TEST_ASSERTION_OK:api_35948808_1"
