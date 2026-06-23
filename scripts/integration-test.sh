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
# Requires: docker (with compose plugin), curl, python3.
set -euo pipefail

API_URL="${API_URL:-http://localhost:9080}"
SALT_USER="${SALT_USER:-saltdev}"
SALT_PASSWORD="${SALT_PASSWORD:-saltdev}"
API_TIMEOUT="${API_TIMEOUT:-60}"    # attempts (x5s) waiting for salt-api
PING_TIMEOUT="${PING_TIMEOUT:-30}"  # attempts (x5s) waiting for a minion

compose() { docker compose "$@"; }

# shellcheck disable=SC2317  # invoked indirectly via the EXIT trap
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
        echo "salt-api is up (after $((i * 5 - 5))s)"
        break
    fi
    if [ "$i" -eq "$API_TIMEOUT" ]; then
        echo "ERROR: timed out waiting for salt-api"
        exit 1
    fi
    sleep 5
done

echo "== Authenticating as ${SALT_USER} via PAM =="
TOKEN="$(curl -fsS "${API_URL}/login" \
    -H 'Accept: application/json' \
    -d username="${SALT_USER}" \
    -d password="${SALT_PASSWORD}" \
    -d eauth=pam \
    | python3 -c 'import sys, json; print(json.load(sys.stdin)["return"][0]["token"])')"

if [ -z "${TOKEN}" ]; then
    echo "ERROR: failed to obtain an auth token"
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

    MINION_ID="$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    ret = data.get("return", [{}])[0]
    ups = [m for m, v in ret.items() if v is True]
    print(ups[0] if ups else "")
except Exception:
    print("")
' 2>/dev/null || echo "")"

    if [ -n "$MINION_ID" ]; then
        echo "PASS [local]: minion '${MINION_ID}' responded True to test.ping"
        break
    fi
    echo "  attempt ${i}/${PING_TIMEOUT}: no minion yet (response: ${RESP})"
    sleep 5
done

if [ -z "$MINION_ID" ]; then
    echo "FAIL: no minion responded to test.ping within the timeout"
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
