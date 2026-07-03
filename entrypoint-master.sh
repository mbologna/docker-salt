#!/usr/bin/env bash
#
# Start and supervise salt-master and salt-api in the foreground.
# If either process exits, stop the other and exit non-zero so the container
# orchestrator (Docker, compose, GitHub Actions services) can restart it.
set -euo pipefail

MASTER_PID=""
API_PID=""

# Helper function for timestamped logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

shutdown() {
    log "Received shutdown signal, stopping salt services..."
    if [ -n "$MASTER_PID" ]; then kill "$MASTER_PID" 2>/dev/null || true; fi
    if [ -n "$API_PID" ]; then kill "$API_PID" 2>/dev/null || true; fi
    wait 2>/dev/null || true
    exit 0
}
trap shutdown SIGTERM SIGINT

log "Starting salt-master..."
/usr/bin/salt-master -l info &
MASTER_PID=$!

log "Starting salt-api..."
/usr/bin/salt-api -l info &
API_PID=$!

log "salt-master (pid $MASTER_PID) and salt-api (pid $API_PID) started."

# Supervise both processes. Exit as soon as one of them dies.
while true; do
    if ! kill -0 "$MASTER_PID" 2>/dev/null; then
        log "salt-master (pid $MASTER_PID) has exited."
        kill "$API_PID" 2>/dev/null || true
        wait 2>/dev/null || true
        exit 1
    fi
    if ! kill -0 "$API_PID" 2>/dev/null; then
        log "salt-api (pid $API_PID) has exited."
        kill "$MASTER_PID" 2>/dev/null || true
        wait 2>/dev/null || true
        exit 1
    fi
    sleep 5
done
