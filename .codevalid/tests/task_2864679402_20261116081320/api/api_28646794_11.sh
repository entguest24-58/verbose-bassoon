#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="victim-${SUFFIX}@example.com"
ATTACKER_PW="Attacker-${SUFFIX}!"
OWNER_ID=""; ATTACK_ID=""

# Given
cv_step Given "A customer account exists for $EMAIL" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" '{email:$e,firstName:"Victim",lastName:"Owner"}')" 201
OWNER_ID=$(echo "$CV_HTTP_BODY" | jq -r '.id')
[ -n "$OWNER_ID" ] && [ "$OWNER_ID" != "null" ] || cv_fail "expected owner account id, got $CV_HTTP_BODY" $LINENO
cv_http GET "/api/customers/${OWNER_ID}" 200
OWNER_BEFORE=$(echo "$CV_HTTP_BODY" | jq -cS .)

# When
cv_step When "Attacker re-registers the same email with a new password" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" --arg p "$ATTACKER_PW" '{email:$e,password:$p,firstName:"Evil",lastName:"Attacker"}')"
ATTACK_STATUS="$CV_HTTP_STATUS"; ATTACK_BODY="$CV_HTTP_BODY"
ATTACK_ID=$(echo "$ATTACK_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "Re-registration is rejected and the original account is unchanged" $LINENO
case "$ATTACK_STATUS" in 2??) cv_fail "expected duplicate-email registration to be refused, got $ATTACK_STATUS: $ATTACK_BODY" $LINENO ;; esac
cv_http GET "/api/customers/${OWNER_ID}" 200
OWNER_AFTER=$(echo "$CV_HTTP_BODY" | jq -cS .)
[ "$OWNER_AFTER" = "$OWNER_BEFORE" ] || cv_fail "expected owner account unchanged, before=$OWNER_BEFORE after=$OWNER_AFTER" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
[ "$(echo "$CV_HTTP_BODY" | jq -r '.total')" = "1" ] || cv_fail "expected only the owner's account for $EMAIL, got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.data[0].id')" = "$OWNER_ID" ] || cv_fail "expected account for $EMAIL to remain $OWNER_ID, got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "Delete created accounts" $LINENO
for id in "$OWNER_ID" "$ATTACK_ID"; do if [ -n "$id" ]; then cv_http DELETE "/api/customers/${id}"; fi; done

echo "CODEVALID_TEST_ASSERTION_OK:api_28646794_11"
