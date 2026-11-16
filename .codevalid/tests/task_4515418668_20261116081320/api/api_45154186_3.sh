#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# This code has no sign-in endpoint or auth middleware; requests are made as the only available caller.
FIELDS="name description price sku"
CREATED_IDS=""
declare -A ST SKUS

# Given
cv_step Given "Four product bodies, each missing one of name, description, price or product code; none of their codes are in the catalog" $LINENO
for f in $FIELDS; do
  SKUS[$f]="MISS-${f}-${SUFFIX}"
  cv_http GET "/api/products?q=${SKUS[$f]}&limit=100" 200
  [ "$(echo "$CV_HTTP_BODY" | jq '.total')" = "0" ] || cv_fail "expected no product matching ${SKUS[$f]} before, got $CV_HTTP_BODY" $LINENO
done

# When
cv_step When "User submits each incomplete product via POST /api/products" $LINENO
for f in $FIELDS; do
  FULL=$(jq -nc --arg s "${SKUS[$f]}" --arg n "Missing ${f} ${SUFFIX}" '{sku:$s,name:$n,description:"Some description",price:12.34}')
  BODY=$(echo "$FULL" | jq -c --arg f "$f" 'del(.[$f])')
  cv_http POST /api/products "$BODY"
  ST[$f]="$CV_HTTP_STATUS"
  ID=$(echo "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
  [ -z "$ID" ] || CREATED_IDS="$CREATED_IDS $ID"
done

# Then
cv_step Then "Every incomplete request is rejected and no product is added" $LINENO
FAILS=""
for f in $FIELDS; do
  case "${ST[$f]}" in 4??) ;; *) FAILS="$FAILS missing-$f->HTTP${ST[$f]}" ;; esac
  cv_http GET "/api/products?q=Missing%20${f}%20${SUFFIX}&limit=100" 200
  N=$(echo "$CV_HTTP_BODY" | jq '.total')
  [ "$N" = "0" ] || FAILS="$FAILS missing-$f->added($N)"
done
[ -z "$FAILS" ] || cv_fail "expected each product missing a required value to be rejected and not added, got:$FAILS" $LINENO

# Cleanup
cv_step Cleanup "Delete any product that was wrongly created" $LINENO
for id in $CREATED_IDS; do cv_http DELETE "/api/products/${id}"; done

echo "CODEVALID_TEST_ASSERTION_OK:api_45154186_3"
