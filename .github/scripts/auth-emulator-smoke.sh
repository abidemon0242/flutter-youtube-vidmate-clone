#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1"
OOB_URL="http://127.0.0.1:9099/emulator/v1/projects/demo-tube-arena/oobCodes"
API_KEY="fake-api-key"
EMAIL="auth-emulator-smoke@example.test"
CONTINUE_URL="https://tube-arena-261114-106732.firebaseapp.com"

request() {
  local method="$1" url="$2" data="${3:-}"
  if [[ "$method" == "GET" ]]; then
    curl --fail --silent --show-error "$url"
  else
    curl --fail --silent --show-error -H 'Content-Type: application/json' -d "$data" "$url"
  fi
}

echo "1/5 Create an isolated test account in the Auth Emulator"
SIGNUP=$(request POST "$BASE_URL/accounts:signUp?key=$API_KEY" \
  "$(jq -n --arg email "$EMAIL" '{email:$email,returnSecureToken:true}')")
ID_TOKEN=$(jq -r '.idToken // empty' <<<"$SIGNUP")
LOCAL_ID=$(jq -r '.localId // empty' <<<"$SIGNUP")
test -n "$ID_TOKEN" && test -n "$LOCAL_ID"

echo "2/5 Confirm the emulator issued a valid authenticated session"
LOOKUP=$(request POST "$BASE_URL/accounts:lookup?key=$API_KEY" \
  "$(jq -n --arg token "$ID_TOKEN" '{idToken:$token}')")
test "$(jq -r '.users[0].localId // empty' <<<"$LOOKUP")" = "$LOCAL_ID"

echo "3/5 Request a passwordless email sign-in link"
request POST "$BASE_URL/accounts:sendOobCode?key=$API_KEY" \
  "$(jq -n --arg email "$EMAIL" --arg url "$CONTINUE_URL" \
    '{requestType:"EMAIL_SIGNIN",email:$email,continueUrl:$url,canHandleCodeInApp:true}')" >/dev/null

echo "4/5 Retrieve the emulator-only out-of-band code"
OOB=$(request GET "$OOB_URL")
OOB_CODE=$(jq -r --arg email "$EMAIL" \
  '[.oobCodes[] | select(.email == $email and .requestType == "EMAIL_SIGNIN")] | last | .oobCode // empty' <<<"$OOB")
test -n "$OOB_CODE"

echo "5/5 Complete passwordless sign-in and verify the returned session"
SIGNED_IN=$(request POST "$BASE_URL/accounts:signInWithEmailLink?key=$API_KEY" \
  "$(jq -n --arg email "$EMAIL" --arg code "$OOB_CODE" \
    '{email:$email,oobCode:$code,returnSecureToken:true}')")
LINK_TOKEN=$(jq -r '.idToken // empty' <<<"$SIGNED_IN")
LINK_LOCAL_ID=$(jq -r '.localId // empty' <<<"$SIGNED_IN")
test -n "$LINK_TOKEN" && test "$LINK_LOCAL_ID" = "$LOCAL_ID"

LINK_LOOKUP=$(request POST "$BASE_URL/accounts:lookup?key=$API_KEY" \
  "$(jq -n --arg token "$LINK_TOKEN" '{idToken:$token}')")
test "$(jq -r '.users[0].localId // empty' <<<"$LINK_LOOKUP")" = "$LOCAL_ID"

echo "PASS: Auth Emulator account creation, token validation, email-link issuance,"
echo "      passwordless completion, and resulting authenticated session."
echo "NOTE: This validates Firebase Auth Emulator REST behavior, not real Google OAuth"
echo "      or the Flutter app's Android deep-link delivery."
