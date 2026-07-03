#!/usr/bin/env bash
#
# Integration / smoke test for the saltstack-master and saltstack-minion images.
#
# It brings the stack up with docker compose, then reproduces exactly what
# salt-netapi-client needs from these images:
#   1. salt-api answers on the netapi port (9080).
#   2. PAM auth with saltdev/saltdev returns a token.
#   3. A minion registers (key auto-accepted) and answers test.ping -> true.
#
# Usage: ./scripts/integration-test.sh
# Requires: docker (with compose plugin), curl, jq.
set -euo pipefail

API_URL="${API_URL:-http://localhost:9080}"
SALT_USER="${SALT_USER:-saltdev}"
SALT_PASSWORD="${SALT_PASSWORD:-saltdev}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-5}"  # seconds between health check attempts
API_TIMEOUT="${API_TIMEOUT:-60}"       # attempts waiting for salt-api
PING_TIMEOUT="${PING_TIMEOUT:-30}"     # attempts waiting for a minion

compose() { docker compose "$@"; }

# shellcheck disable=SC2317,SC2329  # invoked indirectly via the EXIT trap
cleanup() {
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "::group::Failure diagnostics (docker compose logs)"
        compose logs || true
        echo "::endgroup::"
    fi
    compose down -v --remove-orphans || true
    exit "$rc"
}
trap cleanup EXIT

echo "== Building and starting the stack =="
compose up -d --build

echo "== Waiting for salt-api on ${API_URL} =="
for i in $(seq 1 "$API_TIMEOUT"); do
    if curl -fsS "${API_URL}/" -o /dev/null 2>/dev/null; then
        echo "salt-api is up (after $((i * SLEEP_INTERVAL - SLEEP_INTERVAL))s)"
        break
    fi
    if [ "$i" -eq "$API_TIMEOUT" ]; then
        echo "ERROR: timed out waiting for salt-api after ${API_TIMEOUT} attempts"
        echo "       Last checked URL: ${API_URL}"
        exit 1
    fi
    sleep "$SLEEP_INTERVAL"
done

echo "== Authenticating as ${SALT_USER} via PAM =="
TOKEN="$(curl -fsS "${API_URL}/login" \
    -H 'Accept: application/json' \
    -d username="${SALT_USER}" \
    -d password="${SALT_PASSWORD}" \
    -d eauth=pam \
    | jq -r '.return[0].token')"

if [ -z "${TOKEN}" ]; then
    echo "ERROR: failed to obtain an auth token from ${API_URL}/login"
    echo "       User: ${SALT_USER}, Auth method: PAM"
    exit 1
fi
echo "Got auth token: ${TOKEN:0:8}..."

echo "== Waiting for a minion to answer test.ping (local client) =="
MINION_ID=""
for i in $(seq 1 "$PING_TIMEOUT"); do
    RESP="$(curl -fsS "${API_URL}/" \
        -H "X-Auth-Token: ${TOKEN}" \
        -H 'Accept: application/json' \
        -d client=local \
        -d tgt='*' \
        -d fun=test.ping || true)"

    MINION_ID="$(printf '%s' "$RESP" | jq -r '
        .return[0] // {}
        | to_entries
        | map(select(.value == true))
        | .[0].key // ""
    ' 2>/dev/null || echo "")"

    if [ -n "$MINION_ID" ]; then
        echo "PASS [local]: minion '${MINION_ID}' responded True to test.ping"
        break
    fi
    echo "  attempt ${i}/${PING_TIMEOUT}: no minion yet (response: ${RESP})"
    sleep "$SLEEP_INTERVAL"
done

if [ -z "$MINION_ID" ]; then
    echo "FAIL: no minion responded to test.ping within ${PING_TIMEOUT} attempts"
    echo "      Check 'docker compose logs' for minion connection issues"
    exit 1
fi

# Helper: POST a netapi client call and assert the response contains a string.
assert_client() {
    client="$1"; fun="$2"; expect="$3"; label="$4"
    resp="$(curl -fsS "${API_URL}/" \
        -H "X-Auth-Token: ${TOKEN}" \
        -H 'Accept: application/json' \
        -d client="$client" \
        -d fun="$fun" || true)"
    if printf '%s' "$resp" | grep -q "$expect"; then
        echo "PASS [${client}]: ${label}"
    else
        echo "FAIL [${client}]: ${label} (expected to find '${expect}')"
        echo "Response: ${resp}"
        exit 1
    fi
}

echo "== Exercising the runner client (manage.up) =="
assert_client runner manage.up "$MINION_ID" "manage.up lists minion '${MINION_ID}'"

echo "== Exercising the wheel client (key.list_all) =="
assert_client wheel key.list_all "$MINION_ID" "key.list_all reports key for '${MINION_ID}'"

echo "All netapi client checks passed (local, runner, wheel)."
exit 0
