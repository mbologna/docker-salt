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

echo "== Waiting for a minion to answer test.ping =="
for i in $(seq 1 "$PING_TIMEOUT"); do
    RESP="$(curl -fsS "${API_URL}/" \
        -H "X-Auth-Token: ${TOKEN}" \
        -H 'Accept: application/json' \
        -d client=local \
        -d tgt='*' \
        -d fun=test.ping || true)"

    RESPONDED="$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    ret = data.get("return", [{}])[0]
    print(sum(1 for v in ret.values() if v is True))
except Exception:
    print(0)
' 2>/dev/null || echo 0)"

    if [ "${RESPONDED:-0}" -ge 1 ]; then
        echo "PASS: ${RESPONDED} minion(s) responded True to test.ping"
        echo "Response: ${RESP}"
        exit 0
    fi
    echo "  attempt ${i}/${PING_TIMEOUT}: no minion yet (response: ${RESP})"
    sleep 5
done

echo "FAIL: no minion responded to test.ping within the timeout"
exit 1
