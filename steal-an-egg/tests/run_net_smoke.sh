#!/usr/bin/env bash
# Runs a host and a client on this machine and checks they can play together.
# Usage: tests/run_net_smoke.sh /path/to/godot
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."

"$GODOT" --headless --path . res://tests/net_smoke.tscn -- --role=host > /tmp/steal-an-egg-host.log 2>&1 &
HOST_PID=$!
sleep 1
"$GODOT" --headless --path . res://tests/net_smoke.tscn -- --role=client > /tmp/steal-an-egg-client.log 2>&1
CLIENT_STATUS=$?
wait $HOST_PID
HOST_STATUS=$?

echo "--- host ---"; grep -v "^Godot Engine" /tmp/steal-an-egg-host.log
echo "--- client ---"; grep -v "^Godot Engine" /tmp/steal-an-egg-client.log
if [ $HOST_STATUS -ne 0 ] || [ $CLIENT_STATUS -ne 0 ]; then
  echo "Network smoke test failed (host $HOST_STATUS, client $CLIENT_STATUS)"
  exit 1
fi
if grep -q "SCRIPT ERROR" /tmp/steal-an-egg-host.log /tmp/steal-an-egg-client.log; then
  echo "Network smoke test hit script errors"
  exit 1
fi
echo "Network smoke test passed"
