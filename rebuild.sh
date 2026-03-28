#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# Graceful shutdown: SIGTERM first so Molly can kill child processes
pkill -TERM Molly 2>/dev/null || true
sleep 1
# Force kill if still alive
pkill -9 Molly 2>/dev/null || true
sleep 0.3

rm -rf .build Molly.app

swift build -c release
bash build_app.sh
open Molly.app
