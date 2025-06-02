#!/usr/bin/env bash

# Wait for Internet Connectivity Script
# Tests actual internet connectivity by attempting to reach a target

TIMEOUT=300  # 5 minutes total timeout
INTERVAL=5   # Check every 5 seconds
ELAPSED=0
TARGET="https://rancher-staging.gec.io/ping"

echo "Waiting for internet connectivity..."

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Test connectivity with curl
    # -s: silent, -f: fail on HTTP errors, -m 10: 10 second timeout per attempt
    # --connect-timeout 5: 5 second connection timeout
    if curl -sfL --connect-timeout 5 -m 10 "$TARGET" > /dev/null 2>&1; then
        echo "Internet connectivity verified at $(date)"
        exit 0
    fi
    
    echo "No internet connectivity yet, retrying in ${INTERVAL} seconds... (${ELAPSED}/${TIMEOUT}s elapsed)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Timeout reached after ${TIMEOUT} seconds - internet connectivity not established"
exit 1