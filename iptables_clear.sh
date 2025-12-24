#!/usr/bin/env bash
set -e

echo "[1/2] Flush all iptables rules..."
iptables -F

echo "[2/2] Delete all user-defined chains..."
iptables -X

echo
echo "DONE. iptables fully cleared."
